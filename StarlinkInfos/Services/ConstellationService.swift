import Foundation

/// Nombre de satellites Starlink actuellement catalogués en orbite, via
/// Celestrak (source publique gratuite, données du catalogue USSF — pas de
/// clé API). Limité à 1 requête / 2 h par Celestrak : ne jamais appeler en
/// polling, uniquement au chargement/rafraîchissement manuel comme les
/// lancements. Attribution requise : "Celestrak".
///
/// Celestrak répond parfois par un simple message texte ("data has not
/// updated...") plutôt que du JSON quand la même requête est répétée avant le
/// prochain rafraîchissement — dans ce cas on échoue silencieusement, ce
/// n'est pas une vraie erreur réseau.
enum ConstellationService {
    static func fetchSatelliteCount() async throws -> Int {
        let url = URL(string: "https://celestrak.org/NORAD/elements/gp.php?GROUP=starlink&FORMAT=json")!
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let array = try JSONSerialization.jsonObject(with: data) as? [Any] else {
            throw ConstellationServiceError.notJSON
        }
        return array.count
    }
}

enum ConstellationServiceError: Error {
    case notJSON
}
