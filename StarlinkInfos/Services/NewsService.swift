import Foundation

/// Actualités Starlink via le flux RSS de Google News (sans clé API).
/// La langue du flux suit la langue de l'app.
enum NewsService {
    static func fetch(lang: String) async throws -> [Article] {
        let url: URL = lang == "fr"
            ? URL(string: "https://news.google.com/rss/search?q=Starlink&hl=fr&gl=FR&ceid=FR:fr")!
            : URL(string: "https://news.google.com/rss/search?q=Starlink&hl=en-US&gl=US&ceid=US:en")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let parser = RSSParser()
        return parser.parse(data)
    }
}

/// Parseur RSS 2.0 minimal (XMLParser) : title / link / pubDate / source par <item>.
private final class RSSParser: NSObject, XMLParserDelegate {
    private var articles: [Article] = []
    private var inItem = false
    private var currentElement = ""
    private var title = "", link = "", pubDate = "", source = ""

    func parse(_ data: Data) -> [Article] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return articles.sorted { $0.publishedAt > $1.publishedAt }
    }

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
                qualifiedName: String?, attributes: [String: String] = [:]) {
        if name == "item" {
            inItem = true
            title = ""; link = ""; pubDate = ""; source = ""
        }
        currentElement = name
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard inItem else { return }
        switch currentElement {
        case "title": title += string
        case "link": link += string
        case "pubDate": pubDate += string
        case "source": source += string
        default: break
        }
    }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?,
                qualifiedName: String?) {
        guard name == "item" else {
            if name != "item" { currentElement = "" }
            return
        }
        inItem = false
        let trimmedLink = link.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmedLink), !title.isEmpty else { return }
        articles.append(Article(
            id: trimmedLink,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            source: source.trimmingCharacters(in: .whitespacesAndNewlines),
            publishedAt: Self.parseDate(pubDate) ?? Date(),
            link: url
        ))
    }

    /// Format RFC 822 des flux RSS : « Wed, 23 Jul 2026 18:04:00 GMT ».
    private static let rfc822: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return df
    }()

    private static func parseDate(_ s: String) -> Date? {
        rfc822.date(from: s.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
