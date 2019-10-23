## What is an event?

Events are different than typical application logging.
Logging usually means emitting a message whenever your app does something interesting.
Any complex logic will need to log several messages to indicate progress and include more useful data about different parts of the process.
These log messages are easy to write, but when you need to debug a problem in the logic, the information you need to understand what happens is scattered.
You'll need to relate many independent log messages to get the complete picture of what happened.

Events solve this problem by collecting all of the information about a particular action into one place.
At the end of the day, an event is basically just a dictionary: a collection of key-value pairs.
Instead of logging different messages throughout our code, we can keep adding information to an event.
When the action is complete, we can send a single message with all the information we've accumulated.
Later, when we're diagnosing a problem, we will only need to look in one place to have everything we need to understand what happened.

This may not sound like a big difference, but embracing an event model for logging can be incredibly powerful. This is especially true if you can get these events into a queryable data store.

The good folks at [Honeycomb][] deserve a lot of credit for promoting this model for understanding systems. They've [written a great deal][events] about events vs. logs, including a great post about [the difference between structured logs and events][logs-vs-events].

[honeycomb]: https://www.honeycomb.io/
[events]: https://www.honeycomb.io/events-blog/
[logs-vs-events]: https://www.honeycomb.io/blog/how-are-structured-logs-different-from-events/

## Creating an event

The Events package provides an `EventBuilder` type that you can use to construct your events, add data to them, and then send them to their destination.

You won't usually need to create an `EventBuilder`. Events provides a shared one at `Event.current` that you can use from many different parts of your application. This event builder is global to the entire application. This works because most of the time, an app isn't doing multiple high-level units of work at a time.

Sometimes you'll want to emit an event for background work that could happen concurrently with the "current" event. In these situations, you can create an `EventBuilder` locally. You'll need to pass the event explicitly to other functions that need to add data to it, whereas `Event.current` is globally available, but otherwise it works the same.

## Adding information to an event

To add data to an event, start by defining the keys that you'll be storing on your events:

```swift
extension Event.Key {
    static let listName: Event.Key = "list_name"
    static let itemCount: Event.Key = "item_count"
}
```

These keys are simple wrappers for strings, but explicitly defining them as constants helps you use them consistently in different parts of your app.

With your keys defined, you can use them in your code to add data to the current event (or another event builder):

```swift
func fetchList(name: String) -> List {
    Event.current[.listName] = name

    let list = List.findByName(name)
    Event.current[.itemCount] = list.items.count

    return list
}
```

The values you set in the event can be any type that is `Encodable`.

### Using timers to track durations

For events that are made up of multiple steps, it can be useful to track the duration of each step as a field on the event. `EventBuilder.startTimer(_:)` and `EventBuilder.stopTimer(_:)` make this easy to do without filling your code with date math.

```swift
extension Event.Key {
    static let fetchUserTime: Event.Key = "fetch_user_ms"
    static let fetchListsTime: Event.Key = "fetch_lists_ms"
}

func fetchUserAndLists(completion: ((User?, [List]?, Error?) -> Void)) {
    Event.current.startTimer(.fetchUserTime)
    Request.get("/user") { user, error in
        Event.current.stopTimer(.fetchUserTime)

        if let error = error {
            completion(nil, nil, error)
        } else {
            Event.current.startTimer(.fetchListsTime)
            Request.get("/users/\(user.id)/lists") { lists, error in
                Event.current.stopTimer(.fetchListsTime)

                completion(user, lists, error)
            }
        }
    }
}
```

You pass an event key to both `startTimer` and `stopTimer`. When you call `stopTimer`, the key you provide will be set to the time since the call to `startTimer`, in milliseconds.

### Handling errors

It's such a common need to save information about errors that occur in your app that there's a built-in `error` property for it on `ErrorBuilder`s.

```swift
func fetchUser(completion: ((User?, Error?) -> Void)) {
    Request.get("/user") { user, error in
        Event.current.error = error
        completion(user, error)
    }
}
```

Using this property serves two purposes:

* It ensures a consistent key (`"err"`) for the errors your app includes in its events.
* `Error` is not `Encodable`, so you can't set one directly as a field on an event. When you set the `error` property, the `localizedDescription` string from the error gets included on the `"err"` key of the event.

If you have an event that can produce multiple errors (it doesn't stop after the first error encountered), it's completely valid to define more specific error keys and store the `localizedDescription` yourself.

```swift
extension Event.Key {
    static let thingError: Error.Key = "thing_err"
    static let otherThingError: Error.Key = "other_thing_err"
}

func act() {
    do {
        try doThing()
    } catch {
        Event.current[.thingError] = error.localizedDescription
    }

    do {
        try doOtherThing()
    } catch {
        Event.current[.otherThingError] = error.localizedDescription
    }
}
```

Doing this means you don't have to choose which error to keep in the case that both things fail.



## Sending events

When your app completes the work that makes up an event, you need to send it. Sending an event means you're done adding information to it, and it's ready to be sent to its destination. You send an event by calling `EventBuilder.send(_:)`.

```swift
@IBAction func deleteItem() {
    // Item.delete(_:) adds data to the current event
    selectedItem.delete { error in
        if let error = error {
            self.presentError(error)
        }

        Event.current.send("deleted item")
    }
}
```

When you send an event, you pass a message string that describes the event, and that gets included as the `"msg"` field of the event. This is kind of like a log message, but there's an important limitation: it cannot include any dynamic data. `EventBuilder.send(_:)` takes a `StaticString` for the message, so trying to use interpolation or other ways of building a string with dynamic content will fail to compile. This shouldn't be an issue, though: dynamic data for your events should be in the fields. The message of a particular event should always be the same (this also makes it easier to correlate similar events).

Sending an event causes the event builder to freeze its contents into an `Event` structure. The `Event` is sent to an `EventSink` which is responsible for logging the event to a particular destination. See [Destinations][] for more about event sinks.

[destinations]: Destinations.html

Finally, once you send an event, the event builder you used is reset so that all of its fields are cleared out. This means that if you were using `Event.current`, it's already ready to go the next time you start doing work that needs to be recorded in an event.