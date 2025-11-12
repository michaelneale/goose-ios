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
```

### For Production (MDM)

Deploy via MDM with the key:
```
com.block.goose.ed25519_private_key
```

The app checks MDM first, then falls back to UserDefaults for testing.

## Server Configuration (Rust)

Set the public key as an environment variable:

```bash
# Set the Ed25519 public key (replace YOUR_PUBLIC_KEY_HEX with actual hex string)
export GOOSE_TUNNEL_ED25519_PUBLIC_KEY="YOUR_PUBLIC_KEY_HEX"
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
export GOOSE_TUNNEL_ED25519_PUBLIC_KEY="$PUBLIC_KEY"
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
- Server: Don't set `GOOSE_TUNNEL_ED25519_PUBLIC_KEY` - server won't require signatures

The system will work exactly as before.
