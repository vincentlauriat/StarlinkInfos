#if os(macOS)
import Foundation
import Observation

/// Moteur de la mesure du lien. Vit au niveau de l'`App` pour qu'une session
/// continue quand on change de section ou qu'on ferme la fenêtre.
///
/// - Vue live : relevés tant que la vue est affichée (`viewAppeared`/`viewDisappeared`).
/// - Session : relevés enregistrés jusqu'à `stopSession()`, sauvegardés à chaque relevé.
/// - Auto (réglage) : toutes les 60 s, démarre une session si l'antenne est
///   injoignable mais que la sortie est Starlink (cas de l'avion) ; l'arrête quand
///   l'antenne revient ou après 5 relevés consécutifs hors Starlink.
@Observable
@MainActor
final class LinkMonitor {
    static let sampleInterval: Duration = .seconds(30)
    static let autoCheckInterval: Duration = .seconds(60)
    static let liveWindow: TimeInterval = 30 * 60
    static let autoStopAfterNonStarlink = 5

    private let probe = LinkProbe()
    private let store: LinkSessionStore

    /// Relevés récents (30 dernières minutes) pour la vue live.
    private(set) var live: [LinkSample] = []
    private(set) var current: LinkSession?
    private(set) var sessions: [LinkSession] = []
    private(set) var isSampling = false
    var saveError: String?

    var isRecording: Bool { current != nil }

    private var viewVisible = false
    private var sampleTask: Task<Void, Never>?
    private var autoTask: Task<Void, Never>?
    private var nonStarlinkStreak = 0
    private var sleepActivity: NSObjectProtocol?

    init(store: LinkSessionStore = LinkSessionStore()) {
        self.store = store
        sessions = store.loadAll()
    }

    // MARK: - Vue live

    func viewAppeared() {
        viewVisible = true
        updateSampling()
    }

    func viewDisappeared() {
        viewVisible = false
        updateSampling()
    }

    // MARK: - Sessions

    func startSession(trigger: LinkSessionTrigger = .manual) {
        guard current == nil else { return }
        current = LinkSession(trigger: trigger)
        nonStarlinkStreak = 0
        // Empêche la veille sur inactivité pendant la mesure (pas la fermeture du capot).
        sleepActivity = ProcessInfo.processInfo.beginActivity(
            options: [.idleSystemSleepDisabled, .userInitiated],
            reason: "Starlink link measurement session")
        updateSampling()
    }

    func stopSession() {
        guard let session = current else { return }
        var finished = session
        finished.endedAt = Date()
        persist(finished)
        current = nil
        if let activity = sleepActivity {
            ProcessInfo.processInfo.endActivity(activity)
            sleepActivity = nil
        }
        sessions = store.loadAll()
        updateSampling()
    }

    func delete(_ session: LinkSession) {
        do {
            try store.delete(session.id)
        } catch {
            saveError = error.localizedDescription
        }
        sessions = store.loadAll()
    }

    // MARK: - Mode automatique

    func setAutoStart(_ enabled: Bool) {
        autoTask?.cancel()
        autoTask = nil
        guard enabled else { return }
        autoTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.autoCheck()
                try? await Task.sleep(for: Self.autoCheckInterval)
            }
        }
    }

    private func autoCheck() async {
        if let current, current.trigger == .auto {
            if await LinkProbe.dishReachable() { stopSession() }
            return
        }
        guard current == nil else { return }
        // À la maison l'antenne répond : on s'arrête là, sans requête externe.
        if await LinkProbe.dishReachable() { return }
        let (_, _, code) = await LinkProbe.egress()
        if !code.isEmpty { startSession(trigger: .auto) }
    }

    // MARK: - Boucle de mesure

    private func updateSampling() {
        let shouldRun = viewVisible || current != nil
        if shouldRun, sampleTask == nil {
            sampleTask = Task { [weak self] in
                while !Task.isCancelled {
                    await self?.takeSample()
                    try? await Task.sleep(for: Self.sampleInterval)
                }
            }
        } else if !shouldRun {
            sampleTask?.cancel()
            sampleTask = nil
        }
    }

    private func takeSample() async {
        isSampling = true
        let sample = await probe.sample()
        isSampling = false
        guard !Task.isCancelled else { return }

        live.append(sample)
        let cutoff = sample.date.addingTimeInterval(-Self.liveWindow)
        live.removeAll { $0.date < cutoff }

        guard var session = current else { return }
        session.samples.append(sample)
        current = session
        persist(session)

        if session.trigger == .auto {
            nonStarlinkStreak = sample.popCode.isEmpty && !sample.publicIP.isEmpty
                ? nonStarlinkStreak + 1 : 0
            if nonStarlinkStreak >= Self.autoStopAfterNonStarlink { stopSession() }
        }
    }

    private func persist(_ session: LinkSession) {
        do {
            try store.save(session)
        } catch {
            saveError = error.localizedDescription
        }
    }
}
#endif
