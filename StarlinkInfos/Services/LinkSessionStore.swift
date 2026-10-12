#if os(macOS)
import Foundation

/// Sessions de mesure du lien : un fichier JSON par session dans
/// `~/Library/Application Support/StarlinkInfos/LinkSessions/`.
struct LinkSessionStore: Sendable {
    let directory: URL

    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("StarlinkInfos/LinkSessions", isDirectory: true)
    }

    private func url(for id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString).json")
    }

    /// Toutes les sessions, la plus récente d'abord. Un fichier illisible est ignoré.
    func loadAll() -> [LinkSession] {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil)) ?? []
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return files.filter { $0.pathExtension == "json" }
            .compactMap { try? decoder.decode(LinkSession.self, from: Data(contentsOf: $0)) }
            .sorted { $0.startedAt > $1.startedAt }
    }

    func save(_ session: LinkSession) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(session).write(to: url(for: session.id), options: .atomic)
    }

    func delete(_ id: UUID) throws {
        try FileManager.default.removeItem(at: url(for: id))
    }
}
#endif
