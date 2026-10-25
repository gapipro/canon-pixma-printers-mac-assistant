import Foundation

enum AppError: LocalizedError, Equatable {
    case unreachable(String)
    case authFailed
    case busy(String)
    case endpointMissing(AssistantAction)
    case http(Int, String)
    case parse(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .unreachable(let h): return "Cannot reach printer at \(h)."
        case .authFailed: return "Printer password was rejected."
        case .busy(let d): return "Printer is busy: \(d)"
        case .endpointMissing(let a): return "No mapped endpoint for \(a.title) yet. Open Remote UI in the browser."
        case .http(let c, let b): return "HTTP \(c): \(b)"
        case .parse(let m): return "Could not parse printer response: \(m)"
        case .cancelled: return "Cancelled."
        }
    }
}
