#if os(macOS)
import Foundation

/// Un relevé de la mesure du lien (toutes les 30 s), indépendant de l'antenne :
/// latence/pertes de bout en bout vers 1.1.1.1, latence du segment spatial
/// (saut 2 = passerelle CGNAT Starlink) et PoP de sortie.
struct LinkSample: Codable, Identifiable, Hashable, Sendable {
    var id: Date { date }
    let date: Date

    // Bout en bout (10 pings vers 1.1.1.1) ; nil = aucune réponse.
    var rttMin: Double?
    var rttAvg: Double?
    var rttMax: Double?
    var rttStddev: Double?
    var lossPct: Double

    // Sortie Internet.
    var publicIP: String
    var hostname: String
    var popCode: String
    var popCity: String
    var popCountry: String

    // Segment spatial (sondes traceroute expirant au saut 2).
    var spaceHop: String
    var spaceRttAvg: Double?
    var spaceLossPct: Double

    /// Latence au-delà de la station sol (bout en bout − segment spatial).
    var beyondGroundMs: Double? {
        guard let a = rttAvg, let s = spaceRttAvg else { return nil }
        return a - s
    }
}

enum LinkSessionTrigger: String, Codable, Sendable {
    case manual, auto
}

struct LinkSession: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let startedAt: Date
    var endedAt: Date?
    let trigger: LinkSessionTrigger
    var samples: [LinkSample]

    init(trigger: LinkSessionTrigger, startedAt: Date = Date()) {
        id = UUID()
        self.startedAt = startedAt
        self.trigger = trigger
        samples = []
    }

    /// Codes PoP successifs, sans répétition consécutive (ex. ["frtabra1", "brsaopa1"]).
    var popSequence: [String] {
        LinkStats.popChanges(samples).map(\.popCode)
    }
}

// MARK: - Statistiques

enum LinkStats {
    /// Premier relevé de chaque PoP, dans l'ordre : le 1er élément est le PoP
    /// initial, les suivants sont des changements. Les relevés sans code (coupure)
    /// ne rompent pas une série.
    static func popChanges(_ samples: [LinkSample]) -> [LinkSample] {
        var out: [LinkSample] = []
        for s in samples where !s.popCode.isEmpty {
            if out.last?.popCode != s.popCode { out.append(s) }
        }
        return out
    }

    static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        return sorted[sorted.count / 2]
    }

    /// Ville connue d'un code PoP dans la série, sinon le code seul.
    static func popLabel(_ code: String, in samples: [LinkSample]) -> String {
        if let city = samples.first(where: { $0.popCode == code && !$0.popCity.isEmpty })?.popCity {
            return "\(city) (\(code))"
        }
        return code
    }
}

// MARK: - Export CSV

/// Mêmes colonnes que `Scripts/flight/flight_monitor.py`, pour rester lisible par
/// `make_chart.py`.
enum LinkCSV {
    static let header = ["utc", "rtt_min", "rtt_avg", "rtt_max", "rtt_stddev", "loss_pct",
                         "public_ip", "hostname", "pop_city", "pop_country",
                         "pop_code", "space_hop", "space_rtt_avg", "space_loss_pct"]

    static func export(_ samples: [LinkSample]) -> String {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        var lines = [header.joined(separator: ",")]
        for s in samples {
            let fields: [String] = [
                iso.string(from: s.date),
                num(s.rttMin), num(s.rttAvg), num(s.rttMax), num(s.rttStddev), num(s.lossPct),
                s.publicIP, s.hostname, s.popCity, s.popCountry,
                s.popCode, s.spaceHop, num(s.spaceRttAvg), num(s.spaceLossPct),
            ]
            lines.append(fields.map(escape).joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private static func num(_ v: Double?) -> String {
        guard let v else { return "" }
        return String(format: "%.3f", v)
    }

    private static func escape(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" }) else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
#endif
