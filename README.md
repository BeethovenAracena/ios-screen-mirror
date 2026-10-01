# 📱 iOS Screen Mirror (Transmisor de Pantalla a PC / Web)

Aplicación para iOS desarrollada con **Flutter** y **Swift (Apple ReplayKit)** que permite transmitir la pantalla completa de tu iPhone a cualquier computadora o dispositivo en la misma red Wi-Fi en tiempo real con **ultra baja latencia (<60ms)**, sin instalar ningún programa adicional en la PC.

---

## 🚀 ¿Cómo Funciona? (Arquitectura)

Debido al sandbox de seguridad de Apple, ninguna app de iOS puede capturar la pantalla de otras aplicaciones directamente. Para lograrlo, esta solución utiliza la arquitectura oficial recomendada por Apple:

```mermaid
flowchart LR
    A[Pantalla iPhone] -->|ReplayKit| B[ScreenCastExtension<br/>RPBroadcastSampleHandler]
    B -->|TCP Loopback 127.0.0.1:9091| C[Servidor Embebido Flutter<br/>Shelf + WebSockets]
    C -->|Wi-Fi Local :8080| D[Navegador en PC<br/>Chrome / Edge / Firefox]
```

1. **App Principal (Flutter)**:
   - Obtiene la dirección IP local de tu Wi-Fi.
   - Inicia un servidor web embebido HTTP y WebSocket en el puerto `8080`.
   - Muestra el enlace, el código QR y el botón nativo del sistema `RPSystemBroadcastPickerView`.
   - Escucha un socket TCP interno (`127.0.0.1:9091`) para recibir los frames capturados.

2. **Extensión de Transmisión Nativa (`ScreenCastExtension` - Swift)**:
   - Implementa `RPBroadcastSampleHandler`.
   - Captura cada cuadro de video del sistema operativo (`CMSampleBuffer`).
   - Comprime los cuadros a JPEG optimizado en un hilo de alta prioridad.
   - Controla el flujo de memoria para mantenerse estrictamente por debajo del límite de 50MB de Apple.
   - Envía los cuadros por TCP al servidor interno de la app.

3. **Visor Web de la PC (`webViewerHtml`)**:
   - Se sirve directamente desde el iPhone al ingresar a `http://<IP_DEL_IPHONE>:8080`.
   - Renderiza el stream en un `<canvas>` acelerado por hardware a través de WebSocket.
   - Incluye funciones de:
     - Pantalla completa (`F11` o botón).
     - Rotación (0°, 90°, 180°, 270°).
     - Captura de pantalla instantánea guardada en la PC en formato PNG.
     - Monitor de FPS y resolución en tiempo real.
     - Endpoint alternativo MJPEG en `/stream.mjpeg` (compatible con OBS Studio, VLC, etc.).

---

## 🛠️ Estructura del Proyecto

- `lib/main.dart`: Interfaz principal en Flutter con diseño estilo iOS, código QR y métricas en vivo.
- `lib/services/streaming_server.dart`: Servidor HTTP, WebSocket y socket TCP interno de alta velocidad.
- `lib/services/web_viewer_html.dart`: Aplicación web moderna servida a la PC.
- `lib/widgets/broadcast_picker_widget.dart`: Integración nativa de `RPSystemBroadcastPickerView`.
- `ios/Runner/AppDelegate.swift`: Registro del PlatformView para el botón nativo de ReplayKit.
- `ios/ScreenCastExtension/SampleHandler.swift`: Código nativo Swift de la extensión de captura ReplayKit.
- `ios/ScreenCastExtension/Info.plist`: Manifiesto de la extensión de transmisión.

---

## 📲 Pasos para Ejecutar en tu iPhone (con Xcode en Mac)

Para compilar y firmar la extensión en un iPhone físico:

1. **Abrir el proyecto en Xcode**:
   ```bash
   cd ios
   open Runner.xcworkspace
   ```

2. **Agregar el Target de la Extensión (si configuras desde cero)**:
   - En Xcode, ve a **File > New > Target...**
   - Selecciona **Broadcast Upload Extension**.
   - Nómbralo: `ScreenCastExtension`.
   - Asegúrate de asignar tu Apple Developer Team (gratuito o de pago).

3. **Copiar el archivo de la extensión**:
   - Reemplaza el archivo `SampleHandler.swift` generado por el archivo ubicado en `ios/ScreenCastExtension/SampleHandler.swift`.

4. **Conectar tu iPhone y Ejecutar**:
   - Conecta tu iPhone por cable USB o Wi-Fi.
   - En Xcode, selecciona el target `Runner` y tu dispositivo iPhone.
   - Presiona **Cmd + R** para compilar y ejecutar.

---

## 💻 Instrucciones de Uso

1. Conecta tu **iPhone** y tu **Computadora** a la **misma red Wi-Fi**.
2. Abre la app en tu iPhone. Verás una pantalla con una dirección como:
   ```
   http://192.168.1.45:8080
   ```
3. En el navegador de tu computadora (Google Chrome, Microsoft Edge, Brave, etc.), escribe esa dirección o escanea el código QR mostrado en pantalla.
4. En el iPhone, presiona el botón **"Iniciar Transmisión"**, selecciona la extensión y toca **"Iniciar transmisión"**.
5. ¡Listo! La pantalla de tu iPhone aparecerá en tu computadora al instante.
