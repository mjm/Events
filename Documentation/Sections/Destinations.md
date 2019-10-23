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

Doing this is highly recommended, as it can make it easier to filter logging to just your events.

`Event.sink` controls the default event sink that is assigned to new `EventBuilder`s. If you want to override it, be sure to set it before your first use of `Event.current`.

## Creating a custom event sink

If you don't want to send your events to the unified logging system, you can create a type that implements `EventSink` and send your events anywhere you want.

An `Event` doesn't directly expose the data in its fields. Instead, events are designed to be encoded using Swift's `Encodable` protocol.