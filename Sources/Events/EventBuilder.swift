import Foundation
import os

public struct EventBuilder {
    public var error: Error?
    var fields: [Event.Key: AnyEncodable] = [:]
    var lazyFields: [Event.Key: () -> AnyEncodable] = [:]
    private var timers: [Event.Key: Date] = [:]
    
    private let sink: EventSink
    
    public init(sink: EventSink = Event.sink) {
        self.sink = sink
    }
    
    public subscript <T: Encodable>(_ key: Event.Key) -> T? {
        get {
            fields[key] as? T
        }
        set {
            fields[key] = AnyEncodable(newValue)
        }
    }
    
    public subscript <T: Encodable>(_ key: Event.Key) -> () -> T {
        get {
            fatalError("Lazy fields cannot be retrieved")
        }
        set {
            lazyFields[key] = { AnyEncodable(newValue()) }
        }
    }
    
    public mutating func startTimer(_ key: Event.Key) {
        guard timers[key] == nil else {
            preconditionFailure("Attempted to start timer for key \(key), but there's already a timer going for that key.")
        }
        
        timers[key] = Date()
    }
    
    public mutating func stopTimer(_ key: Event.Key) {
        let endTime = Date()
        
        guard let startTime = timers.removeValue(forKey: key) else {
            preconditionFailure("Attempted to stop timer for key \(key), but it was never started.")
        }
        
        let duration = endTime.timeIntervalSinceReferenceDate - startTime.timeIntervalSinceReferenceDate
        self[key] = duration * 1000.0 // store durations as milliseconds
    }
    
    public mutating func send(_ message: String) {
        send(.default, message)
    }
    
    public mutating func send(_ level: OSLogType, _ message: String) {
        let event = makeEvent(message: message)
        sink.send(event: event, level: level)
        
        // reset for the next event
        error = nil
        fields = [:]
    }
    
    mutating func makeEvent(message: String, timestamp: Date = Date()) -> Event {
        let fields = Event.global.resolvedFields.merging(self.resolvedFields) { globalValue, localValue in localValue }
        
        return Event(timestamp: timestamp,
                     error: error,
                     message: message,
                     fields: fields)
    }
    
    private var resolvedFields: [Event.Key: AnyEncodable] {
        fields.merging(lazyFields.mapValues { $0() }) { $1 }
    }
}
