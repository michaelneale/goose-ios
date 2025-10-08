# Goose for mobile

A native iOS client for the Goose AI Assistant that communicates with the goosed server.

To use it:

# Run the goose app in emulator

run `./launch_goosed.sh` - it will show you url and secret to use (needs goosed binary from goose on your $PATH)
use that in the simulator app

# Running from test flight on real phone

* install goose from testflight
* run `./launch_tailscale.sh` to launch goosed with a tunnel
* log in to tailscale if it pops up
* install and enable tailscale on your phone
* point your phone at the QR code to configure it
