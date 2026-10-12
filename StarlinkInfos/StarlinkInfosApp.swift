import SwiftUI

#if os(macOS)
import Sparkle
#endif

@main
struct StarlinkInfosApp: App {
    @State private var settings = AppSettings()
    #if os(macOS)
    /// Au niveau de l'App : une session de mesure survit aux changements de section.
    @State private var linkMonitor = LinkMonitor()
    #endif

    #if os(macOS)
    private let updaterController: SPUStandardUpdaterController = {
        let controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        // Checks run automatically in the background, but never install
        // silently — the user always confirms before anything is applied.
        controller.updater.automaticallyChecksForUpdates = true
        controller.updater.automaticallyDownloadsUpdates = false
        return controller
    }()
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settings)
                #if os(macOS)
                .environment(linkMonitor)
                .task(id: settings.linkAutoStart) {
                    linkMonitor.setAutoStart(settings.linkAutoStart)
                }
                #endif
                .preferredColorScheme(settings.appearance.colorScheme)
        }
        #if os(macOS)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 960, height: 640)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    updaterController.checkForUpdates(nil)
                }
            }
        }
        #endif

        // Réglages via la scène native macOS (⌘,). Sur iOS, les réglages sont
        // présentés en feuille depuis `ContentView` (pas de scène `Settings`).
        #if os(macOS)
        Settings {
            SettingsView()
                .environment(settings)
        }
        #endif
    }
}
