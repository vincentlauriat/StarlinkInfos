import SwiftUI

struct ItemRowView: View {
    let item: Item

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(item.title)
                .font(.body)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 5) {
                Text(item.dateFormatted)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !item.subtitle.isEmpty {
                    Text("·").font(.caption).foregroundStyle(.tertiary)
                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
