# Ed25519 Signature Authentication

A signature can be configure to provide an additional layer of assurance when mobile devices are connecting over a tunnel to a goose desktop app. This can be used in MDM scenarios where you want to lock down org wide access.

## Overview

- **iOS app**: Signs all requests with Ed25519 private key
- **Server**: Validates signatures with Ed25519 public key (when configured)
- **Backward compatible**: Works with or without keys configured

## iOS Configuration

## Creating key and testing it

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

# Verify it was set
xcrun simctl spawn booted defaults read com.goose.chat goose_ed25519_private_key

# To remove the key from simulator
xcrun simctl spawn booted defaults delete com.goose.chat goose_ed25519_private_key


# Configure server with public key 
export GOOSE_TUNNEL_PUBLIC_KEY_AUTH="$PUBLIC_KEY"
```


### For Production (MDM)

**How it works:** The iOS app reads the private key from **managed UserDefaults** via an MDM Configuration Profile. When the MDM system pushes the profile to a device, iOS automatically makes the key available to the app - no user interaction required.

**Key reading priority (see `ConfigurationHandler.swift`):**
1. **MDM-managed**: `ed25519_private_key` (production - deployed via MDM)
2. **Fallback**: `goose_ed25519_private_key` (simulator testing only)

#### MDM Deployment Steps

1. **Create** a `.mobileconfig` Configuration Profile
2. **Upload** to your MDM system (Jamf, Intune, Workspace ONE, etc.)
3. **Push** to target iOS devices
4. **Done** - the app automatically reads the key and signs requests

#### Configuration Profile Template

Create a `.mobileconfig` file with this structure:

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

#### Critical Configuration Values

| Field | Value | Notes |
|-------|-------|-------|
| **Bundle ID** | `com.goose.chat` | Must match the app's bundle identifier |
| **Preference Key** | `ed25519_private_key` | Exact key name (no prefix) |
| **Key Format** | 64-character hex string | 32 bytes represented as hex |
| **PayloadType** | `com.apple.ManagedClient.preferences` | Required for managed preferences |
| **UUIDs** | Generate with `uuidgen` | Two unique UUIDs needed |

#### What Happens on the Device

```
MDM System → iOS Device → Managed UserDefaults → Goose App
                          (com.goose.chat domain)   (reads automatically)
```

When the profile is installed:
1. iOS stores the key in the app's **managed** UserDefaults domain
2. The Goose app reads it from `UserDefaults.standard.string(forKey: "ed25519_private_key")`
3. On every API request, the app signs: `METHOD|PATH|TIMESTAMP|BODY_HASH`
4. Signature sent in `X-Corp-Signature` header
5. Server validates with the corresponding public key

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
