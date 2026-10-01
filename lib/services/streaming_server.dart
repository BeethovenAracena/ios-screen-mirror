import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'web_viewer_html.dart';

class StreamingServer extends ChangeNotifier {
  HttpServer? _httpServer;
  ServerSocket? _internalSocketServer;
  final Set<WebSocketChannel> _wsClients = {};
  final List<StreamController<List<int>>> _mjpegControllers = [];

  bool _isRunning = false;
  bool _isBroadcasting = false;
  int _port = 8080;
  final int _internalPort = 9091;
  String _ipAddress = '127.0.0.1';
  int _connectedClientsCount = 0;
  int _fps = 0;
  int _totalFramesReceived = 0;

  Timer? _fpsTimer;
  int _framesInCurrentSecond = 0;

  // Getters
  bool get isRunning => _isRunning;
  bool get isBroadcasting => _isBroadcasting;
  int get port => _port;
  String get ipAddress => _ipAddress;
  String get serverUrl => 'http://$_ipAddress:$_port';
  int get connectedClientsCount => _connectedClientsCount;
  int get fps => _fps;
  int get totalFramesReceived => _totalFramesReceived;

  Future<void> initialize({int port = 8080}) async {
    _port = port;
    await updateIpAddress();
  }

  Future<void> updateIpAddress() async {
    try {
      final info = NetworkInfo();
      final wifiIp = await info.getWifiIP();
      if (wifiIp != null && wifiIp.isNotEmpty) {
        _ipAddress = wifiIp;
      } else {
        // Fallback: search available network interfaces
        for (var interface in await NetworkInterface.list()) {
          for (var addr in interface.addresses) {
            if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
              _ipAddress = addr.address;
              break;
            }
          }
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error obteniendo IP local: $e');
    }
  }

  Future<void> startServer() async {
    if (_isRunning) return;

    await updateIpAddress();

    // Configurar router de Shelf
    final app = Router();

    // 1. Servir página web principal
    app.get('/', (Request request) {
      return Response.ok(
        webViewerHtml,
        headers: {'content-type': 'text/html; charset=utf-8'},
      );
    });

    // 2. Endpoint WebSocket para transmitir frames ultra-rápido
    final wsHandler = webSocketHandler((WebSocketChannel webSocket, [String? _]) {
      _wsClients.add(webSocket);
      _connectedClientsCount = _wsClients.length + _mjpegControllers.length;
      notifyListeners();

      webSocket.stream.listen(
        (message) {
          // Opcional: recibir comandos o ping del cliente
        },
        onDone: () {
          _wsClients.remove(webSocket);
          _connectedClientsCount = _wsClients.length + _mjpegControllers.length;
          notifyListeners();
        },
        onError: (error) {
          _wsClients.remove(webSocket);
          _connectedClientsCount = _wsClients.length + _mjpegControllers.length;
          notifyListeners();
        },
      );
    });

    app.get('/ws', wsHandler);

    // 3. Endpoint MJPEG tradicional (para OBS, VLC o navegadores antiguos)
    app.get('/stream.mjpeg', (Request request) {
      final controller = StreamController<List<int>>();
      _mjpegControllers.add(controller);
      _connectedClientsCount = _wsClients.length + _mjpegControllers.length;
      notifyListeners();

      request.context['shelf.io.connection'];

      return Response.ok(
        controller.stream,
        headers: {
          'Content-Type': 'multipart/x-mixed-replace; boundary=--frame',
          'Cache-Control': 'no-cache, private',
          'Connection': 'close',
          'Pragma': 'no-cache',
        },
      );
    });

    // 4. API de estado JSON
    app.get('/status', (Request request) {
      final data = {
        'status': 'online',
        'broadcasting': _isBroadcasting,
        'clients': _connectedClientsCount,
        'fps': _fps,
        'totalFrames': _totalFramesReceived,
      };
      return Response.ok(
        jsonEncode(data),
        headers: {'content-type': 'application/json'},
      );
    });

    final handler = const Pipeline()
        .addMiddleware(logRequests())
        .addHandler(app.call);

    try {
      _httpServer = await shelf_io.serve(handler, InternetAddress.anyIPv4, _port);
      debugPrint('Servidor HTTP iniciado en http://$_ipAddress:$_port');

      // Iniciar el socket interno TCP para recibir frames de ReplayKit
      await _startInternalSocketServer();

      _isRunning = true;
      _startFpsMonitor();
      notifyListeners();
    } catch (e) {
      debugPrint('Error iniciando servidores: $e');
      rethrow;
    }
  }

  Future<void> _startInternalSocketServer() async {
    try {
      _internalSocketServer = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        _internalPort,
      );
      debugPrint('Socket interno ReplayKit escuchando en 127.0.0.1:$_internalPort');

      _internalSocketServer!.listen((Socket clientSocket) {
        debugPrint('Extensión ReplayKit conectada al socket interno');
        _isBroadcasting = true;
        notifyListeners();

        // Buffer acumulador para reconstruir paquetes de frames
        final buffer = BytesBuilder(copy: false);
        int expectedFrameSize = 0;

        clientSocket.listen(
          (Uint8List data) {
            buffer.add(data);

            while (true) {
              if (expectedFrameSize == 0) {
                // Necesitamos al menos 4 bytes para leer la longitud del frame
                if (buffer.length >= 4) {
                  final headerBytes = buffer.toBytes().sublist(0, 4);
                  final byteData = ByteData.sublistView(headerBytes);
                  expectedFrameSize = byteData.getUint32(0, Endian.big);

                  // Descartar el encabezado de 4 bytes del buffer
                  final remaining = buffer.takeBytes().sublist(4);
                  buffer.add(remaining);
                } else {
                  break; // Esperar más datos
                }
              }

              if (expectedFrameSize > 0 && buffer.length >= expectedFrameSize) {
                final allBytes = buffer.takeBytes();
                final frameData = allBytes.sublist(0, expectedFrameSize);
                final remaining = allBytes.sublist(expectedFrameSize);
                buffer.add(remaining);

                expectedFrameSize = 0;

                // Distribuir el frame recibido
                _dispatchFrame(frameData);
              } else {
                break; // Esperar el resto del frame
              }
            }
          },
          onDone: () {
            debugPrint('Extensión ReplayKit desconectada');
            _isBroadcasting = false;
            notifyListeners();
          },
          onError: (err) {
            debugPrint('Error en socket de extensión ReplayKit: $err');
            _isBroadcasting = false;
            notifyListeners();
          },
        );
      });
    } catch (e) {
      debugPrint('Error iniciando socket interno: $e');
    }
  }

  void _dispatchFrame(Uint8List frameData) {
    _framesInCurrentSecond++;
    _totalFramesReceived++;

    // 1. Enviar a clientes WebSocket
    final disconnectedWs = <WebSocketChannel>[];
    for (final ws in _wsClients) {
      try {
        ws.sink.add(frameData);
      } catch (e) {
        disconnectedWs.add(ws);
      }
    }
    if (disconnectedWs.isNotEmpty) {
      _wsClients.removeAll(disconnectedWs);
      _connectedClientsCount = _wsClients.length + _mjpegControllers.length;
    }

    // 2. Enviar a clientes MJPEG
    if (_mjpegControllers.isNotEmpty) {
      final header = utf8.encode(
        '--frame\r\nContent-Type: image/jpeg\r\nContent-Length: ${frameData.length}\r\n\r\n',
      );
      final footer = utf8.encode('\r\n');

      final deadControllers = <StreamController<List<int>>>[];
      for (final controller in _mjpegControllers) {
        if (!controller.isClosed) {
          try {
            controller.add(header);
            controller.add(frameData);
            controller.add(footer);
          } catch (_) {
            deadControllers.add(controller);
          }
        } else {
          deadControllers.add(controller);
        }
      }
      for (final dead in deadControllers) {
        _mjpegControllers.remove(dead);
      }
    }
  }

  void _startFpsMonitor() {
    _fpsTimer?.cancel();
    _fpsTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _fps = _framesInCurrentSecond;
      _framesInCurrentSecond = 0;
      notifyListeners();
    });
  }

  Future<void> stopServer() async {
    _fpsTimer?.cancel();

    for (final ws in _wsClients) {
      try {
        ws.sink.close();
      } catch (_) {}
    }
    _wsClients.clear();

    for (final ctrl in _mjpegControllers) {
      try {
        ctrl.close();
      } catch (_) {}
    }
    _mjpegControllers.clear();

    await _httpServer?.close(force: true);
    await _internalSocketServer?.close();

    _httpServer = null;
    _internalSocketServer = null;
    _isRunning = false;
    _isBroadcasting = false;
    _connectedClientsCount = 0;
    _fps = 0;

    notifyListeners();
  }

  @override
  void dispose() {
    stopServer();
    super.dispose();
  }
}
