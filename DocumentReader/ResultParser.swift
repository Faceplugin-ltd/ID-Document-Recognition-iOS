import UIKit

struct FieldRow {
    let key: String
    let value: String
    let source: String
}

struct SecurityRow {
    let page: String
    let check: String
    let status: String
}

/// One image from the DocSDK `images` array, grouped by category (`name`).
struct ResultImage {
    let category: String
    let source: String
    let image: UIImage
}

/**
 * Maps DocSDK JSON into UI fields — same contract as Android `ResultParser`.
 *
 * Recognize: `errorCode`, `documentName`, `ocr`, `mrz`, `images`.
 * Locate: `score` (type confidence) and `position.corners`.
 */
enum ResultParser {
    private static let longValue = 300

    private static let skipKeys: Set<String> = [
        "checkSums", "contrastPrint", "docFormat", "mrzFormat",
        "mrzFormatCheckdigit", "mrzStringsWithCorrectCheckSums",
        "numberChecksumValidity", "numberValidity", "overallValidity",
        "symbolMatrix", "images",
    ]

    static func pretty(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "(empty response)" }
        guard let data = trimmed.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) else {
            return summarizeLong(trimmed)
        }
        let sanitized = sanitize(obj)
        guard let out = try? JSONSerialization.data(withJSONObject: sanitized, options: [.prettyPrinted]),
              let text = String(data: out, encoding: .utf8) else {
            return summarizeLong(trimmed)
        }
        return text
    }

    /// Replace string values longer than `longValue` with type + size (Android).
    private static func sanitize(_ value: Any) -> Any {
        if let dict = value as? [String: Any] {
            return dict.mapValues { sanitize($0) }
        }
        if let arr = value as? [Any] {
            return arr.map { sanitize($0) }
        }
        if let s = value as? String, s.count > longValue {
            return summarizeLong(s)
        }
        return value
    }

    static func summarizeLong(_ value: String) -> String {
        let type: String
        if value.hasPrefix("/9j/") || value.hasPrefix("data:image/jpeg") {
            type = "jpeg"
        } else if value.hasPrefix("iVBOR") || value.hasPrefix("data:image/png") {
            type = "png"
        } else if value.hasPrefix("R0lGOD") || value.hasPrefix("data:image/gif") {
            type = "gif"
        } else if value.hasPrefix("Qk"), value.count > 100 {
            type = "bmp"
        } else if value.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "+" || $0 == "/" || $0 == "=" }) {
            type = "base64"
        } else {
            type = "string"
        }
        return "\(type), \(value.count) chars"
    }

    static func summary(_ raw: String) -> String {
        guard let obj = jsonObject(raw) else { return String(raw.prefix(200)) }
        if let msg = obj["msg"] as? String { return msg }
        let err = (obj["errorCode"] as? NSNumber)?.intValue ?? -1
        let scoreS: String
        if let n = obj["score"] as? NSNumber {
            scoreS = String(format: "%.3f", n.doubleValue)
        } else {
            scoreS = "—"
        }
        var s = "Status: \(err == 0 ? "OK" : "Failed") (errorCode=\(err))\n"
        s += "Document: \((obj["documentName"] as? String) ?? "—")\n"
        s += "Country: \((obj["countryName"] as? String) ?? "—")\n"
        s += "Verification: \(overallVerificationLabel(obj))\n"
        s += "Score: \(scoreS)"
        if let lic = obj["licenseError"] as? String, !lic.isEmpty {
            s += "\nLicense: \(lic)"
        }
        return s
    }

    static func rows(_ raw: String) -> [FieldRow] {
        guard let obj = jsonObject(raw) else { return [] }
        var out: [FieldRow] = [
            FieldRow(key: "documentName", value: obj["documentName"] as? String ?? "", source: "meta"),
            FieldRow(key: "countryName", value: obj["countryName"] as? String ?? "", source: "meta"),
            FieldRow(key: "score", value: obj["score"].map { "\($0)" } ?? "—", source: "meta"),
            FieldRow(key: "errorCode", value: obj["errorCode"].map { "\($0)" } ?? "", source: "meta"),
        ]
        out += rowsFromVerification(obj)
        out += rowsFromImageQuality(obj["imageQuality"])
        out += rowsFromMap(obj["ocr"] as? [String: Any], source: "OCR")
        out += rowsFromMap(obj["mrz"] as? [String: Any], source: "MRZ")
        out += rowsFromMap(obj["barcode"] as? [String: Any], source: "Barcode")
        return out.filter { !$0.value.isEmpty && $0.value != "null" }
    }

    /// Images from response `images[]`, labeled by category (`name` / fieldName).
    /// One entry per category+source (and per unique payload) so page 0/1 copies
    /// of the same Portrait / Document crop are not shown twice.
    static func images(_ raw: String) -> [ResultImage] {
        guard let obj = jsonObject(raw), let arr = obj["images"] as? [Any] else { return [] }
        var out: [ResultImage] = []
        var seenKey = Set<String>()
        for item in arr {
            let b64: String
            let category: String
            let source: String
            if let s = item as? String {
                b64 = s
                category = "Image"
                source = ""
            } else if let d = item as? [String: Any] {
                b64 = (d["image"] as? String) ?? (d["value"] as? String) ?? (d["data"] as? String) ?? ""
                let rawName = (d["name"] as? String) ?? (d["fieldName"] as? String) ?? (d["role"] as? String) ?? ""
                category = rawName.isEmpty ? "Image" : rawName
                source = d["source"] as? String ?? ""
            } else {
                continue
            }
            if b64.count < 32 { continue }
            let key = "\(category.lowercased())|\(source.lowercased())"
            if !seenKey.insert(key).inserted { continue }
            guard let image = decodeBase64Image(b64) else { continue }
            out.append(ResultImage(category: category, source: source, image: image))
        }
        return out
    }

    static func decodeBase64Image(_ b64: String) -> UIImage? {
        var clean = b64
        if let range = b64.range(of: "base64,") {
            clean = String(b64[range.upperBound...])
        }
        guard let data = Data(base64Encoded: clean, options: [.ignoreUnknownCharacters]) else { return nil }
        return UIImage(data: data)
    }

    /// ID-type confidence 0–100 from OneCandidate.P (`score`).
    /// Does **not** use DocumentPosition.objArea (frame fill %, not
    /// “how sure this is a real ID card”).
    static func documentPercent(_ raw: String) -> Int {
        guard let obj = jsonObject(raw), obj["score"] != nil,
              let n = obj["score"] as? NSNumber else { return 0 }
        let s = n.doubleValue
        let pct = s <= 1.0 ? s * 100.0 : s
        return max(0, min(100, Int(pct)))
    }

    /// Optional framing metric: how much of the image the document occupies (0–100).
    static func documentFillPercent(_ raw: String) -> Int {
        guard let obj = jsonObject(raw),
              let pos = obj["position"] as? [String: Any] else { return 0 }
        let area: Int
        if let n = pos["objArea"] as? NSNumber {
            area = n.intValue
        } else if let n = pos["ObjArea"] as? NSNumber {
            area = n.intValue
        } else {
            return 0
        }
        return (0...100).contains(area) ? area : 0
    }

    /**
     * Document corners in **bitmap / locate-input** pixel space:
     * LeftTop, RightTop, RightBottom, LeftBottom.
     */
    static func documentCorners(_ raw: String) -> [CGPoint]? {
        guard let obj = jsonObject(raw),
              let pos = obj["position"] as? [String: Any] else { return nil }
        if let arr = pos["corners"] as? [[String: Any]], arr.count >= 4 {
            var out: [CGPoint] = []
            for i in 0..<4 {
                let p = arr[i]
                let x = (p["x"] as? NSNumber)?.doubleValue ?? .nan
                let y = (p["y"] as? NSNumber)?.doubleValue ?? .nan
                if x.isNaN || y.isNaN { return nil }
                out.append(CGPoint(x: x, y: y))
            }
            return out
        }
        let l = (pos["left"] as? NSNumber)?.doubleValue ?? .nan
        let t = (pos["top"] as? NSNumber)?.doubleValue ?? .nan
        let r = (pos["right"] as? NSNumber)?.doubleValue ?? .nan
        let b = (pos["bottom"] as? NSNumber)?.doubleValue ?? .nan
        if l.isNaN || t.isNaN || r.isNaN || b.isNaN { return nil }
        if r <= l || b <= t { return nil }
        return [
            CGPoint(x: l, y: t),
            CGPoint(x: r, y: t),
            CGPoint(x: r, y: b),
            CGPoint(x: l, y: b),
        ]
    }

    /// Reject engine junk from empty frames (negative coords, tiny/degenerate quads).
    /// iOS camera overlay helper (not in Android ResultParser).
    static func isPlausibleCardQuad(_ corners: [CGPoint]) -> Bool {
        guard corners.count >= 4 else { return false }
        var minX = CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude
        var off = 0
        for p in corners {
            if !p.x.isFinite || !p.y.isFinite { return false }
            if p.x < -8 || p.y < -8 { off += 1 }
            minX = min(minX, p.x)
            minY = min(minY, p.y)
            maxX = max(maxX, p.x)
            maxY = max(maxY, p.y)
        }
        if off >= 2 { return false }
        return (maxX - minX) >= 40 && (maxY - minY) >= 24
    }

    private static func jsonObject(_ raw: String) -> [String: Any]? {
        guard let data = raw.trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return adaptUnifiedWire(obj)
    }

    /// Android DocSDK wire → flat FacePlugin codes the Result UI expects (unchanged labels).
    private static func adaptUnifiedWire(_ obj: [String: Any]) -> [String: Any] {
        var out = obj
        if let raw = obj["verification"] as? [String: Any],
           isNestedAndroidVerification(raw) {
            out["verification"] = flattenAndroidVerification(raw)
        }
        adaptImageQualityChecks(&out)
        return out
    }

    private static let verifyCheckKeys = [
        "docType", "expiry", "text", "mrz", "security", "imageQA", "portrait",
    ]

    private static func isNestedAndroidVerification(_ v: [String: Any]) -> Bool {
        guard let checks = v["checks"] as? [String: Any] else { return false }
        return checks.values.contains { $0 is [String: Any] }
    }

    private static func opticalOverallToFacePlugin(_ code: Int) -> Int {
        if code == 1 { return 0 }
        if code == 0 { return 1 }
        return code
    }

    private static func opticalCheckToFacePlugin(_ code: Int) -> Int {
        if code == 1 { return 0 }
        if code == 0 { return 1 }
        return code
    }

    private static func flattenAndroidVerification(_ raw: [String: Any]) -> [String: Any] {
        var v: [String: Any] = [:]
        if let overallRaw = statusCode(raw["result"] ?? raw["overall"]) {
            v["overall"] = opticalOverallToFacePlugin(overallRaw)
        }
        var reasons: [String: [String]] = [:]
        if let checks = raw["checks"] as? [String: Any] {
            for key in verifyCheckKeys {
                guard let cell = checks[key] else { continue }
                if let c = cell as? [String: Any] {
                    if let n = statusCode(c["result"] ?? c["Result"]) {
                        v[key] = opticalCheckToFacePlugin(n)
                    }
                    if let reason = c["reason"] as? String,
                       !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        reasons[key] = [reason.trimmingCharacters(in: .whitespacesAndNewlines)]
                    }
                } else if let n = statusCode(cell) {
                    v[key] = opticalCheckToFacePlugin(n)
                }
            }
        }
        if let existing = raw["reasons"] as? [String: Any] {
            for (key, val) in existing {
                reasons[key] = stringList(val)
            }
        }
        if !reasons.isEmpty { v["reasons"] = reasons }
        return v
    }

    /// Android wire QA scores (0…1 floats) → CheckResult ints for Image QA rows.
    private static func numericValue(_ value: Any?) -> Double? {
        if let n = value as? NSNumber { return n.doubleValue }
        if let s = value as? String, let d = Double(s) { return d }
        return nil
    }

    private static func qaScoreToCheckResult(_ value: Any?) -> Int? {
        guard let n = numericValue(value) else { return nil }
        let rounded = n.rounded()
        if abs(n - rounded) < 1e-9 {
            let i = Int(rounded)
            if i == 0 || i == 1 || i == 2 { return i }
        }
        if n > 0 && n <= 1 { return n >= 0.9 ? 1 : 0 }
        return nil
    }

    private static func checkResultCode(_ value: Any?) -> Int? {
        if let code = qaScoreToCheckResult(value) { return code }
        return statusCode(value)
    }

    private static func adaptImageQualityChecks(_ obj: inout [String: Any]) {
        let extracted = imageQualityChecks(obj["imageQuality"])
        guard !extracted.isEmpty else { return }
        var checks: [String: Any] = [:]
        for (key, val) in extracted {
            checks[key] = qaScoreToCheckResult(val) ?? val
        }
        obj["imageQuality"] = ["checks": checks]
    }

    static func securitySummary(_ raw: String) -> String {
        guard let obj = jsonObject(raw), let sec = obj["security"] as? [String: Any] else {
            return "No security checks in this response. If you expected checks, this license may not include liveness."
        }
        let pages = securityPages(sec)
        let docLabel = nonemptyString(sec["label"]) ?? statusCell(sec["overall"])
        guard !pages.isEmpty else {
            if docLabel.isEmpty {
                return "No security checks in this response."
            }
            return "Document: \(docLabel)\nNo per-page checks in this response."
        }
        var s = "Document: \(docLabel.isEmpty ? "—" : docLabel)"
        for page in pages {
            let name = pageSide(page["pageIndex"])
            let pageLabel = nonemptyString(page["label"]) ?? statusCell(page["overall"])
            s += "\n\(name): \(pageLabel.isEmpty ? "—" : pageLabel)"
        }
        return s
    }

    static func securityRows(_ raw: String) -> [SecurityRow] {
        guard let obj = jsonObject(raw), let sec = obj["security"] as? [String: Any] else { return [] }
        var out: [SecurityRow] = []
        if securityPages(sec).isEmpty {
            let docLabel = nonemptyString(sec["label"]) ?? statusCell(sec["overall"])
            if !docLabel.isEmpty {
                return [SecurityRow(page: "—", check: "Overall", status: docLabel)]
            }
            return []
        }
        for page in securityPages(sec) {
            let name = pageSide(page["pageIndex"])
            let pageLabel = nonemptyString(page["label"]) ?? statusCell(page["overall"])
            out.append(SecurityRow(page: name, check: "Overall", status: pageLabel.isEmpty ? "—" : pageLabel))
            for (key, rawValue) in page where !securityPageMeta.contains(key) {
                appendSecurityValue(&out, pageName: name, key: key, raw: rawValue)
            }
        }
        return out
    }

    private static let securityPageMeta: Set<String> = [
        "pageIndex", "overall", "label", "pages", "presentation",
    ]

    private static func nonemptyString(_ value: Any?) -> String? {
        guard let s = value as? String, !s.isEmpty else { return nil }
        return s
    }

    private static func securityPages(_ sec: [String: Any]) -> [[String: Any]] {
        if let pages = sec["pages"] as? [[String: Any]], !pages.isEmpty {
            return pages
        }
        var flat: [String: Any] = [:]
        for (key, value) in sec where !securityPageMeta.contains(key) {
            flat[key] = value
        }
        guard !flat.isEmpty else { return [] }
        if let overall = sec["overall"] { flat["overall"] = overall }
        if let label = sec["label"] { flat["label"] = label }
        flat["pageIndex"] = 0
        return [flat]
    }

    private static func pageSide(_ value: Any?) -> String {
        let n = (value as? NSNumber)?.intValue ?? (value as? Int) ?? 0
        if n == 0 { return "Front" }
        if n == 1 { return "Back" }
        return "Page \(n)"
    }

    private static func humanizeKey(_ key: String) -> String {
        var spaced = ""
        for ch in key {
            if ch.isUppercase && !spaced.isEmpty { spaced += " " }
            spaced.append(ch)
        }
        spaced = spaced.trimmingCharacters(in: .whitespaces)
        guard let first = spaced.first else { return key }
        return String(first).uppercased() + spaced.dropFirst()
    }

    private static func checkTitle(_ key: String, _ raw: Any?) -> String {
        if let dict = raw as? [String: Any], let title = dict["title"] as? String, !title.isEmpty {
            return title
        }
        return humanizeKey(key)
    }

    private static func statusKind(_ value: Any?) -> String {
        var v = value
        if let dict = v as? [String: Any] {
            if dict["score"] != nil && !(dict["score"] is [String: Any]) { return "score" }
            v = dict["result"] ?? dict["label"]
        }
        if v is NSNumber { return "score" }
        let s = "\(v ?? "")".trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "_", with: "")
        switch s {
        case "success", "pass", "ok", "authentic", "1": return "success"
        case "notchecked", "wasnotdone", "2": return "notChecked"
        case "fail", "failed", "error", "notauthentic", "0": return "fail"
        default: return "other"
        }
    }

    private static func formatScore(_ value: Any?) -> String {
        let n: Double?
        if let num = value as? NSNumber { n = num.doubleValue }
        else if let s = value as? String { n = Double(s) }
        else { n = nil }
        guard let n else { return "\(value ?? "")" }
        var s = String(format: "%.1f", n)
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return "\(s.isEmpty ? "0" : s)%"
    }

    private static func statusCell(_ value: Any?) -> String {
        switch statusKind(value) {
        case "success": return "Pass"
        case "notChecked": return "Not checked"
        case "fail": return "Fail"
        case "score":
            if let dict = value as? [String: Any] {
                return formatScore(dict["score"] ?? dict["result"])
            }
            return formatScore(value)
        default:
            if let dict = value as? [String: Any] {
                return "\(dict["result"] ?? dict["label"] ?? "")"
            }
            return "\(value ?? "")"
        }
    }

    private static func appendSecurityValue(
        _ rows: inout [SecurityRow],
        pageName: String,
        key: String,
        raw: Any?
    ) {
        let title = checkTitle(key, raw)
        guard let dict = raw as? [String: Any] else {
            rows.append(SecurityRow(page: pageName, check: title, status: statusCell(raw)))
            return
        }
        if dict["score"] != nil && !(dict["score"] is [String: Any]) {
            rows.append(SecurityRow(page: pageName, check: title, status: statusCell(raw)))
            return
        }
        let kind = statusKind(raw)
        rows.append(SecurityRow(page: pageName, check: title, status: statusCell(dict["result"])))
        guard let checks = dict["checks"] as? [String: Any] else { return }
        if kind != "fail" && !checks.values.contains(where: { statusKind($0) == "fail" }) {
            return
        }
        for (ck, cv) in checks {
            if statusKind(cv) == "notChecked" && kind != "fail" { continue }
            rows.append(SecurityRow(
                page: pageName,
                check: "  → \(checkTitle(ck, cv))",
                status: statusCell(cv)
            ))
        }
    }

    /// Same as Android: skip nested objects/arrays; scalars only.
    private static func rowsFromMap(_ data: [String: Any]?, source: String) -> [FieldRow] {
        guard let data else { return [] }
        var out: [FieldRow] = []
        for key in data.keys.sorted() {
            if skipKeys.contains(key) { continue }
            if key.hasPrefix("field"), key.dropFirst(5).allSatisfy(\.isNumber) { continue }
            let value = data[key]!
            if value is [String: Any] || value is [Any] { continue }
            out.append(FieldRow(key: key, value: "\(value)", source: source))
        }
        return out
    }

    /// Status / verification in this engine: 0=OK, 1=fail, 2=was-not-done.
    private static func statusCode(_ value: Any?) -> Int? {
        if let n = value as? NSNumber { return n.intValue }
        if let s = value as? String, let n = Int(s) { return n }
        return nil
    }

    private static func overallLabel(_ code: Int) -> String {
        switch code {
        case 0: return "Verified"
        case 1: return "Not verified"
        case 2: return "Not checked"
        default: return "\(code)"
        }
    }

    private static func checkLabel(_ code: Int) -> String {
        switch code {
        case 0: return "Pass"
        case 1: return "Fail"
        case 2: return "Not checked"
        default: return "\(code)"
        }
    }

    /// ImageQualityCheckList `result` is CheckResult: 0=ERROR, 1=OK, 2=WAS_NOT_DONE.
    private static func checkResultLabel(_ code: Int) -> String {
        switch code {
        case 0: return "Fail"
        case 1: return "Pass"
        case 2: return "Not checked"
        default: return "\(code)"
        }
    }

    private static func worseCheckResult(_ a: Int, _ b: Int) -> Int {
        if a == 0 || b == 0 { return 0 }
        if a == 2 || b == 2 { return 2 }
        return 1
    }

    private static func checkResultToStatus(_ checkResult: Int) -> Int {
        if checkResult == 0 { return 1 }
        if checkResult == 2 { return 2 }
        return 0
    }

    /// Derive Status imageQA from CheckResult checks so Verify matches Image QA rows.
    private static func imageQaStatusFromChecks(_ obj: [String: Any]) -> Int? {
        let checks = imageQualityChecks(obj["imageQuality"])
        guard !checks.isEmpty else { return nil }
        var worst = 1
        var any = false
        for (_, val) in checks {
            guard let code = checkResultCode(val) else { continue }
            any = true
            worst = worseCheckResult(worst, code)
        }
        return any ? checkResultToStatus(worst) : nil
    }

    private static func labelValue(_ value: Any?, overall: Bool, reasons: [String] = []) -> String {
        var label: String
        if let code = statusCode(value) {
            label = overall ? overallLabel(code) : checkLabel(code)
            if code == 1, !reasons.isEmpty {
                return "\(label) (\(reasons.joined(separator: ", ")))"
            }
            return label
        }
        if let s = value as? String, !s.isEmpty { return s }
        return value.map { "\($0)" } ?? ""
    }

    private static func stringList(_ value: Any?) -> [String] {
        if let arr = value as? [Any] {
            return arr.compactMap { item in
                if let s = item as? String, !s.isEmpty { return s }
                if let n = item as? NSNumber { return "\(n)" }
                return nil
            }
        }
        if let s = value as? String, !s.isEmpty { return [s] }
        return []
    }

    private static func verificationMap(_ obj: [String: Any]) -> [String: Any]? {
        var v: [String: Any]
        if let existing = obj["verification"] as? [String: Any], !existing.isEmpty {
            v = existing
        } else if let st = obj["status"] as? [String: Any] {
            v = [:]
            if let overall = st["overallStatus"] { v["overall"] = overall }
            if let opt = st["detailsOptical"] as? [String: Any] {
                for key in ["docType", "expiry", "text", "mrz", "security", "imageQA"] {
                    if let val = opt[key] { v[key] = val }
                }
            }
            if let portrait = st["portrait"] { v["portrait"] = portrait }
            if v.isEmpty { return nil }
        } else {
            return nil
        }
        if let qa = imageQaStatusFromChecks(obj) {
            v["imageQA"] = qa
            if var reasons = v["reasons"] as? [String: Any] {
                reasons.removeValue(forKey: "imageQA")
                v["reasons"] = reasons
            }
        }
        return v
    }

    private static func failedImageQaReasons(_ obj: [String: Any]) -> [String] {
        let checks = imageQualityChecks(obj["imageQuality"])
        var out: [String] = []
        var seen = Set<String>()
        for key in imageQAOrder {
            guard checkResultCode(checks[key]) == 0 else { continue }
            seen.insert(key)
            out.append(key)
        }
        for key in checks.keys.sorted() where !seen.contains(key) {
            guard checkResultCode(checks[key]) == 0 else { continue }
            out.append(key)
        }
        return out
    }

    private static func failedAuthReasons(_ value: Any?) -> [String] {
        var out: [String] = []
        func walk(_ node: Any?) {
            if let arr = node as? [Any] {
                arr.forEach { walk($0) }
                return
            }
            guard let d = node as? [String: Any] else { return }
            for key in ["liveness", "barcode", "IPI", "ipi", "imagePattern", "faceMatch", "photoEmbedding"] {
                if let n = d[key] as? NSNumber, n.intValue == 0 {
                    out.append(key)
                } else if let items = d[key] as? [Any] {
                    for item in items {
                        guard let e = item as? [String: Any] else { continue }
                        let result = statusCode(e["result"] ?? e["elementResult"]) ?? 1
                        guard result == 0 else { continue }
                        if let t = e["type"] as? String, !t.isEmpty {
                            out.append(t)
                        } else if let t = e["elementDiagnoseName"] as? String, !t.isEmpty {
                            out.append(t)
                        } else {
                            out.append(key)
                        }
                    }
                }
            }
        }
        walk(value)
        return out
    }

    private static func reasonsForCheck(_ key: String, verification: [String: Any], obj: [String: Any]) -> [String] {
        if let stored = (verification["reasons"] as? [String: Any]).flatMap({ stringList($0[key]) }),
           !stored.isEmpty {
            return stored
        }
        switch key {
        case "imageQA":
            return failedImageQaReasons(obj)
        case "security":
            return failedAuthReasons(obj["authenticity"])
        case "docType":
            return ["not recognized"]
        case "expiry":
            return ["expired"]
        case "text":
            return ["comparison failed"]
        case "mrz":
            return ["checksums"]
        case "portrait":
            return ["mismatch"]
        case "overall":
            return ["docType", "expiry", "text", "mrz", "security", "imageQA", "portrait"].filter {
                statusCode(verification[$0]) == 1
            }
        default:
            return []
        }
    }

    private static func overallVerificationLabel(_ obj: [String: Any]) -> String {
        guard let v = verificationMap(obj), let overall = v["overall"] else {
            return "Not checked"
        }
        return labelValue(overall, overall: true, reasons: reasonsForCheck("overall", verification: v, obj: obj))
    }

    private static func rowsFromVerification(_ obj: [String: Any]) -> [FieldRow] {
        guard let v = verificationMap(obj) else { return [] }
        var out: [FieldRow] = []
        if let overall = v["overall"] {
            out.append(FieldRow(
                key: "overall",
                value: labelValue(overall, overall: true, reasons: reasonsForCheck("overall", verification: v, obj: obj)),
                source: "Verify"
            ))
        }
        for key in ["docType", "expiry", "text", "mrz", "security", "imageQA", "portrait"] {
            guard let val = v[key] else { continue }
            out.append(FieldRow(
                key: key,
                value: labelValue(val, overall: false, reasons: reasonsForCheck(key, verification: v, obj: obj)),
                source: "Verify"
            ))
        }
        return out
    }

    private static let imageQAOrder = [
        "focus", "glares", "resolution", "colorness", "perspective",
        "bounds", "portrait", "handwritten", "brightness", "occlusion",
    ]

    private static func imageQualityChecks(_ value: Any?) -> [String: Any] {
        if let d = value as? [String: Any] {
            if let checks = d["checks"] as? [String: Any] { return checks }
            let known = Set(imageQAOrder)
            let named = d.filter { known.contains($0.key) && !($0.value is [String: Any] || $0.value is [Any]) }
            if !named.isEmpty { return named }
        }
        var out: [String: Any] = [:]
        let pages: [Any]
        if let arr = value as? [Any] {
            pages = arr
        } else if let d = value as? [String: Any], let list = d["list"] as? [Any] {
            pages = [list]
        } else {
            return out
        }
        for page in pages {
            let checks: [Any]
            if let d = page as? [String: Any] {
                if let named = d["checks"] as? [String: Any] {
                    for (k, v) in named { out[k] = v }
                    continue
                }
                checks = (d["list"] as? [Any]) ?? []
            } else if let arr = page as? [Any] {
                checks = arr
            } else {
                continue
            }
            for item in checks {
                guard let c = item as? [String: Any] else { continue }
                let result = c["result"] ?? c["Result"]
                let name = (c["id"] as? String) ?? (c["name"] as? String)
                if let name, !name.isEmpty {
                    out[name] = result as Any
                    continue
                }
                let type = statusCode(c["type"] ?? c["Type"])
                let id: String
                switch type {
                case 0: id = "glares"
                case 1: id = "focus"
                case 2: id = "resolution"
                case 3: id = "colorness"
                case 4: id = "perspective"
                case 5: id = "bounds"
                case 7: id = "portrait"
                case 8: id = "handwritten"
                case 9: id = "brightness"
                case 10: id = "occlusion"
                case let t?: id = "\(t)"
                default: continue
                }
                out[id] = result as Any
            }
        }
        return out
    }

    private static func imageQaValue(_ value: Any?) -> String {
        if let code = checkResultCode(value) {
            return checkResultLabel(code)
        }
        if let s = value as? String, !s.isEmpty { return s }
        return value.map { "\($0)" } ?? ""
    }

    private static func rowsFromImageQuality(_ value: Any?) -> [FieldRow] {
        let checks = imageQualityChecks(value)
        guard !checks.isEmpty else { return [] }
        var out: [FieldRow] = []
        var seen = Set<String>()
        for key in imageQAOrder {
            guard let val = checks[key] else { continue }
            seen.insert(key)
            out.append(FieldRow(key: key, value: imageQaValue(val), source: "Image QA"))
        }
        for key in checks.keys.sorted() where !seen.contains(key) {
            out.append(FieldRow(key: key, value: imageQaValue(checks[key]), source: "Image QA"))
        }
        return out
    }
}
