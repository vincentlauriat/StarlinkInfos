import SwiftUI

/// Dashboard principal : état de la connexion Starlink en temps réel.
struct DishDashboardView: View {
    @Environment(AppSettings.self) private var settings
    @Bindable var vm: DishViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                DishStatusHeader(vm: vm)

                if let snapshot = vm.snapshot {
                    DishStatTiles(snapshot: snapshot)

                    if !snapshot.alerts.isEmpty {
                        DishAlertsSection(alerts: snapshot.alerts)
                    }

                    DishChartsSection(history: vm.history)

                    HStack(alignment: .top, spacing: 20) {
                        DishObstructionSection(vm: vm, snapshot: snapshot)
                        DishInfoSection(snapshot: snapshot)
                    }

                    DishControlsSection(vm: vm)
                } else if !vm.isReachable {
                    ContentUnavailableView(
                        settings.t("dish_unreachable_title"),
                        systemImage: "antenna.radiowaves.left.and.right.slash",
                        description: Text(settings.t("dish_unreachable_desc"))
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else {
                    ProgressView(settings.t("dish_connecting"))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                }
            }
            .padding(20)
        }
        .navigationTitle(settings.t("section_connection"))
        .task {
            vm.startPolling()
        }
        .onDisappear {
            vm.stopPolling()
        }
        .alert(settings.t("error_title"), isPresented: Binding(
            get: { vm.actionError != nil },
            set: { if !$0 { vm.actionError = nil } }
        )) {
            Button(settings.t("ok")) { vm.actionError = nil }
        } message: {
            Text(vm.actionError ?? "")
        }
    }
}

// MARK: - En-tête d'état

/// Badge d'état : icône + libellé + couleur (le libellé porte l'info, jamais la
/// couleur seule).
struct DishStatusHeader: View {
    @Environment(AppSettings.self) private var settings
    let vm: DishViewModel

    private var state: (key: String, icon: String, color: Color) {
        guard vm.isReachable, let s = vm.snapshot else {
            return ("status_unreachable", "antenna.radiowaves.left.and.right.slash", .red)
        }
        if !s.isOnline { return ("status_offline", "xmark.circle.fill", .red) }
        if s.stowRequested { return ("status_stowed", "arrow.down.circle.fill", .orange) }
        if s.currentlyObstructed { return ("status_obstructed", "exclamationmark.triangle.fill", .yellow) }
        return ("status_online", "checkmark.circle.fill", .green)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: state.icon)
                .font(.title)
                .foregroundStyle(state.color)
            VStack(alignment: .leading, spacing: 2) {
                Text(settings.t(state.key))
                    .font(.title2.bold())
                if let s = vm.snapshot {
                    Text("\(settings.t("uptime")) \(DishFormat.uptime(s.uptime))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let outage = vm.snapshot?.outage {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(settings.t("outage_cause"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(outage.cause)
                        .font(.callout.monospaced())
                }
            }
        }
        .padding(16)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Tuiles de stats

struct DishStatTiles: View {
    @Environment(AppSettings.self) private var settings
    let snapshot: DishSnapshot

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            StatTile(title: settings.t("stat_latency"),
                     value: DishFormat.latency(snapshot.popPingLatencyMs),
                     icon: "timer")
            StatTile(title: settings.t("stat_download"),
                     value: DishFormat.throughput(snapshot.downlinkBps),
                     icon: "arrow.down")
            StatTile(title: settings.t("stat_upload"),
                     value: DishFormat.throughput(snapshot.uplinkBps),
                     icon: "arrow.up")
            StatTile(title: settings.t("stat_drop_rate"),
                     value: DishFormat.percent(snapshot.popPingDropRate),
                     icon: "drop")
            StatTile(title: settings.t("stat_obstruction"),
                     value: DishFormat.percent(snapshot.fractionObstructed),
                     icon: "cloud")
            StatTile(title: settings.t("stat_gps"),
                     value: snapshot.gpsValid ? "\(snapshot.gpsSats) sat" : settings.t("gps_invalid"),
                     icon: "location")
            StatTile(title: settings.t("stat_ethernet"),
                     value: "\(snapshot.ethSpeedMbps) Mb/s",
                     icon: "cable.connector")
            StatTile(title: settings.t("stat_tilt"),
                     value: String(format: "%.0f°", snapshot.tiltAngleDeg),
                     icon: "angle")
        }
    }
}

struct StatTile: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.title3.monospacedDigit().bold())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Alertes

struct DishAlertsSection: View {
    @Environment(AppSettings.self) private var settings
    let alerts: [DishAlert]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(alerts) { alert in
                Label(settings.t(alert.key),
                      systemImage: alert.isWarningOnly ? "exclamationmark.triangle" : "xmark.octagon")
                    .font(.callout)
                    .foregroundStyle(alert.isWarningOnly ? Color.orange : Color.red)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Infos antenne

struct DishInfoSection: View {
    @Environment(AppSettings.self) private var settings
    let snapshot: DishSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(settings.t("info_title"))
                .font(.headline)
            InfoRow(label: settings.t("info_hardware"), value: snapshot.hardwareVersion)
            InfoRow(label: settings.t("info_software"), value: snapshot.softwareVersion)
            InfoRow(label: settings.t("info_country"), value: snapshot.countryCode)
            InfoRow(label: settings.t("info_azimuth"),
                    value: String(format: "%.1f°", snapshot.boresightAzimuthDeg))
            InfoRow(label: settings.t("info_elevation"),
                    value: String(format: "%.1f°", snapshot.boresightElevationDeg))
            InfoRow(label: settings.t("info_update_state"), value: snapshot.softwareUpdateState)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.callout.monospaced())
                .textSelection(.enabled)
        }
        .font(.callout)
    }
}

// MARK: - Actions

struct DishControlsSection: View {
    @Environment(AppSettings.self) private var settings
    let vm: DishViewModel
    @State private var confirmingReboot = false
    @State private var confirmingStow = false

    var body: some View {
        HStack(spacing: 12) {
            Button(role: .destructive) {
                confirmingReboot = true
            } label: {
                Label(settings.t("action_reboot"), systemImage: "arrow.clockwise.circle")
            }
            .confirmationDialog(settings.t("confirm_reboot_title"),
                                isPresented: $confirmingReboot, titleVisibility: .visible) {
                Button(settings.t("action_reboot"), role: .destructive) {
                    Task { await vm.reboot() }
                }
            } message: {
                Text(settings.t("confirm_reboot_desc"))
            }

            if vm.snapshot?.stowRequested == true {
                Button {
                    Task { await vm.unstow() }
                } label: {
                    Label(settings.t("action_unstow"), systemImage: "arrow.up.circle")
                }
            } else {
                Button {
                    confirmingStow = true
                } label: {
                    Label(settings.t("action_stow"), systemImage: "arrow.down.circle")
                }
                .confirmationDialog(settings.t("confirm_stow_title"),
                                    isPresented: $confirmingStow, titleVisibility: .visible) {
                    Button(settings.t("action_stow"), role: .destructive) {
                        Task { await vm.stow() }
                    }
                } message: {
                    Text(settings.t("confirm_stow_desc"))
                }
            }

            Spacer()
        }
        .disabled(vm.isPerformingAction || !vm.isReachable)
    }
}
