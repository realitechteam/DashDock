# DashDock

**Real-time Google Analytics, AdSense & Search Console monitoring — right on your Mac Desktop.**

DashDock is a lightweight macOS menu bar app with WidgetKit desktop widgets that lets you monitor your website metrics at a glance. No browser needed.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue) ![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange) ![License MIT](https://img.shields.io/badge/License-MIT-green)

---

## Features

### Core
- **Menu Bar App** — Quick stats popover with real-time data, no Dock icon
- **Desktop Widgets** — WidgetKit widgets for Desktop and Notification Center
- **Auto-Update** — Built-in Sparkle auto-updater
- **Zero Dependencies** — All native Apple frameworks (SwiftUI, WidgetKit, Swift Charts)
- **Privacy First** — All data stays on your Mac, no third-party analytics

### Google Analytics 4
- Real-time active users with animated number transitions
- Pageviews, sessions, new users with **trend comparison** (this week vs last week)
- **Sparkline mini charts** (7-day trends) on every metric card
- **Daily bar charts** for pageviews and sessions
- Top pages (real-time)
- Auto-detect GA4 properties or manual ID entry

### Google AdSense
- Today's estimated earnings (hero number with trend vs yesterday)
- Yesterday / 7-day / 30-day earnings breakdown
- Clicks, impressions, RPM, CPC metrics
- **7-day earnings sparkline**
- AdSense account picker in Settings

### Google Search Console
- *Coming in Sprint 4*

## Screenshots

*Coming soon*

---

## Development Progress

### Completed Sprints

| Sprint | Focus | Status |
|--------|-------|--------|
| **Phase 1** | GA4 MVP — OAuth login, menu bar popover, realtime widget, property picker | **Done** |
| **Sprint 1** | Comparative analytics — trend badges, sparkline charts, daily bar charts | **Done** |
| **Sprint 2** | AdSense integration — revenue dashboard, earnings sparkline, account picker | **Done** |

### Upcoming Sprints

| Sprint | Focus | Status |
|--------|-------|--------|
| **Sprint 3** | Notifications & alerts — traffic spike/drop detection, revenue milestones | Planned |
| **Sprint 4** | Search Console — clicks, impressions, CTR, top queries, combined widget | Planned |
| **Sprint 5** | AI insights — Claude API integration for traffic pattern analysis | Planned |
| **Sprint 6** | Distribution — Homebrew cask, landing page, CI/CD with GitHub Actions | Planned |
| **Sprint 7** | Multi-account, App Intents widget config, App Store prep | Planned |

---

## Requirements

- macOS 14.0+ (Sonoma)
- Xcode 15+
- Google account with Analytics / AdSense access

## Getting Started

### 1. Google Cloud Setup

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create a new project (or use existing)
3. Enable these APIs:
   - **Google Analytics Data API**
   - **Google Analytics Admin API**
   - **AdSense Management API**
   - **Search Console API** *(optional, for Sprint 4)*
4. Go to **Google Auth Platform** > **Clients** > **Create Client**
5. Choose **Desktop app**, name it "DashDock"
6. Copy the **Client ID** and **Client Secret**
7. Go to **Audience** > **Test users** > add your Google email

### 2. Build & Run

```bash
# Clone the repo
git clone https://github.com/realitechteam/DashDock.git
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

---

## Architecture

```
Google APIs (GA4, AdSense, Search Console)
         | HTTPS (URLSession)
         v
+-------------------------------------+
|        DashDock Main App            |
|  OAuth 2.0 + PKCE -> Keychain      |
|  DataSyncManager -> Polling         |
|    GA4: 30s | AdSense: 5m | SC: 10m|
|  SharedDataStore (App Group)       |
|  MenuBar Popover UI                |
+----------------+--------------------+
                 v
+-------------------------------------+
|     DashDock Widget Extension       |
|  TimelineProvider reads cache       |
|  SwiftUI + Swift Charts views      |
+-------------------------------------+
```

**Key design decisions:**
- **No third-party dependencies** except Sparkle (auto-update)
- OAuth 2.0 + PKCE via local HTTP server (no sandbox issues)
- Widgets read from shared cache — no direct API calls from widget extension
- `@Observable` macro (macOS 14+)
- Smart polling with rate limit tracking per API

## Project Structure

```
DashDock/
├── DashDock/                    # Main app target
│   ├── App/                     # App entry, state, update manager
│   ├── Auth/                    # OAuth 2.0 + PKCE, Keychain, tokens
│   ├── API/
│   │   ├── GA4/                 # GA4 Data API client + models
│   │   ├── AdSense/             # AdSense API client + models
│   │   └── SearchConsole/       # Search Console client (Sprint 4)
│   ├── Data/                    # Sync manager, cache, shared store
│   ├── Views/
│   │   ├── MenuBar/             # Popover, quick stats
│   │   ├── Settings/            # Accounts, properties, refresh, updates
│   │   ├── Dashboard/           # AdSense card, (future: SC dashboard)
│   │   └── Components/          # Charts, trend badges, stat cards
│   └── Extensions/              # Number formatting, date, colors
├── DashDockWidgets/             # WidgetKit extension
│   ├── Widgets/                 # Widget definitions
│   ├── TimelineProviders/       # Data providers
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

---

## Roadmap

- [x] Google Analytics 4 — real-time monitoring
- [x] Property picker (auto-detect GA4 properties)
- [x] Desktop widgets (WidgetKit)
- [x] Sparkle auto-update
- [x] Comparative analytics (trend badges, sparklines)
- [x] Google AdSense — revenue, clicks, impressions, RPM, CPC
- [ ] Notifications & alerts (traffic spikes, revenue milestones)
- [ ] Google Search Console integration
- [ ] Claude AI insights (traffic pattern analysis)
- [ ] Homebrew cask distribution
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
