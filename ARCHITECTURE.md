# Architecture

Application SwiftUI **à codebase unique partagé** entre deux cibles (macOS + iOS/iPadOS). Les différences de plateforme sont gérées par des blocs `#if os(macOS)` / `#if os(iOS)`, jamais par duplication de fichiers.

## Vue d'ensemble

```
                    ┌─────────────────────────┐
                    │      StarlinkInfosApp      │  @main — Scene(s)
                    │  (WindowGroup + Settings)│
                    └────────────┬────────────┘
                                 │ .environment(AppSettings)
                    ┌────────────▼────────────┐
                    │       ContentView       │  NavigationSplitView
                    │   sidebar  ┆   detail    │
                    └─────┬──────┴──────┬──────┘
                          │             │
              ┌───────────▼──┐   ┌──────▼────────────┐
              │ ItemListView │   │  ItemDetailView   │
              │  (sections)  │   │  EmptySelectionV. │
              └───────┬──────┘   └───────────────────┘
                      │ @Bindable
              ┌───────▼──────────┐
              │  ItemsViewModel  │  @Observable @MainActor
              │  items / filtered│  ← source de données (à brancher)
              └───────┬──────────┘
                      │
              ┌───────▼──────┐
              │  Item (model)│  Codable / Identifiable
              └──────────────┘
```

## Couches

| Couche | Rôle | Fichiers |
|---|---|---|
| **App** | Points d'entrée, scènes, injection de `AppSettings` | `StarlinkInfosApp.swift` |
| **Views** | SwiftUI pur, aucune logique réseau | `Views/*.swift` |
| **ViewModels** | État observable `@MainActor`, orchestration du chargement | `ViewModels/ItemsViewModel.swift` |
| **Models** | Structures `Codable` de données | `Models/Item.swift` |
| **Services** | Accès système / réseau réutilisable | `Services/Keychain.swift` |
| **Localization** | Réglages persistés + traduction | `Localization/*.swift` |

## Décisions clés

- **Observation** (`@Observable`, Swift 5.9) plutôt que `ObservableObject` : moins de boilerplate, granularité fine des invalidations. Les ViewModels sont `@MainActor`.
- **Réglages** : `AppSettings` centralise apparence, langue et secrets. Persistance via `UserDefaults` (non sensible) et **Keychain** (secrets). Injecté dans l'environnement SwiftUI.
- **Localisation maison** : un dictionnaire `[lang: [clé: valeur]]` (`Strings.swift`) avec repli `en`, résolu par `settings.t("clé")`. Plus simple à éditer qu'un `.strings` pour un petit périmètre ; l'identifiant de locale courant est exposé via `AppLocale` pour le formatage de dates hors environnement SwiftUI.
- **Réglages multiplateforme** : sur macOS, scène native `Settings` (⌘,). Sur iOS, feuille présentée depuis `ContentView` (bouton engrenage dans la toolbar).
- **Keychain** : `service` dérivé du `bundleIdentifier` pour isoler les entrées ; secrets jamais écrits en clair ni loggés.
- **Build** : projet Xcode **généré** par XcodeGen (`project.yml`) — le `.xcodeproj` n'est pas versionné (`.gitignore`). Régénérer avec `xcodegen generate`.
- **Signature/notarisation** : gérées manuellement dans `release.sh` (Developer ID + Hardened Runtime + timestamp avec retry), car `xcodebuild` en Release échoue souvent sur les xattrs `com.apple.provenance`.

## Ajouter une entité métier

1. Crée `Models/MonType.swift` (`Codable, Identifiable`).
2. Adapte `ItemsViewModel` (ou crée un VM dédié) : remplace `Item.sampleData()` par ton vrai chargement.
3. Adapte les vues `Item*` ou duplique-les pour ton type.
4. Ajoute les clés d'affichage dans `Strings.swift`.
