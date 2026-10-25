import Foundation

enum CHMPXML {
    static func getStatus(serviceType: String) -> Data {
        let xml = """
        <?xml version="1.0" encoding="utf-8" ?>
        <cmd xmlns:ivec="http://www.canon.com/ns/cmd/2008/07/common/">
        <ivec:contents><ivec:operation>GetStatus</ivec:operation>
        <ivec:param_set servicetype="\(serviceType)"></ivec:param_set>
        </ivec:contents></cmd>
        """
        return Data(xml.utf8)
    }

    /// Windows IJ Assistant `Send_PowerOff` body (device service).
    static func powerOff() -> Data {
        let xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <cmd xmlns:ivec="http://www.canon.com/ns/cmd/2008/07/common/"><ivec:contents><ivec:operation>PowerOff</ivec:operation><ivec:param_set servicetype="device"></ivec:param_set></ivec:contents></cmd>
        """
        return Data(xml.utf8)
    }

    static func parsePowerOffResponse(_ data: Data) throws {
        let text = String(data: data, encoding: .utf8) ?? ""
        guard text.contains("PowerOffResponse") else {
            throw AppError.parse("missing PowerOffResponse")
        }
    }

    static func parseGetStatusResponse(_ data: Data) throws -> PrinterStatus {
        let text = String(data: data, encoding: .utf8) ?? ""
        guard text.contains("GetStatusResponse") else {
            throw AppError.parse("missing GetStatusResponse")
        }
        let statusValue = firstTag(text, named: "ivec:status") ?? firstTag(text, named: "status") ?? "unknown"
        let model = firstCDATA(text, after: "mdl=") // optional; may be absent
        let idle = statusValue.lowercased() == "idle"
        return PrinterStatus(isIdle: idle, detail: statusValue, model: model)
    }

    private static func firstTag(_ xml: String, named name: String) -> String? {
        guard let start = xml.range(of: "<\(name)>") else {
            // self-closing or empty
            if xml.contains("<\(name)/>") || xml.contains("<\(name) />") { return "" }
            // try without namespace
            return nil
        }
        let after = xml[start.upperBound...]
        guard let end = after.range(of: "</\(name)>") else { return nil }
        return String(after[..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func firstCDATA(_ xml: String, after marker: String) -> String? {
        // Device GetStatus may include redirect_url with mdl=G3010+series
        guard let r = xml.range(of: marker) else { return nil }
        let rest = xml[r.upperBound...]
        let end = rest.firstIndex(where: { $0 == "&" || $0 == "\"" || $0 == " " }) ?? rest.endIndex
        return String(rest[..<end]).replacingOccurrences(of: "+", with: " ")
    }
}
