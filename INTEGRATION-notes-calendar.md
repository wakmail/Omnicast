# Notes and Calendar integration

## AppDelegate storage

Add these retained properties to AppDelegate.

```swift
private var notesStore: NotesStore?
private var calendarService: CalendarService?
```

Create both services with the other stores during startup, then retain them.

```swift
let notesStore = try NotesStore(directoryURL: OmnicastDataDirectory.defaultURL)
let calendarService = CalendarService()
self.notesStore = notesStore
self.calendarService = calendarService
```

## Command registry

Add both providers to the provider array.

```swift
NotesCommandsProvider(store: notesStore),
CalendarCommandsProvider(),
```

## Launcher presenters

Build the existing presenter dictionary before creating LauncherView, then merge both feature dictionaries.

```swift
var presentingCommands = makePresentingCommands(context: context)
presentingCommands.merge(NotesLauncherPresentation.presenters(store: notesStore)) {
    _, feature in feature
}
presentingCommands.merge(CalendarLauncherPresentation.presenters(service: calendarService)) {
    _, feature in feature
}
```

Pass `presentingCommands` into LauncherView.

## Calendar privacy description

The packaged app metadata must include this value before Calendar access is requested.

```xml
<key>NSCalendarsFullAccessUsageDescription</key>
<string>Omnicast uses your calendars to show your schedule.</string>
```

The notes provider emits Search Notes plus one command for every note loaded at startup. Refreshing the registry when `notesStore.$notes` changes will refresh command search results. The checked out launcher stores its presenter dictionary once, so note commands created later need the shared launcher routing update before they can open directly without restarting. Search Notes and every note present at startup work with the code above.

Calendar access is not requested by CalendarService initialization. ScheduleView asks through `requestAccess()` when My Schedule is opened, then listens for EventKit changes.
