import Foundation
import os
import LogfmtEncoder

public protocol EventSink {
    func send(event: Event, level: OSLogType)
}

public class OSLogEventSink: EventSink {
    let log: OSLog
    let encoder: LogfmtEncoder
    
    public init(log: OSLog = .default) {
        self.log = log
        self.encoder = LogfmtEncoder()
    }
    
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
