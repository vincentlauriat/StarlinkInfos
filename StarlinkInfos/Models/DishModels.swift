import Foundation

// MARK: - Instantané d'état de l'antenne

/// Photographie de l'état de l'antenne à un instant t, mappée depuis
/// `SpaceX.API.Device.DishGetStatusResponse`. Ne conserver ici que ce que l'UI affiche.
struct DishSnapshot: Sendable {
    var timestamp: Date

    // Identité / device
    var hardwareVersion: String
    var softwareVersion: String
    var countryCode: String
    var uptime: TimeInterval

    // Qualité de connexion
    var popPingLatencyMs: Double
    var popPingDropRate: Double
    var downlinkBps: Double
    var uplinkBps: Double
    var ethSpeedMbps: Int
    var isSnrAboveNoiseFloor: Bool

    // Obstructions
    var currentlyObstructed: Bool
    var fractionObstructed: Double
    var avgProlongedObstructionDurationS: Double
    var avgProlongedObstructionValid: Bool

    // Panne en cours (nil si connecté)
    var outage: DishOutageInfo?

    // GPS / alignement
    var gpsValid: Bool
    var gpsSats: Int
    var tiltAngleDeg: Double
    var boresightAzimuthDeg: Double
    var boresightElevationDeg: Double

    // États
    var stowRequested: Bool
    var softwareUpdateState: String
    var alerts: [DishAlert]

    var isOnline: Bool { outage == nil }
}

struct DishOutageInfo: Sendable, Equatable {
    var cause: String
    var start: Date?
}

/// Alerte remontée par l'antenne — `key` est la clé de traduction (`alert_*`).
struct DishAlert: Sendable, Identifiable, Hashable {
    var key: String
    var isWarningOnly: Bool
    var id: String { key }
}

// MARK: - Historique (ring buffers ~15 min à 1 Hz)

struct DishHistorySample: Sendable, Identifiable {
    /// Ancienneté en secondes par rapport à l'échantillon le plus récent (0 = maintenant).
    var ageSeconds: Int
    var latencyMs: Double
    var downlinkBps: Double
    var uplinkBps: Double
    var dropRate: Double
    var id: Int { ageSeconds }
}

// MARK: - Carte d'obstruction

/// Grille SNR vue du ciel par l'antenne. `snr[row * cols + col]` ∈ [0, 1],
/// valeur négative = case jamais mesurée.
struct ObstructionMap: Sendable {
    var rows: Int
    var cols: Int
    var snr: [Float]
}
