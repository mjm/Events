import Foundation
import os
import LogfmtEncoder

/// An EventSink is responsible for sending events to a particular destination.
///
/// The EventSink protocol allows you to control where your events go when you call `EventBuilder.send(_:_:)`. The Events package provides
/// a default EventSink that turns events into formatted log messages and logs them with `os_log`, but you could also send your events to a web
/// service or save them in a database for querying.
///
/// - Warning: Be careful about privacy if you send your events off-device. You should avoid including data in your events that could be considered
///   personally identifiable information (PII).
public protocol EventSink {
    /// Send an event to its destination.
    ///
    /// The implementation of this method should encode the event as necessary and then send or store it as appropriate for the sink. There is no way
    /// to report progress, success, or failure for sending the event. If you need to account for these, that should be contained within your implementation
    /// of this method. Your app will treat sending events as a "fire and forget" system.
    ///
    /// - Parameters:
    ///    - event: The event that needs to be encoded and sent.
    ///    - level: The log level that the event is being sent at. Not all sinks will have use for this parameter, so you may ignore it if it doesn't make
    ///      sense for your sink. While the parameter is an `OSLogType`, it's completely valid for the destination to be somewhere other than `os_log`.
    func send(event: Event, level: OSLogType)
}

extension Event {
    /// The default event sink for events in your application.
    ///
    /// New `EventBuilder`s will use this sink to send their events if no sink is passed in explicitly. In general, you probably don't want to worry about
    /// keeping track of event sinks throughout your app, so when your app launches, you should set this to the sink you want to use.
    ///
    /// The default sink sends events to the default `os_log` logger. It is recommended when using `os_log` to define a custom subsystem and category
    /// specifically for logging your events. To do this, set this property to a custom instance of `OSLogEventSink`:
    ///
    /// ```
    /// Event.sink = OSLogEventSink(subsystem: "com.myapp.App", category: "events")
    /// ```
    public static var sink: EventSink = OSLogEventSink()
}

/// An `EventSink` for logging events to the Apple unified logging system.
///
/// This is the default event sink, but you can and should create one yourself to specify the subsystem and category to use when logging your events. This
/// will make it easier to query for your app's events, which can help filter out log noise.
///
/// - Remark: `os_log` is not actually a particularly good destination for structured, high-cardinality events. The unified logging system doesn't have any
///   understanding of the structure, so you can't do sophisticated queries against your fields, and we have to circumvent the privacy protections that the system
///   has for dynamic values, since we render the entire log string dynamically. The main thing `os_log` has going for it is that it is easily available since it is the
///   default logging system for Apple's platforms.
public class OSLogEventSink: EventSink {
    let log: OSLog
    let encoder: LogfmtEncoder
    
    /// Create a new `os_log` sink, optionally targeting a particular log.
    ///
    /// - Parameters:
    ///    - log: The log to send events to.
    public init(log: OSLog = .default) {
        self.log = log
        self.encoder = LogfmtEncoder()
    }
    
    /// Create a new `os_log` sink for a particular subsystem and category.
    ///
    /// This is a shortcut, and is no different than using `init(log:)` and providing an `OSLog` with the given subsystem and category.
    ///
    /// - Parameters:
    ///    - subsystem: The subsystem to log events to. This is generally structured as a reverse-DNS name, like `com.myapp.App`. If you're unsure
    ///      what it should be, use your app's bundle identifier.
    ///    - category: The category to log events to. This is an arbitrary label within your subsystem, and can be used with configuration profiles to
    ///      control logging policy in the unified logging system. If you're unsure what it should be, use `"events"`.
    ///
    public convenience init(subsystem: String, category: String) {
        self.init(log: OSLog(subsystem: subsystem, category: category))
    }
    
    public func send(event: Event, level: OSLogType) {
        do {
            let text = try encoder.encode(event)
            os_log("%{public}s", log: log, type: level, text)
        } catch {
            NSLog("Could not serialize event: \(error)")
        }
    }
}
