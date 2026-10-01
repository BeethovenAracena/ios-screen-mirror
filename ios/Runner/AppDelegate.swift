import Flutter
import UIKit
import ReplayKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ScreenMirrorBroadcastPicker") {
      let factory = BroadcastPickerFactory(messenger: registrar.messenger())
      registrar.register(factory, withId: "com.screenmirror.broadcast_picker")
    }
  }
}

class BroadcastPickerFactory: NSObject, FlutterPlatformViewFactory {
  private var messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    return BroadcastPickerView(frame: frame, viewId: viewId, args: args, messenger: messenger)
  }

  public func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    return FlutterStandardMessageCodec.sharedInstance()
  }
}

class BroadcastPickerView: NSObject, FlutterPlatformView {
  private var _view: UIView

  init(
    frame: CGRect,
    viewId: Int64,
    args: Any?,
    messenger: FlutterBinaryMessenger?
  ) {
    let pickerView = RPSystemBroadcastPickerView(frame: frame)
    pickerView.preferredExtension = "com.screenmirror.ios-screen-cast.ScreenCastExtension"
    pickerView.showsMicrophoneButton = false
    pickerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    _view = pickerView
    super.init()
  }

  func view() -> UIView {
    return _view
  }
}
