import Foundation

/// Entité de démonstration du template. Remplace-la par ton propre modèle métier
/// (elle est volontairement simple : un identifiant, un titre, un sous-titre,
/// une date et un corps de texte affiché dans le détail).
struct Item: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let createdAt: Date
    let body: String

    var dateFormatted: String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        df.locale = Locale(identifier: AppLocale.identifier)
        return df.string(from: createdAt)
    }
}

extension Item {
    /// Jeu de données de démonstration, servi par le `ItemsViewModel` pour que le
    /// template compile et se lance immédiatement. À supprimer une fois branché
    /// sur ta vraie source (API, base locale, fichiers…).
    static func sampleData(now: Date = Date()) -> [Item] {
        (0..<12).map { i in
            Item(
                id: "item-\(i)",
                title: "Item \(i + 1)",
                subtitle: "Sous-titre de démonstration",
                createdAt: now.addingTimeInterval(Double(-i) * 3600),
                body: """
                Ceci est le corps de l'item \(i + 1).

                Remplace `Item` et `ItemsViewModel` par ton modèle et ta logique \
                de chargement. Le reste du template (navigation, réglages, \
                apparence, langue, Keychain, release) est prêt à l'emploi.
                """
            )
        }
    }
}
