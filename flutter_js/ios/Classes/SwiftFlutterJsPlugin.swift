import Flutter
import JavaScriptCore
import UIKit

public class SwiftFlutterJsPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.whaleread.flutter_js", binaryMessenger: registrar.messenger())
        let instance = SwiftFlutterJsPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        result(FlutterMethodNotImplemented)
    }
}
