import Foundation
import os

/// An EventBuilder is what your app uses to add information to events and send them when they're complete.
///
/// ## Using the current event
///
/// `Event.current` is an event builder that different parts of your app can use to attach custom data to a currently in-progress
/// event. Various parts of your app can add fields to the current event without having to coordinate passing the event around or even
/// having to know about each other.
///
/// When the work corresponding to an event is complete, be sure to send the current event. When you do, the current event will be
/// reset to a blank slate so that the next action can start adding information for the next event.
///
/// ## Attaching fields to all events
///
/// `Event.global` is an event builder that is not meant to be sent. Instead, you can add fields to the global event builder, and those
/// fields will be included automatically in all events.
public struct EventBuilder {
    /// An error that should be logged with the event.
    ///
    /// Since needing to log errors is a very common case, you can use this field instead of having to define an event key for errors in your app.
    /// When encoding the event, the error's `localizedDescription` will be encoded in the `err` key of the event.
    ///
    /// Generally, for consistency, you should always use this property to log an error, but there may be cases where a single event can generate
    /// multiple errors because it doesn't stop short in the case of an error. In this situation, it's fine to define custom event keys for each error
    /// and store both on the event.
    public var error: Error?

    var fields: [Event.Key: AnyEncodable] = [:]
    var lazyFields: [Event.Key: () -> AnyEncodable] = [:]
    private var timers: [Event.Key: UInt64] = [:]

    private let sink: EventSink

    /// Create a new `EventBuilder`.
    ///
    /// Think carefully before constructing an `EventBuilder` directly. Most of the time, you'll want to use `Event.current` to avoid
    /// having to pass the event around to different parts of your app explicitly. However, if you have background work that may be happening
    /// concurrently with user actions, you'll want to let the user actions use `Event.current` and create a separate `EventBuilder`
    /// for the background work to use so that you can log those events separately.
    ///
    /// - Parameters:
    ///    - sink: A different event sink to use than the default that is set at `Event.sink`.
    ///
    public init(sink: EventSink = Event.sink) {
        self.sink = sink
    }

    /// Get or set custom fields to include app-specific data in your events
    ///
    /// This is the primary way to include dynamic data in your events. You should define an `Event.Key` for each field you want to include,
    /// then use the subscript to assign data to that field in your app. The value you assign can be anything `Encodable`, though depending
    /// on the event sink you use and the encoder it uses, there may be limitations on what values can actually be encoded in the event. For
    /// example, the `OSLogEventSink` does not currently support nested keys, so your values need to encode to a flat structure.
    ///
    /// - Parameters:
    ///    - key: The key of the data in the event.
    /// - Returns: The encodable value associated with the key in the event.
    ///
    public subscript<T: Encodable>(_ key: Event.Key) -> T? {
        get {
            fields[key] as? T
        }
        set {
            fields[key] = AnyEncodable(newValue)
        }
    }

    /// Set a custom field to a value that will be evaluated on-demand when the event is sent.
    ///
    /// This is very similar to normal field assignment, but instead of providing the value directly, you must provide a closure that returns the value
    /// you want to be included in the event. When the event is about to be sent, the closure will be called, and the result will be used as the field
    /// value.
    ///
    /// If you reuse the event builder, either by making copies and sending those or by setting closures for fields in `Event.global`, the result
    /// of the closure will not be cached: it will be called each time an event is sent that included that field. This kind of field is useful for including
    /// dynamic system state in your events that may change at any time.
    ///
    /// - Parameters:
    ///    - key: The key of the data in the event.
    /// - Returns: A closure that returns the encodable value associated with the key in the event.
    ///
    /// - Important: Due to the way on-demand fields are stored, it's not possible to get the closure that was originally set for the field back
    ///   out later. Attempting to do so will result in a `fatalError()`, because Swift requires a getter for all subscripts.
    ///
    public subscript<T: Encodable>(_ key: Event.Key) -> () -> T {
        get {
            fatalError("Lazy fields cannot be retrieved")
        }
        set {
            lazyFields[key] = { AnyEncodable(newValue()) }
        }
    }

    /// Starts a timer that will store a duration for a given key.
    ///
    /// It can be useful to track durations of specific parts of the work your app does during an event and store those durations as fields in the
    /// event. This method provides an easy way to do that.
    ///
    /// Call `startTimer(_:)` when the work you want to measure begins, then call `stopTimer(_:)` with the same key when it
    /// completes. When you stop the timer, the duration in milliseconds of the work will be stored in the event under `key`.
    ///
    /// - Parameters:
    ///    - key: The key in the event where the timer duration will be stored when stopped.
    ///
    /// - Precondition: There must not be a timer already started for this key.
    public mutating func startTimer(_ key: Event.Key) {
        guard timers[key] == nil else {
            preconditionFailure(
                "Attempted to start timer for key \(key), but there's already a timer going for that key."
            )
        }

        timers[key] = mach_absolute_time()
    }

    /// Stops a timer that was previously started and records the duration in the event.
    ///
    /// The duration is stored as the milliseconds that passed between starting the timer and calling this method.
    ///
    /// - Parameters:
    ///    - key: The key used to start the timer and where the duration will be stored on the event.
    ///
    /// - Precondition: A timer must have been started for this key already.
    public mutating func stopTimer(_ key: Event.Key) {
        let endTime = mach_absolute_time()

        guard let startTime = timers.removeValue(forKey: key) else {
            preconditionFailure("Attempted to stop timer for key \(key), but it was never started.")
        }

        let nanos = (endTime - startTime) * UInt64(timeBase.numer) / UInt64(timeBase.denom)
        self[key] = Double(nanos) / Double(NSEC_PER_MSEC)  // store durations as milliseconds
    }

    /// Send the event to its sink using the default level.
    ///
    /// See `send(_:_:)` for more details on sending events.
    ///
    /// - Parameters:
    ///    - message: A message to describe the event.
    public mutating func send(_ message: StaticString) {
        send(.default, message)
    }

    /// Send the event to its sink at a given level.
    ///
    /// This creates an `Event` based on the current fields in this builder and the global builder, and sends it to the event sink.
    ///
    /// After sending the event, all fields are cleared from the builder so that it can be reused to send a new event. This is primarily to support
    /// reusing `Event.current` in a natural way. If you need to send an event and also keep using the existing fields for it, you can copy
    /// the event into a new `var` and send the copy, and only the copy will be reset. If you find yourself doing this, it may be a sign that
    /// you are sending too many events and should be collapsing more data into less granular events.
    ///
    /// - Parameters:
    ///    - level: The log level to send this event at. Not all sinks will do something useful with this information.
    ///    - message: A message to describe the event. This message cannot include dynamic data. All dynamic data should be added
    ///      as fields on the event.
    ///
    public mutating func send(_ level: OSLogType, _ message: StaticString) {
        let event = makeEvent(message: message)
        sink.send(event: event, level: level)

        // reset for the next event
        error = nil
        fields = [:]
        lazyFields = [:]
        timers = [:]
    }

    mutating func makeEvent(message: StaticString, timestamp: Date = Date()) -> Event {
        let fields = Event.global.resolvedFields.merging(self.resolvedFields) {
            globalValue, localValue in localValue
        }

        return Event(
            timestamp: timestamp,
            error: error,
            message: message,
            fields: fields)
    }

    private var resolvedFields: [Event.Key: AnyEncodable] {
        fields.merging(lazyFields.mapValues { $0() }) { $1 }
    }
}

private let timeBase: mach_timebase_info = {
    var timeBaseInfo = mach_timebase_info()
    mach_timebase_info(&timeBaseInfo)
    return timeBaseInfo
}()
