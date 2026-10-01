import ReplayKit
import Network
import CoreImage
import UIKit

class SampleHandler: RPBroadcastSampleHandler {

    private var connection: NWConnection?
    private let context = CIContext(options: [CIContextOption.useSoftwareRenderer: false])
    private var isSendingFrame = false
    private let queue = DispatchQueue(label: "com.screenmirror.screencast.queue", qos: .userInteractive)
    private var frameCounter = 0

    // Configuración de compresión (0.6 = balance perfecto calidad/latencia/memoria)
    private let jpegQuality: CGFloat = 0.65
    // Saltear frames si la red es lenta o para limitar a ~30-40 fps y ahorrar batería
    private let frameSkipRatio = 1 

    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        super.broadcastStarted(withSetupInfo: setupInfo)
        connectToLocalServer()
    }

    override func broadcastPaused() {
        super.broadcastPaused()
    }

    override func broadcastResumed() {
        super.broadcastResumed()
    }

    override func broadcastFinished() {
        super.broadcastFinished()
        connection?.cancel()
        connection = nil
    }

    private func connectToLocalServer() {
        let endpoint = NWEndpoint.hostPort(host: "127.0.0.1", port: 9091)
        let parameters = NWParameters.tcp
        parameters.defaultProtocolStack.transportProtocol = NWProtocolTCP.Options()

        connection = NWConnection(to: endpoint, using: parameters)
        connection?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("[ScreenCastExtension] Conectado al servidor local de streaming.")
            case .failed(let error):
                print("[ScreenCastExtension] Error de conexión: \(error.localizedDescription)")
                self?.reconnect()
            case .cancelled:
                print("[ScreenCastExtension] Conexión cancelada.")
            default:
                break
            }
        }
        connection?.start(queue: queue)
    }

    private func reconnect() {
        queue.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            self.connectToLocalServer()
        }
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        switch sampleBufferType {
        case .video:
            // Control de flujo: si el socket está ocupado enviando el frame anterior,
            // descartamos este frame para evitar acumulación de memoria en el buffer.
            // (ReplayKit mata la extensión si excede los 50MB de RAM)
            if isSendingFrame {
                return
            }

            frameCounter += 1
            if frameCounter % frameSkipRatio != 0 {
                return
            }

            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

            autoreleasepool {
                processPixelBuffer(pixelBuffer)
            }

        case .audioApp, .audioMic:
            // Soporte opcional para audio
            break

        @unknown default:
            break
        }
    }

    private func processPixelBuffer(_ pixelBuffer: CVPixelBuffer) {
        guard let connection = self.connection, connection.state == .ready else { return }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }

        let uiImage = UIImage(cgImage: cgImage)
        guard let jpegData = uiImage.jpegData(compressionQuality: jpegQuality) else { return }

        var frameSize = UInt32(jpegData.count).bigEndian
        let headerData = Data(bytes: &frameSize, count: MemoryLayout<UInt32>.size)

        var packet = Data()
        packet.append(headerData)
        packet.append(jpegData)

        isSendingFrame = true

        connection.send(content: packet, completion: .contentProcessed { [weak self] error in
            self?.queue.async {
                self?.isSendingFrame = false
            }
            if let error = error {
                print("[ScreenCastExtension] Error enviando paquete: \(error)")
            }
        })
    }
}
