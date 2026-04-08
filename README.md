# CirightPro iOS SDK (QuickAuthIOSSDK)

Swift Package that wraps CirightPro QuickAuth (carrier/network verification) behind a simple API.

## Install (Swift Package Manager)

Add the package to your app (Xcode → **File → Add Packages…**) and use the repo you already have configured for this SDK.

## Usage

### 1) Configure

Provide your:
- `clientId` (CirightPro client id for the native verification runtime)
- `redirectUri` (must match your deep link / universal link callback)
- environment (`production` or `sandbox`)

### 2) Check coverage (optional but recommended)

Call the coverage check to avoid starting auth flows that are not supported for a given SIM/operator.

### 3) Start authentication

Start the verification flow and exchange the resulting code with your backend to obtain your JWT/session.

## Backend requirement

Your backend must:
- exchange the authorization code with the underlying provider
- issue your own JWT/session for the app
- enforce tenant headers (like `x-qa-client-id`) as needed

## Notes

- This SDK uses `@_implementationOnly import IPificationSDK` to reduce exposure of the provider module in the public interface.
- Universal Links / callback configuration must match `redirectUri`.

