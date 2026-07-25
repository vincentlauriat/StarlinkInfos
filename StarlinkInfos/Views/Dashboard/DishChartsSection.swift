import SwiftUI
import Charts

/// Graphes latence et débits sur ~15 min (données `get_history`, 1 Hz).
/// Deux graphes séparés — jamais de double axe : latence (ms) et débit (Mb/s)
/// n'ont pas la même échelle.
struct DishChartsSection: View {
    @Environment(AppSettings.self) private var settings
    let history: [DishHistorySample]

    /// Sous-échantillonnage pour l'affichage : ~1 point / 5 s suffit à l'œil
    /// et divise le coût de rendu par 5.
    private var displayed: [DishHistorySample] {
        history.filter { $0.ageSeconds % 5 == 0 }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            latencyChart
            throughputChart
        }
    }

    private var latencyChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Série unique : le titre nomme la série, pas de légende.
            Text(settings.t("chart_latency"))
                .font(.headline)
            Chart(displayed) { sample in
                LineMark(
                    x: .value(settings.t("chart_age"), -sample.ageSeconds),
                    y: .value("ms", sample.latencyMs)
                )
                .lineStyle(StrokeStyle(lineWidth: 2))
                .foregroundStyle(Color.indigo)
                .interpolationMethod(.monotone)
            }
            .chartXAxis {
                AxisMarks(values: [-900, -600, -300, 0]) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = value.as(Int.self) {
                            Text(v == 0 ? settings.t("chart_now") : "\(v / 60) min")
                        }
                    }
                }
            }
            .chartYAxisLabel("ms")
            .frame(height: 160)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
    }

    private var throughputChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(settings.t("chart_throughput"))
                .font(.headline)
            // Deux séries : ordre fixe (descendant bleu, montant orange),
            // paire sûre pour le daltonisme ; légende générée par chartForegroundStyleScale.
            Chart(displayed) { sample in
                LineMark(
                    x: .value(settings.t("chart_age"), -sample.ageSeconds),
                    y: .value("Mb/s", sample.downlinkBps / 1_000_000),
                    series: .value("dir", "down")
                )
                .lineStyle(StrokeStyle(lineWidth: 2))
                .foregroundStyle(by: .value(settings.t("chart_series"), settings.t("chart_download")))
                .interpolationMethod(.monotone)

                LineMark(
                    x: .value(settings.t("chart_age"), -sample.ageSeconds),
                    y: .value("Mb/s", sample.uplinkBps / 1_000_000),
                    series: .value("dir", "up")
                )
                .lineStyle(StrokeStyle(lineWidth: 2))
                .foregroundStyle(by: .value(settings.t("chart_series"), settings.t("chart_upload")))
                .interpolationMethod(.monotone)
            }
            .chartForegroundStyleScale([
                settings.t("chart_download"): Color.blue,
                settings.t("chart_upload"): Color.orange,
            ])
            .chartXAxis {
                AxisMarks(values: [-900, -600, -300, 0]) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = value.as(Int.self) {
                            Text(v == 0 ? settings.t("chart_now") : "\(v / 60) min")
                        }
                    }
                }
            }
            .chartYAxisLabel("Mb/s")
            .frame(height: 160)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
    }
}
