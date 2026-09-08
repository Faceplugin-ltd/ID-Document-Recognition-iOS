import UIKit

enum AppSettings {
    static func authenticityMode(licenseAllows: Bool) -> String {
        licenseAllows ? "normal" : "none"
    }
}

/// Session helper for still OCR / MRZ / barcode.
/// Call startGallery immediately before DocSDK.recognize.
enum DocSdkSession {
    @discardableResult
    static func startGallery() -> String {
        DocSDK.startNewSession("{\"scenario\":\"FullProcess\",\"series\":false}")
    }
}
