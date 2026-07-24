import Foundation

/// Table de traductions bilingue (fr / en). Clé → chaîne. `en` sert de repli.
/// Ajoute des langues en ajoutant une entrée de premier niveau (ex. "zh") et le
/// cas correspondant dans `AppLanguage` / `AppSettings.localeIdentifier`.
enum Strings {
    static let table: [String: [String: String]] = [
        "fr": [
            "app_name": "StarlinkInfos",

            // Sidebar / liste
            "search_placeholder": "Rechercher…",
            "refresh": "Rafraîchir",
            "refresh_help": "Recharger la liste",
            "no_items_title": "Aucun élément",
            "no_items_desc": "Tire pour rafraîchir ou vérifie ta source de données.",

            // Groupes de dates
            "group_today": "Aujourd'hui",
            "group_week": "Cette semaine",
            "group_earlier": "Plus tôt",

            // Sélection vide
            "empty_title": "Sélectionne un élément",
            "empty_desc": "Choisis un élément dans la liste pour voir son détail.",

            // Réglages
            "settings_title": "Réglages",
            "settings_appearance": "Apparence",
            "appearance_system": "Système",
            "appearance_light": "Clair",
            "appearance_dark": "Sombre",
            "settings_language": "Langue",
            "language_system": "Système",
            "settings_apikey": "Clé API",
            "apikey_placeholder": "Colle ta clé API…",
            "apikey_help": "Stockée de façon sécurisée dans le Trousseau, jamais en clair.",
            "apikey_present": "Une clé API est enregistrée.",
            "apikey_absent": "Aucune clé API enregistrée.",
            "settings_about": "À propos",
            "settings_about_text": "Généré depuis AppKitTemplate — squelette macOS + iOS SwiftUI.",

            // Divers
            "ok": "OK",
            "error_title": "Erreur",
        ],
        "en": [
            "app_name": "StarlinkInfos",

            "search_placeholder": "Search…",
            "refresh": "Refresh",
            "refresh_help": "Reload the list",
            "no_items_title": "No items",
            "no_items_desc": "Pull to refresh or check your data source.",

            "group_today": "Today",
            "group_week": "This week",
            "group_earlier": "Earlier",

            "empty_title": "Select an item",
            "empty_desc": "Pick an item from the list to see its detail.",

            "settings_title": "Settings",
            "settings_appearance": "Appearance",
            "appearance_system": "System",
            "appearance_light": "Light",
            "appearance_dark": "Dark",
            "settings_language": "Language",
            "language_system": "System",
            "settings_apikey": "API Key",
            "apikey_placeholder": "Paste your API key…",
            "apikey_help": "Stored securely in the Keychain, never in plain text.",
            "apikey_present": "An API key is stored.",
            "apikey_absent": "No API key stored.",
            "settings_about": "About",
            "settings_about_text": "Generated from AppKitTemplate — macOS + iOS SwiftUI skeleton.",

            "ok": "OK",
            "error_title": "Error",
        ],
    ]
}
