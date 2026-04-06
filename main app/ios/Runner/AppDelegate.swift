import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("AIzaSyAH4ioId-gjIZXkDU3aNmaDjeDclwXY9p8")
    
    // Official registration from our dedicated plugin class
    ContactsPlugin.register(with: self.registrar(forPlugin: "ContactsPlugin")!)
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
