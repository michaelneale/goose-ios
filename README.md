# Goose for mobile

A native iOS client for the Goose AI Assistant that communicates with the goosed server.

To use it:

# Run the goose app in emulator

run `./launch_goosed.sh` - it will show you url and secret to use (needs goosed binary from goose on your $PATH)
use that in the simulator app

# Running from test flight on real phone

* install goose from testflight
* run `curl -fsSL https://raw.githubusercontent.com/dhanji/goose-ios/main/launch_tailscale.sh | bash` - this runs the helper script to stand up a tunnel
* log in to tailscale once pops up
* install and enable tailscale on your phone (and login with same account )
* point your phone at the QR code to configure it
