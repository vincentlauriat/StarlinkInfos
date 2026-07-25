import Foundation

// MARK: - Article d'actualité (RSS)

struct Article: Identifiable, Hashable, Sendable {
    let id: String          // URL de l'article
    let title: String
    let source: String
    let publishedAt: Date
    let link: URL

    func dateFormatted(locale: String) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        df.locale = Locale(identifier: locale)
        return df.string(from: publishedAt)
    }
}

// MARK: - Lancement Starlink (Launch Library 2)

struct StarlinkLaunch: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let net: Date                    // No Earlier Than
    let statusAbbrev: String         // "Go", "TBD", "TBC", "Success"…
    let statusName: String
    let padName: String
    let locationName: String
    let missionDescription: String?
    let imageURL: URL?

    func dateFormatted(locale: String) -> String {
        let df = DateFormatter()
        df.dateStyle = .full
        df.timeStyle = .short
        df.locale = Locale(identifier: locale)
        return df.string(from: net)
    }
}
