import Foundation
import Observation

/// Actualités + lancements Starlink. Chargés au démarrage puis à la demande
/// (bouton rafraîchir) — pas de polling : Launch Library 2 est limité en débit.
@Observable
@MainActor
final class FeedViewModel {
    var articles: [Article] = []
    var launches: [StarlinkLaunch] = []
    var satelliteCount: Int?
    var searchText = ""
    var isLoading = false
    var errorMessage: String?

    var filteredArticles: [Article] {
        guard !searchText.isEmpty else { return articles }
        return articles.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
            || $0.source.localizedCaseInsensitiveContains(searchText)
        }
    }

    func load(lang: String) async {
        isLoading = true
        defer { isLoading = false }
        async let news = NewsService.fetch(lang: lang)
        async let upcoming = LaunchService.fetchUpcoming()
        async let satellites = ConstellationService.fetchSatelliteCount()
        do {
            articles = try await news
        } catch {
            errorMessage = error.localizedDescription
        }
        do {
            launches = try await upcoming
        } catch {
            // Les lancements sont secondaires : échec silencieux si les actus
            // ont chargé, sinon l'erreur actus a déjà été remontée.
            if articles.isEmpty { errorMessage = error.localizedDescription }
        }
        // Purement décoratif et rate-limité côté Celestrak (1 requête/2h) :
        // échec toujours silencieux, jamais remonté à l'utilisateur.
        satelliteCount = try? await satellites
    }
}
