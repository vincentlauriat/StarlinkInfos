# Architecture

StarlinkInfos is a **shared-codebase SwiftUI app** (macOS 15+ / iOS 18+, two targets in
`project.yml`) that monitors and manages a Starlink internet connection, with Starlink
news and upcoming launches as secondary panes. Platform differences are handled with
`#if os(...)` blocks, never file duplication.

## Overview

```
                       ┌──────────────────────────┐
                       │     StarlinkInfosApp     │  @main — WindowGroup + Settings (macOS)
                       └────────────┬─────────────┘
                                    │ .environment(AppSettings)
                       ┌────────────▼─────────────┐
                       │       ContentView        │  NavigationSplitView
                       │  sidebar   ┆   detail    │
                       └──┬─────────┴───────┬─────┘
              sections:   │                 │ detail per selection:
        Connexion /       │                 │  DishDashboardView
        Lancements /      │                 │  ArticleDetailView / LaunchDetailView
        Actualités        │                 │
             ┌────────────▼───┐   ┌─────────▼────────┐
             │  FeedViewModel │   │   DishViewModel  │   @Observable @MainActor
             │ articles+launch│   │ polling 2 s      │
             └──┬──────────┬──┘   └────────┬─────────┘
                │          │               │
        ┌───────▼──┐  ┌────▼─────────┐  ┌──▼────────────────┐
        │NewsService│ │LaunchService │  │    DishClient     │  actor
        │Google News│ │Launch Library│  │ gRPC plaintext    │
        │  RSS      │ │ 2 (JSON)     │  │ 192.168.100.1:9200│
        └───────────┘ └──────────────┘  └──┬────────────────┘
                                           │ SpaceX.API.Device.Device/Handle
                                  ┌────────▼─────────┐
                                  │Generated/ (protoc)│  messages + client stub
                                  └──────────────────┘
```

## The dish gRPC API

The Starlink dish exposes a **local, unauthenticated gRPC API in cleartext HTTP/2**
at `192.168.100.1:9200` (service `SpaceX.API.Device.Device`, single unary RPC
`Handle(Request) → Response` with oneof payloads). It is reachable only from the
Starlink LAN.

- **Proto source of truth**: `Proto/dish.protoset`, a `FileDescriptorSet` dumped from
  the dish itself via server reflection (`grpcurl -plaintext -protoset-out ...`).
  Re-dump it after a firmware update if new fields are needed.
- **Code generation** (committed under `StarlinkInfos/Generated/`, never edited by hand):
  ```bash
  protoc --descriptor_set_in=Proto/dish.protoset \
    --swift_out=StarlinkInfos/Generated --swift_opt=Visibility=Internal <all .proto paths>
  protoc --descriptor_set_in=Proto/dish.protoset \
    --grpc-swift-2_out=StarlinkInfos/Generated spacex_api/device/device.proto
  ```
  Plugins: `brew install swift-protobuf grpc-swift` (`protoc-gen-swift`,
  `protoc-gen-grpc-swift-2`).
- **Runtime**: grpc-swift-2 + grpc-swift-nio-transport (`.http2NIOPosix`,
  `.plaintext`, target `.ipv4(address:port:)`). This mandates **macOS 15 / iOS 18**
  minimum deployment targets. URLSession cannot be used instead: it does not support
  cleartext HTTP/2 (h2c).
- **`DishClient` (actor)**: lazily opens one long-lived `GRPCClient`, runs
  `runConnections()` in a background task, and tears down/recreates the client on any
  call failure. All calls carry a 6 s timeout. Used RPCs: `get_status`, `get_history`
  (15 min ring buffers at 1 Hz), `dish_get_obstruction_map`, `reboot`, `dish_stow`.
- Proto → UI mapping lives in `DishClient.swift` extensions (`DishSnapshot(proto)`),
  keeping generated types out of views. `DishModels.swift` holds the clean app-facing
  structs.

## Layers

| Layer | Role | Files |
|---|---|---|
| **App** | Entry points, scenes, `AppSettings` injection | `StarlinkInfosApp.swift` |
| **Views** | Pure SwiftUI | `Views/ContentView.swift`, `Views/Dashboard/*` |
| **ViewModels** | `@Observable @MainActor` state, polling orchestration | `DishViewModel`, `FeedViewModel` |
| **Models** | App-facing structs | `DishModels.swift`, `FeedModels.swift` |
| **Services** | gRPC / HTTP access | `DishClient`, `NewsService`, `LaunchService`, `ConstellationService` |
| **Generated** | protoc output — regenerate, never edit | `Generated/**` |
| **Localization** | Persisted settings + fr/en string table | `Localization/*.swift` |
| **Tests** | Pure-logic unit tests (macOS only) | `StarlinkInfosTests/*.swift` |

## Key decisions

- **Polling**: `DishViewModel` polls status+history every 2 s, obstruction map every
  minute — only while the dashboard is visible (`startPolling`/`stopPolling` on
  appear/disappear). News/launches load once and refresh on demand only: Launch
  Library 2 is rate-limited (~15 req/h).
- **Destructive dish actions** (`reboot`, `stow`) always sit behind a
  `confirmationDialog`. Never trigger them from automated tests.
- **Unreachable dish degrades gracefully**: a `ContentUnavailableView` explains the
  situation (off-LAN) instead of erroring; polling silently retries.
- **Charts** (Swift Charts): latency and throughput are **two separate single-axis
  charts** (never dual-axis). Throughput uses a fixed blue/orange pair (CVD-safe) with
  a legend; connection status is icon + label, never color alone.
- **Obstruction map**: rendered to a `CGImage` (1 px per SNR cell, upscaled with
  `interpolation(.none)`) — far cheaper than a ~15 000-rect `Canvas`.
- **News**: Google News RSS (`hl` follows the app language), parsed with a minimal
  `XMLParser` delegate (`RSSParser`, internal not private, so it's unit-testable via
  `@testable import`). No API key anywhere in the app.
- **Constellation stats**: satellite count from Celestrak
  (`gp.php?GROUP=starlink&FORMAT=json`, free, no key, USSF catalog data). Celestrak
  rate-limits to ~1 request/2h and sometimes replies with a plain-text notice instead
  of JSON when queried again too soon — `ConstellationService` treats that as a
  silent, non-fatal failure (never surfaced to the user), and it's only fetched
  alongside the on-demand news/launches refresh, never polled. Attribution
  ("Celestrak") shown next to the count per their usage policy.
- **Observation** (`@Observable`, `@MainActor`) rather than `ObservableObject`.
- **Settings**: `AppSettings` centralizes appearance + language (UserDefaults). The
  template's Keychain/API-key machinery was removed — nothing to authenticate.
- **In-house localization**: `[lang: [key: value]]` table (`Strings.swift`) with `en`
  fallback, resolved via `settings.t("key")`; `AppLocale.identifier` exposes the
  current locale to model-level date formatting.
- **Build**: Xcode project **generated** by XcodeGen (`project.yml`); `.xcodeproj` is
  not versioned. Regenerate with `xcodegen generate` after any `project.yml` change.
- **Signing/notarization**: handled manually in `release.sh` (Developer ID +
  Hardened Runtime + timestamp retry).
