This is a swift app - which is a client to the goosed service (scripts here are just for helpers to launch it in dev time)

validating changes when needed, can do things like this (or be smarter) with iphone 17:
* xcodebuild -scheme Goose -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build 2>&1 | tail -50

You can keep working notes in notes/
prefix with TODO_...md if it is a work in progress
otherwise it is FEATURE_NOTES.md type of thing (so you know to look at them if they need to be done or not)

Never git commit or change git state without very clearly asking and getting permission.
