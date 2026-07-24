import SwiftUI

struct ContentView: View {
    @Environment(AppSettings.self) private var settings
    @State private var vm = ItemsViewModel()
    @State private var selectedId: String?
    #if os(iOS)
    @State private var showingSettings = false
    #endif

    var body: some View {
        NavigationSplitView {
            ItemListView(vm: vm, selectedId: $selectedId)
                .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 360)
                #if os(iOS)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                }
                #endif
        } detail: {
            if let item = vm.selectedItem {
                ItemDetailView(item: item)
            } else {
                EmptySelectionView()
            }
        }
        .task { await vm.load() }
        .onChange(of: selectedId) { _, id in
            guard let id, let item = vm.items.first(where: { $0.id == id }) else { return }
            vm.select(item)
        }
        .alert(settings.t("error_title"), isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button(settings.t("ok")) { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
        #if os(iOS)
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                SettingsView()
                    .environment(settings)
                    .navigationTitle(settings.t("settings_title"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(settings.t("ok")) { showingSettings = false }
                        }
                    }
            }
        }
        #endif
    }
}
