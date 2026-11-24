# Security model — VirusTotal for macOS

Threat model for security scans of this fork (upstream: `Jerry23011/VirusTotal-macOS`). Drafted from the code on 2026-11-15; edit it as the app changes.

## System overview

A sandboxed SwiftUI client for the VirusTotal API. It hashes or uploads files and submits URLs the user picks, shows the analysis, and updates itself with Sparkle. There is no server of its own.

## Components

| Component | Code |
|---|---|
| **VirusTotal-macOS** | `VirusTotal/**`, `appcast.xml` |

## Entry points

- Files and URLs from the user, drag and drop, and the macOS Services menu (`VirusTotal/SystemService/ServiceProvider.swift`).
- VirusTotal API responses (`VirusTotal/Models/FileAnalysis.swift`, `URLAnalysis.swift`, `QuotaStatus.swift`).
- Sparkle update feed: `SUFeedURL` in `VirusTotal/Info.plist` points at the upstream `raw.githubusercontent.com/Jerry23011/VirusTotal-macOS/main/appcast.xml`, and updates are EdDSA-signed (`SUPublicEDKey`).

## Assets

- The user's VirusTotal API key, stored in `UserDefaults` (`VirusTotal/Configurations/Defaults.swift`) and sent as `x-apikey`.
- The privacy of files and URLs the user submits (uploads to VirusTotal are public to its community).
- The integrity of installed updates.

## Attacker profiles

1. Malicious files or URLs the user chooses to scan.
2. A malicious or compromised network path or API response.
3. Supply chain: a compromised update feed or signing key, or Swift package dependencies.
4. Other software on the same Mac reading app preferences.

## Existing controls

- App Sandbox (`VirusTotal/VirusTotal.entitlements`).
- Sparkle EdDSA update signatures.
- Tracking-parameter removal for submitted URLs.

## Open questions

- Whether code inherited from upstream is in scope or tracked upstream.
- Whether the update feed should point at this fork's releases instead of upstream.
