# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

DashDock is a macOS menu bar app with WidgetKit desktop widgets for monitoring Google Analytics 4, Google AdSense, and Google Search Console in real-time. It's distributed outside the App Store via Sparkle auto-updater.

## Build & Run

```bash
# Prerequisites: Xcode 15+, xcodegen
brew install xcodegen

# First-time setup
cp Config.xcconfig.example Config.xcconfig
# Edit Config.xcconfig with GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET

# Generate Xcode project from project.yml
xcodegen generate

# Build from CLI (unsigned for local dev)
xcodebuild -project DashDock.xcodeproj -scheme DashDock -configuration Debug build \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

# Or open in Xcode
open DashDock.xcodeproj
```

There are no test targets currently. The project has no linter configured.

## Architecture

### Targets

- **DashDock** — main menu bar app (`DashDock/` + `DashDockShared/`)
- **DashDockWidgets** — WidgetKit extension (`DashDockWidgets/` + `DashDockShared/`)

Both targets share code via `DashDockShared/` (not a framework — sources are compiled into each target directly).

### Data Flow

```
Google APIs (GA4 Data/Admin, AdSense Management)
    ↓ URLSession + Bearer token
APIClient (generic GET/POST, error parsing, token injection)
    ↓
GA4Client / AdSenseClient (per-API rate limiter: 10 req/min)
    ↓
DataSyncManager (polling: GA4 realtime 30s, reports 5m, AdSense 5m)
    ↓ writes to
SharedDataStore (UserDefaults JSON cache, fixed keys)
    ↓ reads from
Widget TimelineProvider (15-min refresh) + MenuBarPopover UI
```

### Auth Flow

OAuth 2.0 + PKCE via `GoogleAuthManager`:
1. Starts local `NWListener` on a random port
2. Opens system browser to Google consent
3. Receives callback on local HTTP server
4. Exchanges code for tokens → saves to Keychain (per account ID)
5. Fetches user info → creates `GoogleAccount`

Tokens are persisted in Keychain, scoped by account ID. Session restore on launch reads `SharedDataStore.currentAccount` then checks for a matching Keychain entry.

### State Management

All `@Observable` (macOS 14+), no Combine:
- `GoogleAuthManager` — auth state, current account
- `DataSyncManager` — polling, cached data in memory
- `AppState` — tab selection, setup flow flag
- `SubscriptionManager` — freemium tier (StoreKit 2 not yet integrated)

### Multi-Account Model

- `GoogleAccount` stores per-account config: `ga4PropertyID`, `adSenseAccountID`, etc.
- Accounts list persisted in `SharedDataStore.accounts` (UserDefaults)
- Current account in `SharedDataStore.currentAccount`
- Tokens scoped by account ID in Keychain
- **Cache is NOT scoped per account** — `SharedDataStore` uses fixed keys (`ga4_realtime`, `ga4_summary`, etc.), so switching accounts shows stale data until next poll

### Widget Architecture

Widgets only read from `SharedDataStore` (no API calls). The main app calls `WidgetCenter.shared.reloadAllTimelines()` after each sync. Widget data reflects whichever account was last synced.

## Key Conventions

- **No third-party deps** except Sparkle 2.6.4 (auto-update)
- Build config (client ID/secret, Sparkle key) via `Config.xcconfig` → Info.plist
- `LSUIElement = true` — menu bar only, no Dock icon
- App sandbox disabled (required for local OAuth HTTP server)
- Project generated from `project.yml` via XcodeGen — edit `project.yml` not the `.xcodeproj` directly
- Number formatting utilities in `DashDockShared/NumberFormatting.swift`: `.formattedCompact()`, `.formattedCurrency()`, `.formattedPercent()`

## Release Process

```bash
# Generate EdDSA keys (one-time)
./scripts/release.sh generate-keys

# Build release DMG
./scripts/release.sh build <version>
```

Uses Sparkle with EdDSA signing. Feed at `appcast.xml`.

## Development Status

Completed: GA4 MVP, comparative analytics (sparklines/trends), AdSense integration.
Planned: notifications/alerts, Search Console, Claude AI insights, multi-account improvements, App Store.
