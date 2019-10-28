import Foundation

private let eventAccessQueue = DispatchQueue(label: "com.mattmoriarity.Events.EventAccessQueue")

extension Event {
    private static var _global = EventBuilder()

    /// An event builder for fields that will be added to all future events.
    ///
    /// The global event builder is not meant to be sent. Instead, any fields you include here will be automatically included when sending future
    /// events.
    public static var global: EventBuilder {
        get {
            eventAccessQueue.sync { _global }
        }
        set {
            eventAccessQueue.sync(flags: .barrier) {
                _global = newValue
            }
        }
    }

    private static var _current = EventBuilder()

    /// The event that is currently in progress.
    ///
    /// In most cases, this is the event that your app should be adding fields to. This allows uncoupled parts of your app to add relevant information
    /// to the current event without knowing who started it or when it will be sent.
    ///
    /// The current event is the same throughout the entire app, so if you are performing background or concurrent tasks, you may want to avoid the
    /// current event for those and explicitly create and pass around an `EventBuilder`.
    ///
    /// `EventBuilder` is a value type, so all changes to the current event should be made directly on this property, rather than trying to store the
    /// current event somewhere else.
    ///
    /// ```
    /// // good
    /// Event.current[.myField] = "foo"
    ///
    /// // bad
    /// var event = Event.current
    /// event[.myField] = "foo"
    /// ```
    public static var current: EventBuilder {
        get {
            eventAccessQueue.sync { _current }
        }
        set {
            eventAccessQueue.sync(flags: .barrier) {
                _current = newValue
            }
        }
    }
}
