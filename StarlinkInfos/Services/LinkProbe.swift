#if os(macOS)
import Foundation
import Network

/// Mesure du lien Internet, indépendante de l'antenne (portage de
/// `Scripts/flight/flight_monitor.py`). Lectures seules : pings ICMP, sondes
/// traceroute UDP, deux GET HTTPS publics et une résolution DNS inverse.
///
/// macOS uniquement : l'app n'est pas sandboxée et lance `/sbin/ping` et
/// `/usr/sbin/traceroute` (pas de socket ICMP brut sans privilèges).
actor LinkProbe {
    static let internetTarget = "1.1.1.1"
    static let internetCount = 10
    static let spaceHop = 2
    static let spaceCount = 5
    static let cityRefresh: TimeInterval = 600

    private var lastCityAt: Date = .distantPast
    private var lastPopCode: String?
    private var place: (city: String, country: String) = ("", "")

    /// Un relevé complet (~10 s : pings et sondes tournent en parallèle).
    func sample() async -> LinkSample {
        let date = Date()
        async let internet = Self.run("/sbin/ping",
            ["-c", "\(Self.internetCount)", "-i", "1", "-t", "\(Self.internetCount + 5)", Self.internetTarget],
            timeout: TimeInterval(Self.internetCount + 10))
        async let space = Self.run("/usr/sbin/traceroute",
            ["-n", "-f", "\(Self.spaceHop)", "-m", "\(Self.spaceHop)", "-q", "\(Self.spaceCount)",
             "-w", "2", Self.internetTarget],
            timeout: TimeInterval(Self.spaceCount * 2 + 10))
        async let egress = Self.egress()

        let (ip, host, code) = await egress
        if !code.isEmpty, code != lastPopCode || date.timeIntervalSince(lastCityAt) >= Self.cityRefresh {
            place = await Self.city()
            lastCityAt = date
            lastPopCode = code
        }
        let ping = LinkParsers.ping(await internet ?? "")
        let hop = LinkParsers.hop(await space ?? "", probes: Self.spaceCount)

        return LinkSample(
            date: date,
            rttMin: ping.min, rttAvg: ping.avg, rttMax: ping.max, rttStddev: ping.stddev,
            lossPct: ping.lossPct,
            publicIP: ip, hostname: host, popCode: code,
            popCity: code.isEmpty ? "" : place.city, popCountry: code.isEmpty ? "" : place.country,
            spaceHop: hop.address, spaceRttAvg: hop.avg, spaceLossPct: hop.lossPct)
    }

    /// true si l'API gRPC de l'antenne accepte une connexion TCP (sans rien envoyer).
    static func dishReachable(timeout: TimeInterval = 3) async -> Bool {
        await withCheckedContinuation { cont in
            let conn = NWConnection(host: "192.168.100.1", port: 9200, using: .tcp)
            let once = OnceFlag()
            let finish: @Sendable (Bool) -> Void = { ok in
                guard once.claim() else { return }
                conn.cancel()
                cont.resume(returning: ok)
            }
            conn.stateUpdateHandler = { state in
                switch state {
                case .ready: finish(true)
                case .failed, .waiting: finish(false)
                default: break
                }
            }
            conn.start(queue: .global(qos: .utility))
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { finish(false) }
        }
    }

    // MARK: - Sortie Internet

    /// (IP publique, nom DNS inverse, code PoP) — sans ipinfo (pas de quota).
    static func egress() async -> (String, String, String) {
        guard let ip = try? await get("https://api.ipify.org")?
            .trimmingCharacters(in: .whitespacesAndNewlines), !ip.isEmpty else {
            return ("", "", "")
        }
        let host = reverseDNS(ip) ?? ""
        return (ip, host, LinkParsers.popCode(hostname: host) ?? "")
    }

    static func city() async -> (city: String, country: String) {
        guard let body = try? await get("https://ipinfo.io/json"),
              let data = body.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ("", "")
        }
        return (obj["city"] as? String ?? "", obj["country"] as? String ?? "")
    }

    private static func get(_ url: String) async throws -> String? {
        var req = URLRequest(url: URL(string: url)!)
        req.timeoutInterval = 8
        let (data, _) = try await URLSession.shared.data(for: req)
        return String(data: data, encoding: .utf8)
    }

    private static func reverseDNS(_ ip: String) -> String? {
        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        guard inet_pton(AF_INET, ip, &addr.sin_addr) == 1 else { return nil }
        var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let rc = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getnameinfo($0, socklen_t(MemoryLayout<sockaddr_in>.size),
                            &host, socklen_t(host.count), nil, 0, NI_NAMEREQD)
            }
        }
        guard rc == 0 else { return nil }
        return String(cString: host)
    }

    // MARK: - Processus

    /// Lance un outil système et renvoie sa sortie standard, nil si échec ou délai dépassé.
    private static func run(_ path: String, _ args: [String], timeout: TimeInterval) async -> String? {
        await withCheckedContinuation { cont in
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: path)
            proc.arguments = args
            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = FileHandle.nullDevice
            let once = OnceFlag()
            proc.terminationHandler = { _ in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if once.claim() { cont.resume(returning: String(data: data, encoding: .utf8)) }
            }
            do {
                try proc.run()
            } catch {
                if once.claim() { cont.resume(returning: nil) }
                return
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                if proc.isRunning { proc.terminate() }
            }
        }
    }
}

/// Garde « une seule fois » thread-safe pour reprendre une continuation.
private final class OnceFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false
    func claim() -> Bool {
        lock.lock(); defer { lock.unlock() }
        if done { return false }
        done = true
        return true
    }
}

// MARK: - Parseurs (purs, testés)

enum LinkParsers {
    struct PingResult: Equatable {
        var min: Double?, avg: Double?, max: Double?, stddev: Double?
        var lossPct: Double
    }

    struct HopResult: Equatable {
        var address: String
        var avg: Double?
        var lossPct: Double
    }

    /// Résumé de `ping` macOS : « N packets transmitted, M packets received » et
    /// « round-trip min/avg/max/stddev = a/b/c/d ms ».
    static func ping(_ output: String) -> PingResult {
        var loss = 100.0
        if let m = output.firstMatch(of: /(\d+) packets transmitted, (\d+) (?:packets )?received/),
           let tx = Double(m.1), let rx = Double(m.2), tx > 0 {
            loss = (100 * (1 - rx / tx) * 10).rounded() / 10
        }
        guard let r = output.firstMatch(of: /= ([\d.]+)\/([\d.]+)\/([\d.]+)\/([\d.]+) ms/) else {
            return PingResult(lossPct: loss)
        }
        return PingResult(min: Double(r.1), avg: Double(r.2), max: Double(r.3), stddev: Double(r.4),
                          lossPct: loss)
    }

    /// Ligne de saut unique de `traceroute -n -f N -m N -q K` :
    /// « 2  100.64.0.1  55.9 ms  26.9 ms  *  30.6 ms  23.8 ms ».
    static func hop(_ output: String, probes: Int) -> HopResult {
        guard let line = output.split(separator: "\n").first(where: {
            $0.firstMatch(of: /^\s*\d+\s+/) != nil
        }) else {
            return HopResult(address: "", avg: nil, lossPct: 100)
        }
        let tokens = line.split(whereSeparator: \.isWhitespace).dropFirst()
        guard let address = tokens.first, address != "*" else {
            return HopResult(address: "", avg: nil, lossPct: 100)
        }
        let rtts = line.matches(of: /([\d.]+) ms/).compactMap { Double($0.1) }
        let lost = max(0, probes - rtts.count)
        let avg = rtts.isEmpty ? nil : rtts.reduce(0, +) / Double(rtts.count)
        return HopResult(address: String(address), avg: avg,
                         lossPct: (100 * Double(lost) / Double(probes) * 10).rounded() / 10)
    }

    /// « customer.frtabra1.isp.starlink.com » → « frtabra1 » ; nil si pas Starlink.
    static func popCode(hostname: String) -> String? {
        guard let m = hostname.wholeMatch(of: /customer\.([a-z0-9]+)\.isp\.starlink\.com/) else {
            return nil
        }
        return String(m.1)
    }
}
#endif
