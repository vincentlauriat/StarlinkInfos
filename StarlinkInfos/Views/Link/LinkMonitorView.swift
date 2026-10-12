#if os(macOS)
import SwiftUI
import Charts
import UniformTypeIdentifiers

/// Mesure du lien Internet indépendante de l'antenne (utile quand l'API locale
/// est injoignable, typiquement en avion) : vue live, sessions enregistrées.
struct LinkMonitorView: View {
    @Environment(AppSettings.self) private var settings
    @Bindable var monitor: LinkMonitor
    @State private var openedSession: LinkSession?

    /// Pendant un enregistrement, on affiche toute la session ; sinon les 30 dernières minutes.
    private var samples: [LinkSample] { monitor.current?.samples ?? monitor.live }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                LinkHeader(monitor: monitor)
                if samples.isEmpty {
                    ProgressView(settings.t("link_first_sample"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else {
                    LinkReport(samples: samples)
                }
                LinkSessionList(monitor: monitor, opened: $openedSession)
            }
            .padding(20)
        }
        .navigationTitle(settings.t("link_title"))
        .onAppear { monitor.viewAppeared() }
        .onDisappear { monitor.viewDisappeared() }
        .sheet(item: $openedSession) { session in
            LinkSessionDetailView(monitor: monitor, session: session)
                .environment(settings)
        }
        .alert(settings.t("error_title"), isPresented: Binding(
            get: { monitor.saveError != nil },
            set: { if !$0 { monitor.saveError = nil } }
        )) {
            Button(settings.t("ok")) { monitor.saveError = nil }
        } message: {
            Text(monitor.saveError ?? "")
        }
    }
}

// MARK: - En-tête

private struct LinkHeader: View {
    @Environment(AppSettings.self) private var settings
    let monitor: LinkMonitor

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: monitor.isRecording ? "record.circle.fill" : "waveform.path.ecg")
                .font(.title)
                .foregroundStyle(monitor.isRecording ? Color.red : Color.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(settings.t(monitor.isRecording ? "link_recording" : "link_live"))
                    .font(.title2.bold())
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if monitor.isSampling {
                ProgressView().scaleEffect(0.6)
            }
            if monitor.isRecording {
                Button(role: .destructive) {
                    monitor.stopSession()
                } label: {
                    Label(settings.t("link_stop"), systemImage: "stop.fill")
                }
            } else {
                Button {
                    monitor.startSession()
                } label: {
                    Label(settings.t("link_start"), systemImage: "record.circle")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
    }

    private var subtitle: String {
        if let current = monitor.current {
            let start = current.startedAt.formatted(date: .omitted, time: .shortened)
            let auto = current.trigger == .auto ? " · " + settings.t("link_auto") : ""
            return "\(settings.t("link_since")) \(start) · \(current.samples.count) \(settings.t("link_samples"))\(auto)"
        }
        return settings.t("link_live_desc")
    }
}

// MARK: - Rapport (tuiles + graphes), partagé entre live et session

struct LinkReport: View {
    @Environment(AppSettings.self) private var settings
    let samples: [LinkSample]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            LinkTiles(samples: samples)
            LinkLatencyChart(samples: samples)
            LinkLossChart(samples: samples)
        }
    }
}

private struct LinkTiles: View {
    @Environment(AppSettings.self) private var settings
    let samples: [LinkSample]
    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    var body: some View {
        let pops = LinkStats.popChanges(samples)
        let lossCount = samples.filter { $0.lossPct > 0 }.count
        LazyVGrid(columns: columns, spacing: 12) {
            StatTile(title: settings.t("link_latency_median"),
                     value: ms(LinkStats.median(samples.compactMap(\.rttAvg))),
                     icon: "timer")
            StatTile(title: settings.t("link_space_median"),
                     value: ms(LinkStats.median(samples.compactMap(\.spaceRttAvg))),
                     icon: "antenna.radiowaves.left.and.right")
            StatTile(title: settings.t("link_worst"),
                     value: ms(samples.compactMap(\.rttAvg).max()),
                     icon: "exclamationmark.triangle")
            StatTile(title: settings.t("link_loss_samples"),
                     value: "\(lossCount) / \(samples.count)",
                     icon: "drop")
            StatTile(title: settings.t("link_pop"),
                     value: pops.last.map { LinkStats.popLabel($0.popCode, in: samples) }
                        ?? settings.t("link_not_starlink"),
                     icon: "building.2")
            StatTile(title: settings.t("link_pop_changes"),
                     value: "\(max(0, pops.count - 1))",
                     icon: "arrow.triangle.swap")
        }
    }

    private func ms(_ v: Double?) -> String { v.map(DishFormat.latency) ?? "—" }
}

/// Coupe les séries aux trous de mesure (> 90 s) pour ne pas relier deux points éloignés.
private func segmentIndex(_ samples: [LinkSample]) -> [Date: Int] {
    var out: [Date: Int] = [:]
    var seg = 0
    for (i, s) in samples.enumerated() {
        if i > 0, s.date.timeIntervalSince(samples[i - 1].date) > 90 { seg += 1 }
        out[s.date] = seg
    }
    return out
}

private struct LinkLatencyChart: View {
    @Environment(AppSettings.self) private var settings
    let samples: [LinkSample]
    @State private var selected: Date?

    var body: some View {
        let seg = segmentIndex(samples)
        let changes = Array(LinkStats.popChanges(samples).dropFirst())
        let endToEnd = settings.t("link_series_e2e")
        let space = settings.t("link_series_space")

        VStack(alignment: .leading, spacing: 8) {
            Text(settings.t("link_chart_latency"))
                .font(.headline)
            Text(settings.t("link_chart_latency_note"))
                .font(.caption)
                .foregroundStyle(.secondary)
            Chart {
                ForEach(samples) { s in
                    if let lo = s.rttMin, let hi = s.rttMax {
                        AreaMark(x: .value("t", s.date), yStart: .value("ms", lo), yEnd: .value("ms", hi),
                                 series: .value("band", "band-\(seg[s.date] ?? 0)"))
                            .foregroundStyle(Color.blue.opacity(0.15))
                    }
                }
                ForEach(samples) { s in
                    if let v = s.rttAvg {
                        LineMark(x: .value("t", s.date), y: .value("ms", v),
                                 series: .value("s", "e2e-\(seg[s.date] ?? 0)"))
                            .foregroundStyle(by: .value(settings.t("link_series"), endToEnd))
                            .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                }
                ForEach(samples) { s in
                    if let v = s.spaceRttAvg {
                        LineMark(x: .value("t", s.date), y: .value("ms", v),
                                 series: .value("s", "space-\(seg[s.date] ?? 0)"))
                            .foregroundStyle(by: .value(settings.t("link_series"), space))
                            .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                }
                // Une ligne a besoin de deux points : on marque les tout premiers relevés.
                if samples.count < 3 {
                    ForEach(samples) { s in
                        if let v = s.rttAvg {
                            PointMark(x: .value("t", s.date), y: .value("ms", v))
                                .foregroundStyle(by: .value(settings.t("link_series"), endToEnd))
                                .symbolSize(64)
                        }
                        if let v = s.spaceRttAvg {
                            PointMark(x: .value("t", s.date), y: .value("ms", v))
                                .foregroundStyle(by: .value(settings.t("link_series"), space))
                                .symbolSize(64)
                        }
                    }
                }
                ForEach(changes) { c in
                    RuleMark(x: .value("t", c.date))
                        .foregroundStyle(.secondary)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .annotation(position: .top, alignment: .leading) {
                            Text("→ " + LinkStats.popLabel(c.popCode, in: samples))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                }
                if let sel = nearest(selected) {
                    RuleMark(x: .value("t", sel.date))
                        .foregroundStyle(.tertiary)
                        .annotation(position: .top, overflowResolution: .init(x: .fit, y: .disabled)) {
                            LinkTooltip(sample: sel, samples: samples)
                        }
                }
            }
            .chartForegroundStyleScale([endToEnd: Color.blue, space: Color.orange])
            .chartXSelection(value: $selected)
            .chartYAxisLabel("ms")
            .frame(height: 220)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
    }

    private func nearest(_ date: Date?) -> LinkSample? {
        guard let date else { return nil }
        return samples.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }
    }
}

private struct LinkTooltip: View {
    @Environment(AppSettings.self) private var settings
    let sample: LinkSample
    let samples: [LinkSample]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(sample.date.formatted(date: .omitted, time: .standard))
                .foregroundStyle(.secondary)
            Text("\(settings.t("link_series_e2e")) : \(sample.rttAvg.map(DishFormat.latency) ?? settings.t("link_no_reply"))")
            Text("\(settings.t("link_series_space")) : \(sample.spaceRttAvg.map(DishFormat.latency) ?? settings.t("link_no_reply"))")
            if let beyond = sample.beyondGroundMs {
                Text("\(settings.t("link_beyond_ground")) : \(DishFormat.latency(beyond))")
                    .foregroundStyle(.secondary)
            }
            Text("\(settings.t("link_loss")) : \(String(format: "%.0f %%", sample.lossPct))")
            if !sample.popCode.isEmpty {
                Text("PoP : \(LinkStats.popLabel(sample.popCode, in: samples))")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption.monospacedDigit())
        .padding(8)
        .background(.background, in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
    }
}

private struct LinkLossChart: View {
    @Environment(AppSettings.self) private var settings
    let samples: [LinkSample]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Série unique : le titre nomme la série, pas de légende.
            Text(settings.t("link_chart_loss"))
                .font(.headline)
            Chart(samples.filter { $0.lossPct > 0 }) { s in
                BarMark(x: .value("t", s.date, unit: .second), y: .value("%", s.lossPct), width: 4)
                    .foregroundStyle(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
            }
            .chartXScale(domain: (samples.first?.date ?? .now)...(samples.last?.date ?? .now))
            .chartYScale(domain: 0...100)
            .chartYAxisLabel("%")
            .frame(height: 100)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Sessions enregistrées

private struct LinkSessionList: View {
    @Environment(AppSettings.self) private var settings
    let monitor: LinkMonitor
    @Binding var opened: LinkSession?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(settings.t("link_sessions"))
                .font(.headline)
            let past = monitor.sessions.filter { $0.id != monitor.current?.id }
            if past.isEmpty {
                Text(settings.t("link_no_sessions"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            ForEach(past) { session in
                Button {
                    opened = session
                } label: {
                    LinkSessionRow(session: session)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct LinkSessionRow: View {
    @Environment(AppSettings.self) private var settings
    let session: LinkSession

    var body: some View {
        HStack {
            Image(systemName: session.trigger == .auto ? "airplane" : "record.circle")
                .foregroundStyle(.secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
    }

    private var detail: String {
        var parts = ["\(session.samples.count) \(settings.t("link_samples"))"]
        if let end = session.endedAt {
            parts.append(DishFormat.uptime(end.timeIntervalSince(session.startedAt)))
        }
        if let median = LinkStats.median(session.samples.compactMap(\.rttAvg)) {
            parts.append(DishFormat.latency(median))
        }
        let pops = session.popSequence
        if !pops.isEmpty { parts.append(pops.joined(separator: " → ")) }
        return parts.joined(separator: " · ")
    }
}

struct LinkSessionDetailView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    let monitor: LinkMonitor
    let session: LinkSession
    @State private var exporting = false
    @State private var confirmingDelete = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.title2.bold())
                Spacer()
                Button {
                    exporting = true
                } label: {
                    Label(settings.t("link_export_csv"), systemImage: "square.and.arrow.up")
                }
                Button(role: .destructive) {
                    confirmingDelete = true
                } label: {
                    Label(settings.t("link_delete"), systemImage: "trash")
                }
                Button(settings.t("ok")) { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(16)
            Divider()
            ScrollView {
                if session.samples.isEmpty {
                    Text(settings.t("link_no_samples"))
                        .foregroundStyle(.secondary)
                        .padding(40)
                } else {
                    LinkReport(samples: session.samples).padding(20)
                }
            }
        }
        .frame(minWidth: 760, minHeight: 620)
        .fileExporter(isPresented: $exporting,
                      document: CSVDocument(text: LinkCSV.export(session.samples)),
                      contentType: .commaSeparatedText,
                      defaultFilename: "starlink-link-\(fileStamp).csv") { _ in }
        .confirmationDialog(settings.t("link_delete_confirm"), isPresented: $confirmingDelete,
                            titleVisibility: .visible) {
            Button(settings.t("link_delete"), role: .destructive) {
                monitor.delete(session)
                dismiss()
            }
        }
    }

    private var fileStamp: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd-HHmm"
        return f.string(from: session.startedAt)
    }
}

struct CSVDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.commaSeparatedText]
    var text: String

    init(text: String) { self.text = text }

    init(configuration: ReadConfiguration) throws {
        text = String(decoding: configuration.file.regularFileContents ?? Data(), as: UTF8.self)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
#endif
