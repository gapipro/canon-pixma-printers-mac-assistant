import Foundation

struct PrinterDevice: Identifiable, Codable, Hashable {
    var id: String { host }
    var name: String
    var host: String
    var model: String

    var displayName: String { "\(name) (\(host))" }
}
