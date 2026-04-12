# DashDock

macOS menu bar app + WidgetKit desktop widgets for monitoring Google Analytics 4, Google AdSense, and Google Search Console in real-time.

## Setup

1. Create a Google Cloud project and enable: Analytics Data API, AdSense Management API, Search Console API
2. Create OAuth 2.0 Client ID (Desktop app type)
3. Copy `Config.xcconfig.example` to `Config.xcconfig` and add your Client ID
4. Open `DashDock.xcodeproj` in Xcode
5. Build and run

## Requirements

- macOS 14.0+ (Sonoma)
- Xcode 15+
- Google account with Analytics/AdSense/Search Console access
