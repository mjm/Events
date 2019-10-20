import Foundation

struct AnyEncodable: Encodable {
    var value: Any
    private var encode: (inout SingleValueEncodingContainer) throws -> ()
    
    init<T: Encodable>(_ value: T) {
        self.value = value
        encode = { container in
            try container.encode(value)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try encode(&container)
    }
}
