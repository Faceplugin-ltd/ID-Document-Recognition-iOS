import Foundation

struct LicenseStatus {
    let licensed: Bool
    let level: Int
    let levelName: String
    let recognition: Bool
    let authenticity: Bool
    let label: String

    static func current() -> LicenseStatus {
        from(json: DocSDK.getLicenseStatus())
    }

    static func from(json: String?) -> LicenseStatus {
        guard let data = (json ?? "").data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return .notLicensed
        }
        return LicenseStatus(
            licensed: obj["licensed"] as? Bool ?? false,
            level: obj["level"] as? Int ?? -1,
            levelName: obj["levelName"] as? String ?? "None",
            recognition: obj["recognition"] as? Bool ?? false,
            authenticity: obj["authenticity"] as? Bool ?? false,
            label: obj["label"] as? String ?? "Not licensed"
        )
    }

    static let notLicensed = LicenseStatus(
        licensed: false,
        level: -1,
        levelName: "None",
        recognition: false,
        authenticity: false,
        label: "Not licensed"
    )

    /// User-facing note when a requested capability is missing.
    func denyMessage(wantRecognition: Bool, wantAuthenticity: Bool) -> String? {
        var parts: [String] = []
        if wantAuthenticity && !authenticity {
            parts.append("Liveness is not available on this license (\(label)).")
        }
        if wantRecognition && !recognition {
            parts.append("Recognition is not available on this license (\(label)).")
        }
        return parts.isEmpty ? nil : parts.joined(separator: "\n")
    }
}
