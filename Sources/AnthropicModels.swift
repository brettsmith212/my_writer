import Foundation

/// The Claude models an Anthropic API key can use, for the Settings model
/// picker. Loaded from GET /v1/models when a key is saved (and on Refresh),
/// and remembered between launches.
@MainActor
final class AnthropicModels: ObservableObject {
    static let shared = AnthropicModels()

    struct Model: Identifiable, Hashable, Codable {
        let id: String
        let name: String
        let created: String
    }

    @Published private(set) var models: [Model] = []
    @Published private(set) var loading = false
    @Published private(set) var lastError: String?
    /// True when the key needs a workspace ID to be sent with requests.
    @Published private(set) var needsWorkspace = false

    private let cacheKey = "anthropicModelsCache"

    private init() {
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let cached = try? JSONDecoder().decode([Model].self, from: data) {
            models = cached
        }
    }

    func load() async {
        guard let key = APIKeyStore.anthropic.key else {
            models = []
            lastError = nil
            return
        }
        loading = true
        defer { loading = false }
        do {
            var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/models?limit=100")!)
            for (name, value) in AIClient.anthropicHeaders(key: key) { request.setValue(value, forHTTPHeaderField: name) }
            request.timeoutInterval = 20
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard status == 200, let json else {
                let message = ((json?["error"] as? [String: Any])?["message"] as? String) ?? "Anthropic returned HTTP \(status)."
                needsWorkspace = AIClient.isWorkspaceError(message)
                throw AIError.http(status == 401 ? "That API key wasn't accepted. Check it and save again."
                    : needsWorkspace ? "This key isn't tied to a workspace. Enter its Workspace ID above, or create a key inside a workspace in the Claude Console."
                    : message)
            }
            needsWorkspace = false
            models = (json["data"] as? [[String: Any]] ?? []).compactMap { item in
                guard let id = item["id"] as? String else { return nil }
                return Model(id: id, name: item["display_name"] as? String ?? id, created: item["created_at"] as? String ?? "")
            }
            .sorted { $0.created > $1.created }
            lastError = models.isEmpty ? "No models are available to this key." : nil
            if let data = try? JSONEncoder().encode(models) { UserDefaults.standard.set(data, forKey: cacheKey) }
        } catch {
            lastError = error.localizedDescription
        }
    }
}
