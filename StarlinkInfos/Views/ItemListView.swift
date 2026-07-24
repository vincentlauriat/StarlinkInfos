import SwiftUI

struct ItemListView: View {
    @Environment(AppSettings.self) private var settings
    @Bindable var vm: ItemsViewModel
    @Binding var selectedId: String?

    var body: some View {
        List(selection: $selectedId) {
            ForEach(vm.grouped, id: \.key) { group in
                Section(settings.t(group.key)) {
                    ForEach(group.items) { item in
                        ItemRowView(item: item)
                            .tag(item.id)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .searchable(text: $vm.searchText, placement: .sidebar, prompt: settings.t("search_placeholder"))
        .navigationTitle(settings.t("app_name"))
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    Task { await vm.refresh() }
                } label: {
                    if vm.isLoading {
                        ProgressView().scaleEffect(0.65)
                    } else {
                        Label(settings.t("refresh"), systemImage: "arrow.clockwise")
                    }
                }
                .disabled(vm.isLoading)
                .help(settings.t("refresh_help"))
            }
        }
        .overlay {
            if vm.items.isEmpty && !vm.isLoading {
                ContentUnavailableView(
                    settings.t("no_items_title"),
                    systemImage: "tray",
                    description: Text(settings.t("no_items_desc"))
                )
            }
        }
    }
}
