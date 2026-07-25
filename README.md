# StarlinkInfos

**macOS + iOS/iPadOS** SwiftUI app to monitor and manage a Starlink internet
connection — talking directly to the dish's local gRPC API — with Starlink news and
upcoming launches on the side.

## Features

| Feature | macOS | iOS/iPadOS |
|---|:---:|:---:|
| Real-time dish dashboard (status, uptime, latency, throughput, GPS, alerts) | ✅ | ✅ |
| Latency & throughput charts (last 15 min, live) | ✅ | ✅ |
| Obstruction map (sky-view SNR grid) | ✅ | ✅ |
| Dish controls: reboot, stow/unstow (with confirmation) | ✅ | ✅ |
| Graceful "dish unreachable" state when off the Starlink LAN | ✅ | ✅ |
| Starlink news (Google News RSS, follows app language) | ✅ | ✅ |
| Upcoming Starlink launches (Launch Library 2) | ✅ | ✅ |
| Settings: appearance (system/light/dark), language (system/fr/en) | ✅ | ✅ |

The dish API (`192.168.100.1:9200`, gRPC) is local and unauthenticated — no account
or API key needed, but the dashboard only works from the Starlink network.

## Build

Requirements: Xcode 16+, [XcodeGen](https://github.com/yonaskolb/XcodeGen)
(`brew install xcodegen`). Targets macOS 15+ / iOS 18+ (grpc-swift-2 requirement).

```bash
xcodegen generate            # generates StarlinkInfos.xcodeproj
open StarlinkInfos.xcodeproj # macOS: scheme StarlinkInfos — iOS: scheme StarlinkInfosiOS
```

To regenerate the gRPC client after a dish firmware update, see `ARCHITECTURE.md`
(section "The dish gRPC API").

## Release (macOS)

```bash
./Scripts/release.sh 1.0.0   # build → sign → DMG → notarize → staple
```

## Project layout

```
StarlinkInfos/
├── StarlinkInfosApp.swift       # @main
├── Models/                      # DishModels (status/history/map), FeedModels (news/launches)
├── ViewModels/                  # DishViewModel (2 s polling), FeedViewModel
├── Views/
│   ├── ContentView.swift        # NavigationSplitView, sidebar with 3 sections
│   └── Dashboard/               # dashboard, charts, obstruction map, controls
├── Services/                    # DishClient (gRPC actor), NewsService, LaunchService
├── Generated/                   # protoc output from Proto/dish.protoset — do not edit
└── Localization/                # AppSettings + fr/en string table
Proto/dish.protoset              # dish API descriptor set (dumped via gRPC reflection)
Scripts/                         # release.sh, make-app-icon.swift, make-dmg-background.swift
project.yml                      # XcodeGen config (targets + SPM packages)
```

## Install

Download the latest notarized DMG from the
[Releases page](https://github.com/vincentlauriat/StarlinkInfos/releases). The app
auto-updates via Sparkle (Help menu → "Check for Updates…").

## Roadmap

- [x] Real-time dish dashboard over local gRPC
- [x] News + launches panes
- [x] Final app icon
- [x] Notarized DMG release + Sparkle auto-update
- [ ] iOS signing & device testing

## License

MIT — see [`LICENSE`](LICENSE).
