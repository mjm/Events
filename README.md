# Events

Events is a package for logging high-cardinality events in your Mac or iOS app.

## Installation

Events can be installed using SwiftPM. If you're using it from another Swift package, add this snippet to the `dependencies` in your `Package.swift`:

```swift
.package(url: "https://github.com/mjm/Events", .branch("master"))
```

You can also use Events from your macOS or iOS app using Xcode 11's SwiftPM support.

1. Click on your project in Xcode's Project navigator.
2. Select the project in the sidebar of the editor.
3. Hit the + button on the Swift Packages tab.
4. Enter `https://github.com/mjm/Events` for the package repository URL.
5. Choose "Branch" and use "master" as the branch.
6. Be sure the Events library is added to the target for your app.
7. Choose "Finish."