import Foundation

/// Lancements Starlink à venir via Launch Library 2 (thespacedevs.com).
/// API gratuite sans clé, limitée à ~15 requêtes/heure — ne rafraîchir qu'à la
/// demande, jamais en polling.
enum LaunchService {
    static func fetchUpcoming() async throws -> [StarlinkLaunch] {
        let url = URL(string:
            "https://ll.thespacedevs.com/2.2.0/launch/upcoming/?search=starlink&limit=20&mode=detailed")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoded = try JSONDecoder().decode(LL2Response.self, from: data)

        let iso = ISO8601DateFormatter()
        return decoded.results.compactMap { r in
            guard let net = iso.date(from: r.net) else { return nil }
            return StarlinkLaunch(
                id: r.id,
                name: r.name,
                net: net,
                statusAbbrev: r.status?.abbrev ?? "?",
                statusName: r.status?.name ?? "",
                padName: r.pad?.name ?? "",
                locationName: r.pad?.location?.name ?? "",
                missionDescription: r.mission?.description,
                imageURL: r.image.flatMap(URL.init(string:))
            )
        }
    }
}

// MARK: - DTOs Launch Library 2

private struct LL2Response: Decodable {
    let results: [LL2Launch]
}

private struct LL2Launch: Decodable {
    let id: String
    let name: String
    let net: String
    let status: LL2Status?
    let pad: LL2Pad?
    let mission: LL2Mission?
    let image: String?
}

private struct LL2Status: Decodable {
    let name: String?
    let abbrev: String?
}

private struct LL2Pad: Decodable {
    let name: String?
    let location: LL2Location?
}

private struct LL2Location: Decodable {
    let name: String?
}

private struct LL2Mission: Decodable {
    let description: String?
}
