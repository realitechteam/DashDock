# DashDock Deploy

## Cloudflare Pages (static hosting)

Hosts `appcast.xml` + DMG releases.

- Project: `dashdock-releases`
- Pages URL: https://dashdock-releases.pages.dev
- Public URL via Worker proxy: https://realitech.dev/dashdock/

```bash
# Sync deploy/ folder with latest releases + appcast, then publish
cp ../appcast.xml dashdock/appcast.xml
cp ../releases/DashDock-v*.dmg dashdock/releases/
wrangler pages deploy dashdock --project-name=dashdock-releases --branch=main --commit-dirty=true
```

## Cloudflare Worker (URL proxy)

Routes `realitech.dev/dashdock/*` → `dashdock-releases.pages.dev/dashdock/*`
so Sparkle's `SUFeedURL` (`https://realitech.dev/dashdock/appcast.xml`) keeps working.

```bash
cd worker
wrangler deploy
```
