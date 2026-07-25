import Foundation

/// Table de traductions bilingue (fr / en). Clé → chaîne. `en` sert de repli.
enum Strings {
    static let table: [String: [String: String]] = [
        "fr": [
            "app_name": "StarlinkInfos",

            // Navigation
            "section_connection": "Connexion",
            "section_news": "Actualités",
            "section_launches": "Lancements",
            "constellation_count": "Satellites en orbite :",
            "dashboard_row": "Mon antenne",
            "search_placeholder": "Rechercher…",
            "refresh": "Rafraîchir",
            "refresh_help": "Recharger actus et lancements",

            // Dashboard — états
            "status_online": "Connecté",
            "status_obstructed": "Connecté — obstruction",
            "status_offline": "Hors ligne",
            "status_stowed": "Antenne repliée",
            "status_unreachable": "Antenne injoignable",
            "uptime": "En service depuis",
            "outage_cause": "Cause de la panne",
            "dish_unreachable_title": "Antenne injoignable",
            "dish_unreachable_desc": "Impossible de joindre l'antenne sur 192.168.100.1. Vérifie que tu es sur le réseau Starlink.",
            "dish_connecting": "Connexion à l'antenne…",

            // Dashboard — tuiles
            "stat_latency": "Latence",
            "stat_download": "Descendant",
            "stat_upload": "Montant",
            "stat_drop_rate": "Pertes ping",
            "stat_obstruction": "Obstruction",
            "stat_gps": "GPS",
            "gps_invalid": "Invalide",
            "stat_ethernet": "Ethernet",
            "stat_tilt": "Inclinaison",

            // Graphes
            "chart_latency": "Latence (15 min)",
            "chart_throughput": "Débits (15 min)",
            "chart_age": "Il y a",
            "chart_now": "maintenant",
            "chart_series": "Sens",
            "chart_download": "Descendant",
            "chart_upload": "Montant",

            // Carte d'obstruction
            "obstruction_title": "Carte d'obstruction",
            "obstruction_clear": "Ciel dégagé",
            "obstruction_blocked": "Obstrué",

            // Infos antenne
            "info_title": "Antenne",
            "info_hardware": "Matériel",
            "info_software": "Firmware",
            "info_country": "Pays",
            "info_azimuth": "Azimut",
            "info_elevation": "Élévation",
            "info_update_state": "Mise à jour",

            // Actions
            "action_reboot": "Redémarrer l'antenne",
            "action_stow": "Replier",
            "action_unstow": "Déplier",
            "confirm_reboot_title": "Redémarrer l'antenne ?",
            "confirm_reboot_desc": "La connexion Internet sera coupée pendant 2 à 5 minutes.",
            "confirm_stow_title": "Replier l'antenne ?",
            "confirm_stow_desc": "L'antenne se met en position verticale et la connexion est coupée jusqu'au dépliage.",

            // Alertes antenne
            "alert_motors_stuck": "Moteurs bloqués",
            "alert_thermal_throttle": "Ralentissement thermique",
            "alert_thermal_shutdown": "Arrêt thermique",
            "alert_mast_not_vertical": "Mât non vertical",
            "alert_unexpected_location": "Position inattendue",
            "alert_slow_ethernet": "Liaison Ethernet lente",
            "alert_roaming": "Itinérance (hors cellule d'origine)",
            "alert_install_pending": "Installation en attente",
            "alert_heating": "Dégivrage en cours",
            "alert_psu_thermal": "Alimentation en limite thermique",
            "alert_low_motor_current": "Courant moteur faible",
            "alert_low_signal": "Signal plus faible que prévu",
            "alert_obstruction_map_reset": "Carte d'obstruction réinitialisée",
            "alert_dish_water": "Eau détectée (antenne)",
            "alert_router_water": "Eau détectée (routeur)",

            // Actus / lancements
            "open_in_browser": "Ouvrir dans le navigateur",

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
            "settings_about": "À propos",
            "settings_about_text": "Suivi de connexion Starlink : état de l'antenne en temps réel (API locale), actualités et lancements.",

            // Divers
            "ok": "OK",
            "error_title": "Erreur",
        ],
        "en": [
            "app_name": "StarlinkInfos",

            "section_connection": "Connection",
            "section_news": "News",
            "section_launches": "Launches",
            "constellation_count": "Satellites in orbit:",
            "dashboard_row": "My dish",
            "search_placeholder": "Search…",
            "refresh": "Refresh",
            "refresh_help": "Reload news and launches",

            "status_online": "Online",
            "status_obstructed": "Online — obstructed",
            "status_offline": "Offline",
            "status_stowed": "Dish stowed",
            "status_unreachable": "Dish unreachable",
            "uptime": "Up for",
            "outage_cause": "Outage cause",
            "dish_unreachable_title": "Dish unreachable",
            "dish_unreachable_desc": "Can't reach the dish at 192.168.100.1. Make sure you're on the Starlink network.",
            "dish_connecting": "Connecting to the dish…",

            "stat_latency": "Latency",
            "stat_download": "Download",
            "stat_upload": "Upload",
            "stat_drop_rate": "Ping drop",
            "stat_obstruction": "Obstruction",
            "stat_gps": "GPS",
            "gps_invalid": "Invalid",
            "stat_ethernet": "Ethernet",
            "stat_tilt": "Tilt",

            "chart_latency": "Latency (15 min)",
            "chart_throughput": "Throughput (15 min)",
            "chart_age": "Age",
            "chart_now": "now",
            "chart_series": "Direction",
            "chart_download": "Download",
            "chart_upload": "Upload",

            "obstruction_title": "Obstruction map",
            "obstruction_clear": "Clear sky",
            "obstruction_blocked": "Obstructed",

            "info_title": "Dish",
            "info_hardware": "Hardware",
            "info_software": "Firmware",
            "info_country": "Country",
            "info_azimuth": "Azimuth",
            "info_elevation": "Elevation",
            "info_update_state": "Software update",

            "action_reboot": "Reboot dish",
            "action_stow": "Stow",
            "action_unstow": "Unstow",
            "confirm_reboot_title": "Reboot the dish?",
            "confirm_reboot_desc": "Internet will be down for 2–5 minutes.",
            "confirm_stow_title": "Stow the dish?",
            "confirm_stow_desc": "The dish folds vertically and the connection stays down until unstowed.",

            "alert_motors_stuck": "Motors stuck",
            "alert_thermal_throttle": "Thermal throttling",
            "alert_thermal_shutdown": "Thermal shutdown",
            "alert_mast_not_vertical": "Mast not vertical",
            "alert_unexpected_location": "Unexpected location",
            "alert_slow_ethernet": "Slow Ethernet link",
            "alert_roaming": "Roaming (outside home cell)",
            "alert_install_pending": "Install pending",
            "alert_heating": "Snow melt heating",
            "alert_psu_thermal": "Power supply thermal throttle",
            "alert_low_motor_current": "Low motor current",
            "alert_low_signal": "Lower signal than predicted",
            "alert_obstruction_map_reset": "Obstruction map reset",
            "alert_dish_water": "Water detected (dish)",
            "alert_router_water": "Water detected (router)",

            "open_in_browser": "Open in browser",

            "empty_title": "Select an item",
            "empty_desc": "Pick an item from the list to see its detail.",

            "settings_title": "Settings",
            "settings_appearance": "Appearance",
            "appearance_system": "System",
            "appearance_light": "Light",
            "appearance_dark": "Dark",
            "settings_language": "Language",
            "language_system": "System",
            "settings_about": "About",
            "settings_about_text": "Starlink connection monitor: real-time dish status (local API), news and launches.",

            "ok": "OK",
            "error_title": "Error",
        ],
    ]
}
