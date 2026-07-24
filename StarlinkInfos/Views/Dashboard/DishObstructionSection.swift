import SwiftUI

/// Carte d'obstruction : grille SNR vue du ciel par l'antenne.
/// Bleu = ciel dégagé mesuré, rouge = obstruction, transparent = jamais mesuré.
struct DishObstructionSection: View {
    @Environment(AppSettings.self) private var settings
    let vm: DishViewModel
    let snapshot: DishSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(settings.t("obstruction_title"))
                    .font(.headline)
                Spacer()
                Button {
                    Task { await vm.refreshObstructionMap() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help(settings.t("refresh"))
            }

            if let map = vm.obstructionMap, let image = ObstructionMapRenderer.render(map) {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .interpolation(.none)
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(.separator, lineWidth: 1))
                    .frame(maxWidth: 260)
                    .frame(maxWidth: .infinity)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 200)
            }

            // Légende : identité par libellé + pastille, jamais couleur seule.
            HStack(spacing: 16) {
                Label(settings.t("obstruction_clear"), systemImage: "circle.fill")
                    .foregroundStyle(Color(red: 0.25, green: 0.5, blue: 0.9))
                Label(settings.t("obstruction_blocked"), systemImage: "circle.fill")
                    .foregroundStyle(Color(red: 0.85, green: 0.25, blue: 0.2))
            }
            .font(.caption)

            Text("\(settings.t("stat_obstruction")) : \(DishFormat.percent(snapshot.fractionObstructed))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
    }
}

/// Rend la grille SNR en CGImage (1 pixel par case) — bien plus rapide qu'un
/// Canvas de ~15 000 rectangles, et l'upscaling `interpolation(.none)` garde
/// les cases nettes.
enum ObstructionMapRenderer {
    static func render(_ map: ObstructionMap) -> CGImage? {
        guard map.rows > 0, map.cols > 0, map.snr.count >= map.rows * map.cols else { return nil }

        let clear = (r: UInt8(64), g: UInt8(128), b: UInt8(230))
        let blocked = (r: UInt8(217), g: UInt8(64), b: UInt8(51))

        var pixels = [UInt8](repeating: 0, count: map.rows * map.cols * 4)
        for i in 0..<(map.rows * map.cols) {
            let snr = map.snr[i]
            let o = i * 4
            if snr < 0 {
                // Case jamais mesurée : transparent.
                continue
            }
            let t = max(0, min(1, snr))
            pixels[o] = UInt8(Float(blocked.r) + (Float(clear.r) - Float(blocked.r)) * t)
            pixels[o + 1] = UInt8(Float(blocked.g) + (Float(clear.g) - Float(blocked.g)) * t)
            pixels[o + 2] = UInt8(Float(blocked.b) + (Float(clear.b) - Float(blocked.b)) * t)
            pixels[o + 3] = 255
        }

        let data = Data(pixels)
        guard let provider = CGDataProvider(data: data as CFData) else { return nil }
        return CGImage(
            width: map.cols,
            height: map.rows,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: map.cols * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
}
