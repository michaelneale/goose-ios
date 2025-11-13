# Ed25519 Signature Authentication

This document describes the Ed25519 signature-based authentication system for securing communication between the iOS app and goose server through the tunnel.

## Overview

- **iOS app**: Signs all requests with Ed25519 private key
- **Server**: Validates signatures with Ed25519 public key (when configured)
- **Backward compatible**: Works with or without keys configured

## Key Generation

Generate an Ed25519 keypair using OpenSSL:

```bash
# Generate private key
openssl genpkey -algorithm ed25519 -out ed25519_private.pem

# Extract private key as hex (32 bytes = 64 hex characters)
openssl pkey -in ed25519_private.pem -text -noout | grep "priv:" -A 3 | tail -n 3 | tr -d ' :\n'

# Extract public key as hex (32 bytes = 64 hex characters)  
openssl pkey -in ed25519_private.pem -pubout -text -noout | grep "pub:" -A 3 | tail -n 3 | tr -d ' :\n'
```

**Important**: Save both hex strings (private and public keys). The private key goes to iOS, the public key goes to the server.

## iOS Configuration

### For Simulator Testing

Set the private key in the simulator's UserDefaults:

```bash
# Boot simulator (if not running)
xcrun simctl boot "iPhone 16 Pro"

# Set the Ed25519 private key (replace YOUR_PRIVATE_KEY_HEX with actual hex string)
xcrun simctl spawn booted defaults write com.goose.chat goose_ed25519_private_key "YOUR_PRIVATE_KEY_HEX"

# Verify it was set
xcrun simctl spawn booted defaults read com.goose.chat goose_ed25519_private_key

# To remove the key from simulator
xcrun simctl spawn booted defaults delete com.goose.chat goose_ed25519_private_key
```

### For Production (MDM)

Deploy via MDM Configuration Profile. Create a `.mobileconfig` file:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>PayloadContent</key>
    <array>
        <dict>
            <key>PayloadType</key>
            <string>com.apple.ManagedClient.preferences</string>
            <key>PayloadVersion</key>
            <integer>1</integer>
            <key>PayloadIdentifier</key>
            <string>com.yourcompany.goose.prefs</string>
            <key>PayloadUUID</key>
            <string>GENERATE-A-UUID-HERE</string>
            <key>PayloadDisplayName</key>
            <string>Goose Configuration</string>
            <key>PayloadDescription</key>
            <string>Ed25519 authentication for Goose app</string>
            <key>PayloadOrganization</key>
            <string>Your Company</string>
            
            <key>PayloadContent</key>
            <dict>
                <key>com.goose.chat</key>
                <dict>
                    <key>Forced</key>
                    <array>
                        <dict>
                            <key>mcx_preference_settings</key>
                            <dict>
                                <key>ed25519_private_key</key>
                                <string>YOUR_PRIVATE_KEY_HEX_HERE</string>
                            </dict>
                        </dict>
                    </array>
                </dict>
            </dict>
        </dict>
    </array>
    <key>PayloadDisplayName</key>
    <string>Goose Ed25519 Authentication</string>
    <key>PayloadIdentifier</key>
    <string>com.yourcompany.goose</string>
    <key>PayloadRemovalDisallowed</key>
    <false/>
    <key>PayloadType</key>
    <string>Configuration</string>
    <key>PayloadUUID</key>
    <string>GENERATE-ANOTHER-UUID-HERE</string>
    <key>PayloadVersion</key>
    <integer>1</integer>
</dict>
</plist>
```

**Key points:**
- The bundle ID is `com.goose.chat` (must match your app)
- The preference key is `ed25519_private_key` (no prefix needed)
- Replace `YOUR_PRIVATE_KEY_HEX_HERE` with your actual hex private key
- Generate UUIDs with `uuidgen` command
- Deploy through your MDM system (Jamf, Intune, etc.)

The app checks MDM-managed preferences first, then falls back to UserDefaults for simulator testing.

### Testing MDM on Physical Device

To test the MDM configuration profile on a personal device without a full MDM system:

1. **Save the `.mobileconfig` file** with your test private key
2. **Email it to yourself** or host it on a web server
3. **Open the file** on your iOS device (tap the email attachment or visit the URL in Safari)
4. **Install the profile**: Settings → General → VPN & Device Management → Install
5. **Verify it's installed**: Settings → General → VPN & Device Management → Configuration Profiles

**To verify the key was set:**
```swift
// Add temporary debug code to ConfigurationHandler.swift
print("🔍 MDM Key check: \(UserDefaults.standard.string(forKey: "ed25519_private_key") ?? "not found")")
```

**To remove the profile:**
Settings → General → VPN & Device Management → Select profile → Remove Profile

⚠️ **Note**: For production, deploy via your MDM system (Jamf, Intune, Workspace ONE, etc.). This manual method is for testing only.

## Server Configuration (Rust)

Set the public key as an environment variable:

```bash
# Set the Ed25519 public key (replace YOUR_PUBLIC_KEY_HEX with actual hex string)
export GOOSE_TUNNEL_PUBLIC_KEY_AUTH="YOUR_PUBLIC_KEY_HEX"
```

When this environment variable is set, the server will:
- Require `X-Corp-Signature` header on all tunnel requests
- Validate signatures using the public key
- Reject requests with missing or invalid signatures

When the environment variable is **not** set:
- Server does not require signatures
- Works exactly as before (backward compatible)

## How It Works

### Request Signing (iOS)

For each request, the iOS app:
1. Creates a message: `METHOD|PATH|TIMESTAMP|BODY_HASH`
   - METHOD: HTTP method (GET, POST, etc.)
   - PATH: Request path (e.g., `/sessions`)
   - TIMESTAMP: Unix timestamp in seconds
   - BODY_HASH: SHA-256 hex of request body (or empty string if no body)

2. Signs the message with Ed25519 private key

3. Adds header: `X-Corp-Signature: <timestamp>.<signature_hex>`

### Signature Validation (Server)

The server:
1. Extracts timestamp and signature from `X-Corp-Signature` header
2. Reconstructs the message using request data
3. Verifies the signature using the Ed25519 public key
4. Accepts request if signature is valid, rejects with 401 if invalid

## Example

Generate and configure a keypair:

```bash
# Generate keys
openssl genpkey -algorithm ed25519 -out ed25519_private.pem
PRIVATE_KEY=$(openssl pkey -in ed25519_private.pem -text -noout | grep "priv:" -A 3 | tail -n 3 | tr -d ' :\n')
PUBLIC_KEY=$(openssl pkey -in ed25519_private.pem -pubout -text -noout | grep "pub:" -A 3 | tail -n 3 | tr -d ' :\n')

echo "Private key (for iOS): $PRIVATE_KEY"
echo "Public key (for server): $PUBLIC_KEY"

# Configure iOS simulator
xcrun simctl spawn booted defaults write com.goose.chat goose_ed25519_private_key "$PRIVATE_KEY"

# Configure server
export GOOSE_TUNNEL_PUBLIC_KEY_AUTH="$PUBLIC_KEY"
```

## Security Notes

- Private keys must be kept secure and never transmitted
- Public keys can be safely distributed
- Each deployment should use unique keypairs
- Keys can be rotated by generating new pairs and updating configurations
- The system provides replay protection via timestamp validation
- All tunnel traffic is already encrypted via HTTPS/WSS

## Troubleshooting

### iOS app not signing requests

Check the Xcode console for:
- `✓ Ed25519 signer initialized successfully` - Signing is enabled
- `⚠️ No Ed25519 private key found` - No key configured (signatures won't be added)
- `❌ Ed25519 signer failed to initialize` - Invalid key format

### Server rejecting signatures

Check the server logs for:
- `✓ Signature valid for METHOD /path` - Signature validated successfully  
- `✗ Authentication error: Missing X-Corp-Signature header` - iOS not sending signature
- `✗ Authentication error: Invalid signature` - Signature verification failed

### Testing without signatures

Simply don't set the keys:
- iOS: Don't set `goose_ed25519_private_key` - app won't sign requests
- Server: Don't set `GOOSE_TUNNEL_PUBLIC_KEY_AUTH` - server won't require signatures

The system will work exactly as before.
