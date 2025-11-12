import CryptoKit
import Foundation

class Ed25519Signer {
    private let privateKey: Curve25519.Signing.PrivateKey
    
    init?(privateKeyHex: String?) {
        guard let hex = privateKeyHex,
              let data = Data(hexString: hex),
              data.count == 32 else {
            return nil
        }
        guard let key = try? Curve25519.Signing.PrivateKey(rawRepresentation: data) else {
            return nil
        }
        self.privateKey = key
    }
    
    func sign(method: String, path: String, body: String?) -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        let bodyHash = body.map { SHA256.hash(data: $0.data(using: .utf8)!).hexString } ?? ""
        let message = "\(method)|\(path)|\(timestamp)|\(bodyHash)"
        let signature = try! privateKey.signature(for: message.data(using: .utf8)!)
        return "\(timestamp).\(signature.hexString)"
    }
}

// Helper extensions
extension Data {
    init?(hexString: String) {
        let len = hexString.count / 2
        var data = Data(capacity: len)
        for i in 0..<len {
            let j = hexString.index(hexString.startIndex, offsetBy: i*2)
            let k = hexString.index(j, offsetBy: 2)
            let bytes = hexString[j..<k]
            if var num = UInt8(bytes, radix: 16) {
                data.append(&num, count: 1)
            } else {
                return nil
            }
        }
        self = data
    }
    
    var hexString: String {
        map { String(format: "%02hhx", $0) }.joined()
    }
}

extension SHA256.Digest {
    var hexString: String {
        map { String(format: "%02hhx", $0) }.joined()
    }
}
