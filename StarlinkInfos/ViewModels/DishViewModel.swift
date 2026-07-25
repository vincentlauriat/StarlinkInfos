import Foundation
import Observation

@Observable
@MainActor
final class DishViewModel {
    private let client = DishClient()

    var snapshot: DishSnapshot?
    var history: [DishHistorySample] = []
    var obstructionMap: ObstructionMap?

    /// false = l'antenne ne répond pas (hors LAN Starlink, redémarrage…).
    var isReachable = true
    var actionError: String?
    var isPerformingAction = false

    private var pollTask: Task<Void, Never>?
    private var ticks = 0

    // MARK: - Polling

    /// Rafraîchit statut + historique toutes les 2 s, la carte d'obstruction
    /// toutes les minutes. Actif uniquement quand le dashboard est affiché.
    func startPolling() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.tick()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    private func tick() async {
        do {
            snapshot = try await client.status()
            history = try await client.history()
            if obstructionMap == nil || ticks % 30 == 0 {
                obstructionMap = try await client.obstructionMap()
            }
            isReachable = true
            ticks += 1
        } catch {
            isReachable = false
        }
    }

    func refreshObstructionMap() async {
        obstructionMap = try? await client.obstructionMap()
    }

    // MARK: - Actions (destructives : toujours derrière une confirmation UI)

    func reboot() async { await perform { try await $0.reboot() } }
    func stow() async { await perform { try await $0.stow() } }
    func unstow() async { await perform { try await $0.unstow() } }

    private func perform(_ action: (DishClient) async throws -> Void) async {
        isPerformingAction = true
        defer { isPerformingAction = false }
        do {
            try await action(client)
        } catch {
            actionError = error.localizedDescription
        }
    }
}

// MARK: - Formatage

enum DishFormat {
    /// « 7,7 Mb/s » à partir de bits/s.
    static func throughput(_ bps: Double) -> String {
        let mbps = bps / 1_000_000
        if mbps >= 100 { return String(format: "%.0f Mb/s", mbps) }
        if mbps >= 1 { return String(format: "%.1f Mb/s", mbps) }
        return String(format: "%.0f kb/s", bps / 1_000)
    }

    /// « 19 h 36 min » à partir de secondes.
    static func uptime(_ seconds: TimeInterval) -> String {
        let f = DateComponentsFormatter()
        f.allowedUnits = seconds >= 86_400 ? [.day, .hour] : [.hour, .minute]
        f.unitsStyle = .abbreviated
        return f.string(from: seconds) ?? "—"
    }

    static func latency(_ ms: Double) -> String {
        String(format: "%.0f ms", ms)
    }

    static func percent(_ fraction: Double) -> String {
        String(format: "%.1f %%", fraction * 100)
    }
}
