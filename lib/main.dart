import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'services/streaming_server.dart';
import 'widgets/broadcast_picker_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Bloquear orientación o permitir rotación fluida
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final server = StreamingServer();
  await server.initialize();
  await server.startServer();

  runApp(
    ChangeNotifierProvider.value(
      value: server,
      child: const ScreenMirrorApp(),
    ),
  );
}

class ScreenMirrorApp extends StatelessWidget {
  const ScreenMirrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'iOS Screen Cast',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0E1A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF0071E3),
          secondary: Color(0xFF30D158),
          surface: Color(0xFF151C2C),
        ),
        fontFamily: '.SF Pro Text',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showQr = true;

  @override
  Widget build(BuildContext context) {
    final server = context.watch<StreamingServer>();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF0071E3).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.cast_connected, color: Color(0xFF0071E3), size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'iOS Screen Mirror',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: -0.3),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar IP',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => server.updateIpAddress(),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Estado en vivo
              _buildLiveStatusHeader(server),
              const SizedBox(height: 20),

              // 2. Tarjeta principal de conexión (URL + QR)
              _buildConnectionCard(server),
              const SizedBox(height: 24),

              // 3. Botón de inicio de transmisión nativo
              Center(
                child: BroadcastPickerWidget(
                  width: double.infinity,
                  height: 58,
                  onTapped: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('En iOS real, este botón abrirá el selector del sistema.'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // 4. Guía de uso rápido
              _buildQuickGuide(),
              const SizedBox(height: 24),

              // 5. Estadísticas de transmisión
              _buildStatsCard(server),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveStatusHeader(StreamingServer server) {
    final isBroadcasting = server.isBroadcasting;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF151C2C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isBroadcasting ? const Color(0xFF30D158) : Colors.white10,
          width: isBroadcasting ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isBroadcasting ? const Color(0xFF30D158) : const Color(0xFFFF9F0A),
              boxShadow: [
                BoxShadow(
                  color: (isBroadcasting ? const Color(0xFF30D158) : const Color(0xFFFF9F0A))
                      .withValues(alpha: 0.5),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isBroadcasting ? 'Transmitiendo pantalla' : 'Servidor listo en espera',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                Text(
                  isBroadcasting
                      ? '${server.fps} FPS • ${server.connectedClientsCount} visor(es) conectado(s)'
                      : 'Abre la dirección en tu PC para visualizar',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionCard(StreamingServer server) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF151C2C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Dirección de tu PC / Navegador',
            style: TextStyle(color: Colors.white60, fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 10),

          // Enlace clickeable / copiable
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF0071E3).withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.link, color: Color(0xFF0071E3), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    server.serverUrl,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 20, color: Colors.white70),
                  tooltip: 'Copiar enlace',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: server.serverUrl));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('¡Enlace copiado al portapapeles!'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Toggle QR Code
          GestureDetector(
            onTap: () => setState(() => _showQr = !_showQr),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _showQr ? Icons.qr_code_scanner : Icons.qr_code,
                  size: 16,
                  color: const Color(0xFF0071E3),
                ),
                const SizedBox(width: 6),
                Text(
                  _showQr ? 'Ocultar Código QR' : 'Mostrar Código QR',
                  style: const TextStyle(color: Color(0xFF0071E3), fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),

          if (_showQr) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: QrImageView(
                data: server.serverUrl,
                version: QrVersions.auto,
                size: 170.0,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Escanea con la cámara de tu laptop o tablet',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickGuide() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF151C2C).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded, color: Color(0xFFFF9F0A), size: 18),
              SizedBox(width: 8),
              Text(
                '¿Cómo funciona?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildStepItem(1, 'Conecta tu iPhone y tu computadora a la misma red Wi-Fi.'),
          _buildStepItem(2, 'Abre la dirección mostrada arriba en Chrome, Edge o Safari en tu PC.'),
          _buildStepItem(3, 'Toca "Iniciar Transmisión" y selecciona la app para ver tu pantalla en vivo.'),
        ],
      ),
    );
  }

  Widget _buildStepItem(int stepNumber, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$stepNumber',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12.5, color: Colors.white70, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(StreamingServer server) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF151C2C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatColumn('Visores PC', '${server.connectedClientsCount}', Icons.devices),
          _buildDivider(),
          _buildStatColumn('FPS en vivo', '${server.fps}', Icons.speed),
          _buildDivider(),
          _buildStatColumn('Puerto', '${server.port}', Icons.dns_outlined),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(width: 1, height: 28, color: Colors.white12);
  }

  Widget _buildStatColumn(String label, String value, IconData icon) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white54),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
        ),
      ],
    );
  }
}
