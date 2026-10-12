# Changelog

Toutes les modifications notables de ce projet sont consignées ici, groupées par type.

## [1.2.0] — 2026-10-12

### Added
- `Scripts/flight/` : outils de mesure du lien Starlink en avion (2026-10-12).
  `flight_monitor.py` relève latence/perte vers 1.1.1.1 toutes les 30 s et le
  point de sortie (ipinfo.io) toutes les 2 min dans un CSV ; `make_chart.py`
  produit un graphique HTML autonome (SVG, survol, mode sombre). Les mesures
  (`Scripts/flight/data/`, IP publique + horodatages de vol) sont gitignorées.
- `flight_monitor.py` enregistre aussi, à chaque relevé, le code du PoP de sortie
  (DNS inverse de l'IP publique via api.ipify.org, sans limite de requêtes ;
  ipinfo.io seulement toutes les 10 min ou à chaque changement de PoP) et la
  latence du segment spatial (traceroute limité au saut 2, la passerelle CGNAT
  `100.64.0.1` ignorant les pings directs). `make_chart.py` trace les deux
  latences et marque les changements de PoP ; il lit toujours les anciens CSV.

- App macOS : section **Mesure du lien** (sidebar Connexion + bouton « Mesurer le
  lien quand même » sur l'écran antenne injoignable). Même mesure que
  `flight_monitor.py` (`LinkProbe`), vue live 30 min, sessions enregistrées
  (Démarrer/Arrêter, JSON dans Application Support, export CSV, suppression),
  démarrage automatique optionnel en vol (réglage), graphes Swift Charts (bout en
  bout / segment spatial, changements de PoP, pertes). macOS uniquement ; iOS
  compile sans la fonction. 10 tests unitaires (parseurs ping/traceroute/PoP, CSV).

### Changed
- `release.sh` : DMG construit avec `dmgbuild` (venv privé, roues épinglées par
  hash) au lieu de l'AppleScript Finder, avec vérification de la mise en page.

### Decisions
- En avion (Wi-Fi Air France via Starlink), l'API gRPC de l'antenne
  `192.168.100.1:9200` n'est pas joignable depuis le réseau passagers :
  l'app ne peut rien afficher côté antenne, ce n'est pas un bug.

## [1.1.0] — 2026-07-25

### Added
- Cible de tests unitaires `StarlinkInfosTests` (macOS) : mapping des ring
  buffers d'historique de l'antenne (`DishClient.samples(from:)`) et parseur
  RSS (`RSSParser`), 7 tests.
- Stats de constellation dans le volet Lancements : nombre de satellites
  Starlink catalogués en orbite via Celestrak (gratuit, sans clé), affiché en
  en-tête de section avec attribution ; échoue silencieusement si Celestrak
  rate-limite (~1 req/2h).
- Signature iOS automatique (`DEVELOPMENT_TEAM: KFLACS69T9`) ; build et
  lancement vérifiés sur simulateur iPhone (données live de l'antenne via le
  réseau du Mac hôte).

## [1.0.0] — 2026-07-25

### Added
- Dashboard Connexion Starlink — client gRPC de l'API locale de l'antenne
  (`DishClient`, grpc-swift-2, code généré depuis `Proto/dish.protoset` dumpé
  par réflexion), polling 2 s, tuiles d'état (latence, débits, pertes,
  obstruction, GPS, Ethernet, inclinaison), graphes Swift Charts 15 min
  (latence + débits), carte d'obstruction (rendu CGImage), alertes localisées,
  actions reboot/stow avec confirmation, état dégradé « antenne injoignable ».
- Volet Actualités (Google News RSS fr/en, parseur XMLParser) et volet
  Lancements (Launch Library 2, compte à rebours, image, statut).
- Navigation en sidebar à trois sections (Connexion / Lancements /
  Actualités), détails article et lancement.
- Icône graphique (antenne parabolique émettant un signal, ciel étoilé) —
  `Scripts/make-starlink-icon.swift`, remplace le placeholder du template.
- Mise à jour automatique **Sparkle 2.9.1** : `SPUStandardUpdaterController`,
  menu « Check for Updates… », vérifications en tâche de fond sans jamais
  installer sans confirmation. Clé EdDSA générée sous le compte trousseau
  `StarlinkInfos`, sauvegarde locale gitignorée.
- Repo GitHub public `vincentlauriat/StarlinkInfos`, branche `master`.
- Première release notarisée : DMG signé Developer ID, notarisé, staplé,
  publié sur GitHub Releases avec `appcast.xml` pour Sparkle.
- Projet initialisé depuis AppKitTemplate (squelette SwiftUI macOS + iOS).

### Changed
- Cibles de déploiement macOS 14→15 et iOS 17→18 (exigence grpc-swift-2) ;
  packages SPM ajoutés (grpc-swift-2 2.4.2, grpc-swift-nio-transport 2.9.0,
  grpc-swift-protobuf 2.4.1, swift-protobuf 1.38.1) ;
  `NSLocalNetworkUsageDescription` ajouté côté iOS.
- `Scripts/release.sh` : signature des binaires imbriqués de
  `Sparkle.framework`, signature Sparkle du DMG (`sign_update`), génération
  de `appcast.xml`, artefacts écrits dans `release/` (plus à la racine).

### Removed
- Entité de démonstration `Item`/`ItemsViewModel` et vues associées ;
  Keychain + section « clé API » des réglages (l'API de l'antenne est locale et
  sans authentification).

### Decisions
- Actions destructives (reboot/stow) toujours derrière confirmation, jamais
  déclenchées par des tests ; Launch Library 2 rafraîchi à la demande
  uniquement (rate limit ~15 req/h).

### Docs
- Bootstrap du projet, `CLAUDE.md` (architecture + commandes réelles),
  `ARCHITECTURE.md` réécrit (section API gRPC de l'antenne, régénération protoc),
  `README.md` (features réelles, roadmap), `PLAN.md`/`MEMORY.md`/`TODOS.md` à jour.
