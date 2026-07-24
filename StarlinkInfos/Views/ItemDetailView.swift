import SwiftUI

struct ItemDetailView: View {
    let item: Item

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.largeTitle.bold())
                    Text(item.dateFormatted)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Divider()

                Text(item.body)
                    .font(.body)
                    .textSelection(.enabled)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .navigationTitle(item.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
