_Where do events go when they ~~die~~ are sent?_

Your events aren't very useful if they don't go somewhere for you to look over later.
Taking an event and sending it to its destination is the job of an `EventSink`.
Events currently provides one default event sink, but it also exposes the protocol so that you can define your own if you need to.

## Logging events to `os_log`

By default, when you send an event, it will be logged to Apple's unified logging system using `os_log`.

```swift
Event.current["list_name"] = "My Fancy List"
Event.current["item_count"] = 8

Event.current.send("fetched list")
```

When the above code is run, the following message will be logged to the Console:

```
msg="fetched list" item_count=8 list_name="My Fancy List"
```

Events are logged in the [logfmt][] format, as it's a good compromise between human- and machine-readability. After the `err` and `msg` keys, the rest of your app-specific fields are output in alphabetical order of key to keep the order deterministic and make fields easy to find.

[logfmt]: https://brandur.org/logfmt

You can customize the logging subsystem and category used to log your events by overriding `Event.sink` with your own instance of `OSLogEventSink`:

```swift
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    Event.sink = OSLogEventSink(subsystem: "com.example.MyListApp",
                                category: "events")
}
```

Doing this is highly recommended, as it makes it much easier to filter logging to just your events.

`Event.sink` controls the default event sink that is assigned to new `EventBuilder`s. If you want to override it, be sure to set it before your first use of `Event.current`.

## Creating a custom event sink

If you don't want to send your events to the unified logging system, you can create a type that implements `EventSink` and send your events anywhere you want.

An `Event` doesn't directly expose the data in its fields. Instead, events are designed to be encoded using Swift's `Encodable` protocol. This means that your event sink doesn't need to worry about how events are represented or how fields are stored. It can just let an encoder take care of serializing them and send that data where it needs to go.

Hypothetically, if we wanted to make an event sink that saved each event as JSON in a row in a SQL database, that might look something like this:

```swift
class DatabaseEventSink {
    let dbConnection: DBConnection
    let encoder = JSONEncoder()

    init(dbConnection: DBConnection) {
        self.dbConnection = dbConnection
    }

    func send(event: Event, level: OSLogType) {
        do {
            let jsonData = try encoder.encode(event)
            try dbConnection.execute(
                "INSERT INTO events (fields) VALUES (?)",
                jsonData
            )
        } catch {
            NSLog("Could not save event to database: \(error)")
        }
    }
}

// Then during app startup
let dbConnection = ... // create the database connection
Event.sink = DatabaseEventSink(dbConnection: dbConnection)
```

Now all your events would end up in your database table.

Note that event sinks do not have a way to report whether they've failed or not. Application code that is sending events shouldn't need to worry about whether events are sending successfully. Instead, events should be fired and forgotten. If an event sink's implementation can fail, then responding to that should be internal to the implementation of the sink.

Similarly, there is no way to asynchronously report completion of sending the event. Again, application code shouldn't need to worry about waiting for an event to finish sending. It's important that sending events is not disruptive to the flow of the application. So if your event sink needs to do asynchronous work, it should handle the details of that within its own implementation.