**Note**: This project uses [bd (beads)](https://github.com/steveyegge/beads) for issue tracking. Use `bd` commands instead of markdown TODOs. See onboarding output for workflow details.

BEFORE ANYTHING ELSE: run 'bd onboard' and follow the instructions
if you don't have bd: brew tap steveyegge/beads; brew install bd

This is a swift app - which is a client to the goosed service (scripts here are just for helpers to launch it in dev time)

validating changes when needed, can do things like this (or be smarter) with iphone 17:
* xcodebuild -scheme Goose -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build 2>&1 | tail -50

Never git commit or change git state without very clearly asking and getting permission.

You should try to complete the task if you can, don't stop if you think it can be done.
