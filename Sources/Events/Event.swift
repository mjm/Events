import Foundation

/// An Event structure holds the information for a complete loggable event in your application.
///
/// You are not expected to construct an `Event` yourself. Instead, use an `EventBuilder` to set up your events. When you
/// tell the event builder to send the event, it creates an `Event` for you and sends it to the event sink.
///
/// The only way to access the data in an `Event` is by using an encoder to encode it.
///
/// `Event` also includes some static properties that serve a few purposes:
///
/// - Provide some special `EventBuilder`s: `current` and `global`.
/// - Allow configuring the behavior of events.
public struct Event: Encodable {
    var timestamp: Date
    var error: Error?
    var message: StaticString = ""
    var fields: [Event.Key: AnyEncodable]

    /// Encodes the data in the event to an `Encoder`.
    ///
    /// For encoders that care about the order of keys that are encoded, events encode fields in the following order:
    ///
    /// - `Event.Key.error`, if present
    /// - `Event.Key.message`
    /// - Any app-specific custom keys, sorted alphabetically.
    ///
    /// - Parameters:
    ///    - encoder: The encoder to use to encode the event data.
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
