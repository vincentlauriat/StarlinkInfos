# Changelog

Toutes les modifications notables de ce projet sont consignées ici, groupées par type.

## [Unreleased]

### Added
- 2026-07-24 : **Dashboard Connexion Starlink** — client gRPC de l'API locale de
  l'antenne (`DishClient`, grpc-swift-2, code généré depuis `Proto/dish.protoset`
  dumpé par réflexion), polling 2 s, tuiles d'état (latence, débits, pertes,
  obstruction, GPS, Ethernet, inclinaison), graphes Swift Charts 15 min
  (latence + débits), carte d'obstruction (rendu CGImage), alertes localisées,
  actions reboot/stow avec confirmation, état dégradé « antenne injoignable ».
- 2026-07-24 : volet **Actualités** (Google News RSS fr/en, parseur XMLParser) et
  volet **Lancements** (Launch Library 2, compte à rebours, image, statut).
- 2026-07-24 : navigation en sidebar à trois sections (Connexion / Lancements /
  Actualités), détails article et lancement.
- Projet initialisé depuis AppKitTemplate (squelette SwiftUI macOS + iOS).

### Changed
- 2026-07-24 : cibles de déploiement macOS 14→15 et iOS 17→18 (exigence grpc-swift-2) ;
  packages SPM ajoutés (grpc-swift-2 2.4.2, grpc-swift-nio-transport 2.9.0,
  grpc-swift-protobuf 2.4.1, swift-protobuf 1.38.1) ;
  `NSLocalNetworkUsageDescription` ajouté côté iOS.

### Removed
- 2026-07-24 : entité de démonstration `Item`/`ItemsViewModel` et vues associées ;
  Keychain + section « clé API » des réglages (l'API de l'antenne est locale et
  sans authentification).

### Decisions
- 2026-07-24 : actions destructives (reboot/stow) toujours derrière confirmation,
  jamais déclenchées par des tests ; Launch Library 2 rafraîchi à la demande
  uniquement (rate limit ~15 req/h).

### Docs
- 2026-07-24 : bootstrap du projet, `CLAUDE.md` (architecture + commandes réelles),
  `ARCHITECTURE.md` réécrit (section API gRPC de l'antenne, régénération protoc),
  `README.md` (features réelles, roadmap), `PLAN.md`/`MEMORY.md`/`TODOS.md` à jour.
