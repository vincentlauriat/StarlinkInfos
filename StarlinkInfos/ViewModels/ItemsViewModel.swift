import Foundation
import Observation

@Observable
@MainActor
final class ItemsViewModel {
    var items: [Item] = []
    var searchText: String = ""
    var isLoading = false
    var selectedItem: Item?
    var errorMessage: String?

    var filtered: [Item] {
        guard !searchText.isEmpty else { return items }
        return items.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
            || $0.subtitle.localizedCaseInsensitiveContains(searchText)
        }
    }

    /// Regroupe par ancienneté (aujourd'hui / cette semaine / plus tôt), du plus
    /// récent au plus ancien. C'est le pattern « sidebar sectionnée » de macOS/iPadOS.
    var grouped: [(key: String, items: [Item])] {
        let cal = Calendar.current
        let now = Date()
        let weekAgo = cal.date(byAdding: .day, value: -7, to: now)!
        var today: [Item] = [], week: [Item] = [], older: [Item] = []
        for item in filtered {
            if cal.isDateInToday(item.createdAt) { today.append(item) }
            else if item.createdAt >= weekAgo { week.append(item) }
            else { older.append(item) }
        }
        let byDateDescending: (Item, Item) -> Bool = { $0.createdAt > $1.createdAt }
        today.sort(by: byDateDescending)
        week.sort(by: byDateDescending)
        older.sort(by: byDateDescending)
        return [("group_today", today), ("group_week", week), ("group_earlier", older)]
            .filter { !$0.items.isEmpty }
    }

    // MARK: - Chargement

    /// Charge les items. Ici : données de démonstration après un court délai pour
    /// simuler un appel réseau. Remplace le corps par ton vrai chargement (API…).
    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            try await Task.sleep(for: .milliseconds(300))
            items = Item.sampleData()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func refresh() async {
        await load()
    }

    func select(_ item: Item) {
        selectedItem = item
    }
}
