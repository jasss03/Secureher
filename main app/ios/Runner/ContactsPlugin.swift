import Flutter
import UIKit
import ContactsUI

public class ContactsPlugin: NSObject, FlutterPlugin, CNContactPickerDelegate {
  private var result: FlutterResult?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "com.secureher/contacts", binaryMessenger: registrar.messenger())
    let instance = ContactsPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "pickContact" {
      self.result = result
      
      var rootViewController = UIApplication.shared.keyWindow?.rootViewController
      if rootViewController == nil {
        rootViewController = UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.rootViewController
      }
      
      if let controller = rootViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = self
        picker.displayedPropertyKeys = [
          CNContactGivenNameKey,
          CNContactFamilyNameKey,
          CNContactPhoneNumbersKey,
          CNContactEmailAddressesKey,
        ]
        controller.present(picker, animated: true)
      } else {
        result(FlutterError(code: "UNAVAILABLE", message: "Key window root view controller is unavailable", details: nil))
      }
    } else {
      result(FlutterMethodNotImplemented)
    }
  }

  public func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
    let given = contact.givenName
    let family = contact.familyName
    let name = "\(given) \(family)".trimmingCharacters(in: .whitespaces)
    let phones = contact.phoneNumbers.map { $0.value.stringValue }
    let emails = contact.emailAddresses.map { $0.value as String }
    
    result?([
      "name": name,
      "phones": phones,
      "emails": emails
    ])
    result = nil
  }

  public func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
    result?(nil)
    result = nil
  }
}
