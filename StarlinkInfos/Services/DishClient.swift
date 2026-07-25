import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2

/// Client de l'API gRPC locale de l'antenne Starlink (`192.168.100.1:9200`,
/// service `SpaceX.API.Device.Device`, RPC unaire `Handle`).
///
/// La connexion est maintenue tant que l'actor vit ; en cas d'erreur de
/// transport, elle est fermée et recréée au prochain appel. Tous les appels
/// portent un timeout court : l'antenne est sur le LAN, au-delà de quelques
/// secondes elle est considérée injoignable.
actor DishClient {
    static let defaultHost = "192.168.100.1"
    static let defaultPort = 9200

    private let host: String
    private let port: Int

    private var grpc: GRPCClient<HTTP2ClientTransport.Posix>?
    private var connectionTask: Task<Void, Error>?

    init(host: String = DishClient.defaultHost, port: Int = DishClient.defaultPort) {
        self.host = host
        self.port = port
    }

    deinit {
        connectionTask?.cancel()
    }

    // MARK: - Lectures

    func status() async throws -> DishSnapshot {
        let response = try await handle(.with { $0.getStatus = .init() })
        guard case .dishGetStatus(let status) = response.response else {
            throw DishClientError.unexpectedResponse
        }
        return DishSnapshot(status)
    }

    func history() async throws -> [DishHistorySample] {
        let response = try await handle(.with { $0.getHistory = .init() })
        guard case .dishGetHistory(let history) = response.response else {
            throw DishClientError.unexpectedResponse
        }
        return Self.samples(from: history)
    }

    func obstructionMap() async throws -> ObstructionMap {
        let response = try await handle(.with { $0.dishGetObstructionMap = .init() })
        guard case .dishGetObstructionMap(let map) = response.response else {
            throw DishClientError.unexpectedResponse
        }
        return ObstructionMap(rows: Int(map.numRows), cols: Int(map.numCols), snr: map.snr)
    }

    // MARK: - Actions

    func reboot() async throws {
        _ = try await handle(.with { $0.reboot = .init() })
    }

    func stow() async throws {
        _ = try await handle(.with { $0.dishStow = .with { $0.unstow = false } })
    }

    func unstow() async throws {
        _ = try await handle(.with { $0.dishStow = .with { $0.unstow = true } })
    }

    // MARK: - Transport

    private func handle(
        _ request: SpaceX_API_Device_Request
    ) async throws -> SpaceX_API_Device_Response {
        let device = SpaceX_API_Device_Device.Client(wrapping: try connectedClient())
        var options = CallOptions.defaults
        options.timeout = .seconds(6)
        do {
            return try await device.handle(request, options: options)
        } catch {
            // Connexion probablement morte (antenne redémarrée, hors LAN…) :
            // on repart d'un client neuf au prochain appel.
            teardown()
            throw error
        }
    }

    private func connectedClient() throws -> GRPCClient<HTTP2ClientTransport.Posix> {
        if let grpc { return grpc }
        let client = GRPCClient(
            transport: try .http2NIOPosix(
                target: .ipv4(address: host, port: port),
                transportSecurity: .plaintext
            )
        )
        grpc = client
        connectionTask = Task { try await client.runConnections() }
        return client
    }

    private func teardown() {
        grpc?.beginGracefulShutdown()
        connectionTask?.cancel()
        grpc = nil
        connectionTask = nil
    }
}

enum DishClientError: Error {
    case unexpectedResponse
}

// MARK: - Mapping proto → modèles

extension DishSnapshot {
    init(_ s: SpaceX_API_Device_DishGetStatusResponse) {
        timestamp = Date()

        hardwareVersion = s.deviceInfo.hardwareVersion
        softwareVersion = s.deviceInfo.softwareVersion
        countryCode = s.deviceInfo.countryCode
        uptime = TimeInterval(s.deviceState.uptimeS)

        popPingLatencyMs = Double(s.popPingLatencyMs)
        popPingDropRate = Double(s.popPingDropRate)
        downlinkBps = Double(s.downlinkThroughputBps)
        uplinkBps = Double(s.uplinkThroughputBps)
        ethSpeedMbps = Int(s.ethSpeedMbps)
        isSnrAboveNoiseFloor = s.isSnrAboveNoiseFloor

        currentlyObstructed = s.obstructionStats.currentlyObstructed
        fractionObstructed = Double(s.obstructionStats.fractionObstructed)
        avgProlongedObstructionDurationS = Double(s.obstructionStats.avgProlongedObstructionDurationS)
        avgProlongedObstructionValid = s.obstructionStats.avgProlongedObstructionValid

        if s.hasOutage {
            let startNs = s.outage.startTimestampNs
            outage = DishOutageInfo(
                cause: String(describing: s.outage.cause).lowercased(),
                start: startNs > 0 ? Date(timeIntervalSince1970: Double(startNs) / 1_000_000_000) : nil
            )
        } else {
            outage = nil
        }

        gpsValid = s.gpsStats.gpsValid
        gpsSats = Int(s.gpsStats.gpsSats)
        tiltAngleDeg = Double(s.alignmentStats.tiltAngleDeg)
        boresightAzimuthDeg = Double(s.boresightAzimuthDeg)
        boresightElevationDeg = Double(s.boresightElevationDeg)

        stowRequested = s.stowRequested
        softwareUpdateState = String(describing: s.softwareUpdateState).lowercased()
        alerts = DishSnapshot.alerts(from: s.alerts)
    }

    private static func alerts(from a: SpaceX_API_Device_DishAlerts) -> [DishAlert] {
        var result: [DishAlert] = []
        func add(_ flag: Bool, _ key: String, warning: Bool = false) {
            if flag { result.append(DishAlert(key: key, isWarningOnly: warning)) }
        }
        add(a.motorsStuck, "alert_motors_stuck")
        add(a.thermalThrottle, "alert_thermal_throttle", warning: true)
        add(a.thermalShutdown, "alert_thermal_shutdown")
        add(a.mastNotNearVertical, "alert_mast_not_vertical", warning: true)
        add(a.unexpectedLocation, "alert_unexpected_location")
        add(a.slowEthernetSpeeds, "alert_slow_ethernet", warning: true)
        add(a.roaming, "alert_roaming", warning: true)
        add(a.installPending, "alert_install_pending", warning: true)
        add(a.isHeating, "alert_heating", warning: true)
        add(a.powerSupplyThermalThrottle, "alert_psu_thermal", warning: true)
        add(a.lowMotorCurrent, "alert_low_motor_current", warning: true)
        add(a.lowerSignalThanPredicted, "alert_low_signal", warning: true)
        add(a.obstructionMapReset, "alert_obstruction_map_reset", warning: true)
        add(a.dishWaterDetected, "alert_dish_water", warning: true)
        add(a.routerWaterDetected, "alert_router_water", warning: true)
        return result
    }
}

extension DishClient {
    /// Déroule les ring buffers de `DishGetHistoryResponse` : `current` est le
    /// nombre total d'échantillons écrits (1 Hz), l'index d'écriture courant est
    /// `current % taille`. On restitue du plus ancien au plus récent.
    static func samples(from h: SpaceX_API_Device_DishGetHistoryResponse) -> [DishHistorySample] {
        let size = h.popPingLatencyMs.count
        guard size > 0 else { return [] }
        let total = Int(h.current)
        let available = min(total, size)
        let writeIndex = total % size

        func at(_ buffer: [Float], _ i: Int) -> Double {
            buffer.indices.contains(i) ? Double(buffer[i]) : 0
        }

        return (0..<available).map { offset in
            // offset 0 = le plus ancien des échantillons disponibles.
            let i = (writeIndex - available + offset + size * 2) % size
            return DishHistorySample(
                ageSeconds: available - 1 - offset,
                latencyMs: at(h.popPingLatencyMs, i),
                downlinkBps: at(h.downlinkThroughputBps, i),
                uplinkBps: at(h.uplinkThroughputBps, i),
                dropRate: at(h.popPingDropRate, i)
            )
        }
    }
}
