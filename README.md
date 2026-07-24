# StarlinkInfos

Application **macOS + iOS/iPadOS** en SwiftUI, à codebase partagé.

> Généré depuis [AppKitTemplate](https://github.com/). Remplace ce README par la description de ton app.

## Features

| Feature | macOS | iOS/iPadOS |
|---|:---:|:---:|
| Navigation master-detail (`NavigationSplitView`) | ✅ | ✅ |
| Réglages : apparence (système/clair/sombre) | ✅ | ✅ |
| Réglages : langue (système/fr/en) | ✅ | ✅ |
| Stockage sécurisé Keychain (clé API) | ✅ | ✅ |

## Build

Prérequis : Xcode 15+, [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```bash
xcodegen generate            # génère StarlinkInfos.xcodeproj
open StarlinkInfos.xcodeproj    # macOS : scheme StarlinkInfos — iOS : scheme StarlinkInfosiOS
```

## Release (macOS)

```bash
./Scripts/release.sh 1.0.0   # build → sign → DMG → notarize → staple
```

## Project layout

```
StarlinkInfos/
├── StarlinkInfosApp.swift      # @main
├── Models/Item.swift         # entité (à remplacer)
├── ViewModels/               # logique d'état (@Observable)
├── Views/                    # SwiftUI (ContentView, liste, détail, réglages)
├── Services/Keychain.swift   # stockage sécurisé
├── Localization/             # AppSettings + tables de traduction
└── Assets.xcassets/          # AppIcon
Scripts/                      # release.sh, make-app-icon.swift, make-dmg-background.swift
project.yml                   # config XcodeGen
```

## Licence

MIT — voir [`LICENSE`](LICENSE).
