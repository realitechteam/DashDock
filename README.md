# DashDock

**Real-time Google Analytics, AdSense & Search Console monitoring — right on your Mac Desktop.**

DashDock is a lightweight macOS menu bar app with WidgetKit desktop widgets that lets you monitor your website metrics at a glance. No browser needed.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue) ![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange) ![License MIT](https://img.shields.io/badge/License-MIT-green)

## Features

- **Menu Bar App** — Quick stats popover with real-time active users, pageviews, sessions, top pages
- **Desktop Widgets** — WidgetKit widgets for your Desktop and Notification Center
- **Google Analytics 4** — Real-time active users, pageviews, sessions, new users, top pages
- **Google AdSense** — Revenue, clicks, impressions, RPM *(coming soon)*
- **Google Search Console** — Clicks, impressions, CTR, average position *(coming soon)*
- **Auto-Update** — Built-in Sparkle auto-updater for seamless updates
- **Zero Dependencies** — All native Apple frameworks (SwiftUI, WidgetKit, Swift Charts)
- **Privacy First** — All data stays on your Mac, no third-party analytics

## Screenshots

*Coming soon*

## Requirements

- macOS 14.0+ (Sonoma)
- Xcode 15+
- Google account with Analytics access

## Getting Started

### 1. Google Cloud Setup

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create a new project (or use existing)
3. Enable these APIs:
   - **Google Analytics Data API**
   - **Google Analytics Admin API**
   - **AdSense Management API** *(optional, for Phase 2)*
   - **Search Console API** *(optional, for Phase 3)*
4. Go to **Google Auth Platform** > **Clients** > **Create Client**
5. Choose **Desktop app**, name it "DashDock"
6. Copy the **Client ID** and **Client Secret**
7. Go to **Audience** > **Test users** > add your Google email

### 2. Build & Run

```bash
# Clone the repo
git clone https://github.com/AidenVN/DashDock.git
cd DashDock

# Copy config and add your credentials
cp Config.xcconfig.example Config.xcconfig
# Edit Config.xcconfig with your GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET

# Generate Xcode project (requires xcodegen)
brew install xcodegen
xcodegen generate

# Open in Xcode
open DashDock.xcodeproj

# Or build from CLI
xcodebuild -project DashDock.xcodeproj -scheme DashDock -configuration Release build \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  CONFIGURATION_BUILD_DIR=./build
```

### 3. Install

Copy `build/DashDock.app` to `/Applications/` and launch it.

## Architecture

```
Google APIs (GA4, AdSense, Search Console)
         | HTTPS
         v
+-------------------------------------+
|        DashDock Main App            |
|  OAuth 2.0 + PKCE -> Keychain      |
|  DataSyncManager -> Polling         |
|  SharedDataStore (UserDefaults)     |
|  MenuBar Popover UI                |
+----------------+--------------------+
                 v
+-------------------------------------+
|     DashDock Widget Extension       |
|  TimelineProvider reads cache       |
|  SwiftUI + Swift Charts views      |
+-------------------------------------+
```

- **No third-party dependencies** except Sparkle (auto-update)
- OAuth 2.0 + PKCE via local HTTP server (no ASWebAuthenticationSession sandbox issues)
- Widgets read from shared cache — no direct API calls from widget extension
- `@Observable` macro (macOS 14+)

## Project Structure

```
DashDock/
├── DashDock/                    # Main app target
│   ├── App/                     # App entry, state, update manager
│   ├── Auth/                    # OAuth 2.0 + PKCE, Keychain, tokens
│   ├── API/                     # GA4, AdSense, Search Console clients
│   ├── Data/                    # Sync manager, cache, shared store
│   ├── Views/                   # Menu bar, settings, dashboard, components
│   └── Extensions/              # Number formatting, date, colors
├── DashDockWidgets/             # WidgetKit extension
│   ├── Widgets/                 # Widget definitions
│   ├── TimelineProviders/       # Data providers for widgets
│   └── WidgetViews/             # Widget SwiftUI views
├── DashDockShared/              # Shared code (both targets)
├── scripts/                     # Release & signing scripts
├── project.yml                  # XcodeGen spec
└── appcast.xml                  # Sparkle update feed
```

## Releasing Updates

DashDock uses [Sparkle](https://sparkle-project.org/) for auto-updates.

```bash
# One-time: generate EdDSA signing keys
./scripts/release.sh generate-keys

# Build a release
./scripts/release.sh build 1.1.0

# Upload DMG + appcast.xml to your server
```

See `scripts/release.sh` for details.

## Roadmap

- [x] Google Analytics 4 — real-time monitoring
- [x] Property picker (auto-detect GA4 properties)
- [x] Desktop widgets (WidgetKit)
- [x] Sparkle auto-update
- [ ] Google AdSense integration
- [ ] Google Search Console integration
- [ ] Multi-account support
- [ ] Widget configuration via App Intents
- [ ] Launch at Login
- [ ] App Store release

## Contributing

Contributions are welcome! Feel free to:

1. Fork the repo
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

MIT License — see [LICENSE](LICENSE) for details.

## Credits

Built by **[Realitech Team](https://realitech.dev)**

- Web: [realitech.dev](https://realitech.dev)
- Email: [partner@realitech.dev](mailto:partner@realitech.dev)
- Phone: +84 345 678 462

---

*DashDock is not affiliated with Google. Google Analytics, AdSense, and Search Console are trademarks of Google LLC.*
