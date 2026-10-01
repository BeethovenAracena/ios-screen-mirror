import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BroadcastPickerWidget extends StatelessWidget {
  final double width;
  final double height;
  final VoidCallback? onTapped;

  const BroadcastPickerWidget({
    super.key,
    this.width = 240,
    this.height = 56,
    this.onTapped,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // En iOS utilizamos el PlatformView nativo de RPSystemBroadcastPickerView
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return SizedBox(
        width: width,
        height: height,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Botón visual con diseño moderno
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0071E3), Color(0xFF0051A8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0071E3).withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cast, color: Colors.white, size: 22),
                  SizedBox(width: 10),
                  Text(
                    'Iniciar Transmisión',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
            // RPSystemBroadcastPickerView superpuesto transparente para capturar el tap del sistema de iOS
            Positioned.fill(
              child: Opacity(
                opacity: 0.02, // Casi transparente para que el tap sea interceptado por ReplayKit
                child: const UiKitView(
                  viewType: 'com.screenmirror.broadcast_picker',
                  creationParamsCodec: StandardMessageCodec(),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Fallback para pruebas en Simulator o Web/Android
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        minimumSize: Size(width, height),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
      ),
      onPressed: onTapped,
      icon: const Icon(Icons.cast),
      label: const Text(
        'Iniciar Transmisión',
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
    );
  }
}
