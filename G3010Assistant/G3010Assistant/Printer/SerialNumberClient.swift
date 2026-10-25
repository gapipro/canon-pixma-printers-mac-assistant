import Foundation
import Network

/// Reads the factory serial over SNMPv1 `public` (Canon enterprise MIB).
/// On many G-series units that serial is also the default Remote UI password.
enum SerialNumberClient {
    /// `iso.org.dod.internet.private.enterprises.canon…serial`
    static let serialOID = [1, 3, 6, 1, 4, 1, 1602, 1, 2, 1, 8, 1, 3, 1, 1]
    static let community = "public"
    static let port: UInt16 = 161

    static func fetchSerial(host: String, timeout: Duration = .seconds(3)) async throws -> String {
        let request = buildGetRequest(requestID: 1)
        let response = try await udpExchange(host: host, payload: request, timeout: timeout)
        return try parseSerial(from: response)
    }

    static func buildGetRequest(requestID: Int) -> Data {
        let oid = berObjectIdentifier(serialOID)
        let null = Data([0x05, 0x00])
        let varbind = berSequence(oid + null)
        let varbindList = berSequence(varbind)
        let pdu = berTagged(
            0xa0,
            berInteger(requestID) + berInteger(0) + berInteger(0) + varbindList
        )
        let body = berInteger(0) + berOctetString(Data(community.utf8)) + pdu
        return berSequence(body)
    }

    static func parseSerial(from response: Data) throws -> String {
        // Walk TLV stream for the first OCTET STRING that looks like a Canon serial.
        var offset = 0
        while offset < response.count {
            guard let (tag, value, next) = try? readTLV(response, offset: offset) else {
                break
            }
            offset = next
            if tag == 0x04, let text = String(data: value, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               isPlausibleSerial(text) {
                return text
            }
            // Dive into constructed values (SEQUENCE / PDU).
            if tag & 0x20 != 0, let nested = try? parseSerial(from: value) {
                return nested
            }
        }
        throw AppError.parse("SNMP response missing serial")
    }

    private static func isPlausibleSerial(_ text: String) -> Bool {
        guard text.count >= 6, text.count <= 32 else { return false }
        guard text != community else { return false }
        return text.unicodeScalars.allSatisfy { CharacterSet.alphanumerics.contains($0) }
    }

    private static func udpExchange(host: String, payload: Data, timeout: Duration) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            let queue = DispatchQueue(label: "local.g3010.snmp")
            let endpoint = NWEndpoint.hostPort(
                host: NWEndpoint.Host(host),
                port: NWEndpoint.Port(rawValue: port)!
            )
            let connection = NWConnection(to: endpoint, using: .udp)
            let lock = NSLock()
            var settled = false
            func finish(_ result: Result<Data, Error>) {
                lock.lock()
                defer { lock.unlock() }
                guard !settled else { return }
                settled = true
                connection.cancel()
                continuation.resume(with: result)
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.send(content: payload, completion: .contentProcessed { error in
                        if let error {
                            finish(.failure(error))
                            return
                        }
                        connection.receiveMessage { content, _, _, error in
                            if let error {
                                finish(.failure(error))
                            } else if let content, !content.isEmpty {
                                finish(.success(content))
                            } else {
                                finish(.failure(AppError.unreachable(host)))
                            }
                        }
                    })
                case .failed(let error):
                    finish(.failure(error))
                case .cancelled:
                    break
                default:
                    break
                }
            }
            connection.start(queue: queue)
            let seconds = Double(timeout.components.seconds) + Double(timeout.components.attoseconds) / 1e18
            queue.asyncAfter(deadline: .now() + seconds) {
                finish(.failure(AppError.unreachable(host)))
            }
        }
    }

    // MARK: - Minimal BER

    private static func berSequence(_ content: Data) -> Data {
        berTagged(0x30, content)
    }

    private static func berTagged(_ tag: UInt8, _ content: Data) -> Data {
        Data([tag]) + berLength(content.count) + content
    }

    private static func berInteger(_ value: Int) -> Data {
        var n = value
        var bytes: [UInt8] = []
        repeat {
            bytes.insert(UInt8(n & 0xff), at: 0)
            n >>= 8
        } while n > 0
        if let first = bytes.first, first & 0x80 != 0 {
            bytes.insert(0, at: 0)
        }
        return Data([0x02, UInt8(bytes.count)]) + Data(bytes)
    }

    private static func berOctetString(_ value: Data) -> Data {
        Data([0x04]) + berLength(value.count) + value
    }

    private static func berObjectIdentifier(_ oid: [Int]) -> Data {
        precondition(oid.count >= 2)
        var body = Data([UInt8(40 * oid[0] + oid[1])])
        for part in oid.dropFirst(2) {
            body.append(berOIDComponent(part))
        }
        return Data([0x06]) + berLength(body.count) + body
    }

    private static func berOIDComponent(_ value: Int) -> Data {
        var n = value
        var stack: [UInt8] = []
        repeat {
            stack.append(UInt8(n & 0x7f))
            n >>= 7
        } while n > 0
        var out = Data()
        for (index, byte) in stack.enumerated().reversed() {
            let isLast = index == 0
            out.append(isLast ? byte : (byte | 0x80))
        }
        return out
    }

    private static func berLength(_ length: Int) -> Data {
        if length < 0x80 {
            return Data([UInt8(length)])
        }
        var n = length
        var bytes: [UInt8] = []
        while n > 0 {
            bytes.insert(UInt8(n & 0xff), at: 0)
            n >>= 8
        }
        return Data([UInt8(0x80 | bytes.count)]) + Data(bytes)
    }

    private static func readTLV(_ data: Data, offset: Int) throws -> (UInt8, Data, Int) {
        guard offset < data.count else { throw AppError.parse("truncated SNMP TLV") }
        let tag = data[offset]
        var i = offset + 1
        guard i < data.count else { throw AppError.parse("truncated SNMP length") }
        let first = data[i]
        i += 1
        let length: Int
        if first & 0x80 == 0 {
            length = Int(first)
        } else {
            let count = Int(first & 0x7f)
            guard count > 0, i + count <= data.count else { throw AppError.parse("bad SNMP length") }
            var value = 0
            for b in data[i..<(i + count)] {
                value = (value << 8) | Int(b)
            }
            i += count
            length = value
        }
        guard i + length <= data.count else { throw AppError.parse("truncated SNMP value") }
        let value = data.subdata(in: i..<(i + length))
        return (tag, value, i + length)
    }
}
