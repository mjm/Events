import Foundation

public struct Event: Encodable {
    var timestamp: Date
    var error: Error?
    var message: StaticString = ""
    var fields: [Event.Key: AnyEncodable]
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        if let error = error {
            try container.encode(error.localizedDescription, forKey: .error)
        }
        try container.encode(message.asString, forKey: .message)
        
        let sortedKeys = fields.keys.sorted { $0.stringValue < $1.stringValue }
        for key in sortedKeys {
            let value = fields[key]!
            try container.encode(value, forKey: key)
        }
    }
}

extension StaticString {
    var asString: String {
        withUTF8Buffer { buffer in
            String(decoding: buffer, as: UTF8.self)
        }
    }
}
