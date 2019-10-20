extension Event {
    /// A key identifier for the different fields you can add to events.
    ///
    /// There are a few predefined keys for fields that will be handled automatically by the Events system, but most fields will be custom, defined by the
    /// needs of your application. You can add custom keys in extensions of `Event.Key` in your app:
    ///
    /// ```
    /// extension Event.Key {
    ///     static let florbCount: Event.Key = "florb_count"
    /// }
    /// ```
    ///
    /// Then you can use this key to set fields on events in your app:
    ///
    /// ```
    /// Event.current[.florbCount] = florbs.count
    /// ```
    ///
    /// The string literal you assign for the key will be the key used for the field when encoding the event.
    public struct Key: Hashable, CodingKey, ExpressibleByStringLiteral {
        /// :nodoc:
        public let stringValue: String
        
        /// Key for storing the timestamp of the event.
        ///
        /// This isn't currently used because `os_log` messages already include the current timestamp.
        ///
        /// - ToDo: This should be used and included when encoding events, and we should find a way to ignore it in
        ///   in situations where we don't want to include the field.
        static let time: Event.Key = "time"
        /// Key for storing the error that occurred on the event.
        ///
        /// You shouldn't need to use this key directly. Instead, use the `EventBuilder.error` property to set the error for an event.
        ///
        /// - Note: This key encodes as `"err"`.
        static let error: Event.Key = "err"
        /// Key for storing the message that was passed when sending the event.
        ///
        /// You shouldn't need to use this key directly. Instead, include your message when calling `EventBuilder.send(_:)`.
        ///
        /// - Note: This key encodes as `"msg"`.
        static let message: Event.Key = "msg"
        
        /// :nodoc:
        public init?(intValue: Int) {
            return nil
        }
        
        /// :nodoc:
        public init?(stringValue: String) {
            self.stringValue = stringValue
        }
        
        /// :nodoc:
        public init(stringLiteral value: String) {
            stringValue = value
        }
        
        /// :nodoc:
        public var intValue: Int? { nil }
    }
}
