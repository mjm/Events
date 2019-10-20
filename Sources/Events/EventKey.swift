extension Event {
    public enum Key: Hashable, CodingKey, ExpressibleByStringLiteral {
        case time
        case error
        case message
        case custom(String)
        
        public init?(intValue: Int) {
            return nil
        }
        
        public init?(stringValue: String) {
            switch stringValue {
            case "time": self = .time
            case "err": self = .error
            case "msg": self = .message
            default: self = .custom(stringValue)
            }
        }
        
        public init(stringLiteral value: String) {
            self = .custom(value)
        }
        
        public var intValue: Int? { nil }
        public var stringValue: String {
            switch self {
            case .time: return "time"
            case .error: return "err"
            case .message: return "msg"
            case let .custom(key): return key
            }
        }
    }
}
