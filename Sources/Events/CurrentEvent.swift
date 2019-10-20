import Foundation

private let eventAccessQueue = DispatchQueue(label: "com.mattmoriarity.Events.EventAccessQueue")

extension Event {
    private static var _global = EventBuilder()
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
    
    public static var sink: EventSink = OSLogEventSink()
}
