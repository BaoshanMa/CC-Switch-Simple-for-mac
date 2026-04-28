import Foundation
import Combine

class AppState: ObservableObject {
    @Published var profiles: [Profile] = []
    @Published var providers: [Provider] = []

    private let storage: StorageService
    private let settingsFile: SettingsFileService

    init(storage: StorageService = StorageService(),
         settingsFile: SettingsFileService = SettingsFileService()) {
        self.storage = storage
        self.settingsFile = settingsFile
        load()
    }

    // MARK: - 查询

    func providers(for profileId: UUID) -> [Provider] {
        providers.filter { $0.profileId == profileId }
    }

    func activeProvider(for profile: Profile) -> Provider? {
        guard let id = profile.activeProviderId else { return nil }
        return providers.first { $0.id == id }
    }

    // MARK: - 持久化

    func load() {
        guard let (p, v) = try? storage.load() else { return }
        profiles = p
        providers = v
    }

    private func persist() {
        try? storage.save(profiles: profiles, providers: providers)
    }

    // MARK: - Profile CRUD

    func addProfile(_ profile: Profile) {
        profiles.append(profile)
        persist()
    }

    func updateProfile(_ profile: Profile) {
        guard let idx = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        profiles[idx] = profile
        persist()
    }

    func deleteProfile(_ profile: Profile) {
        providers.removeAll { $0.profileId == profile.id }
        profiles.removeAll { $0.id == profile.id }
        persist()
    }

    func cloneProfile(_ profile: Profile, newName: String, newConfigDir: URL) {
        var newProfile = profile
        newProfile.id = UUID()
        newProfile.name = newName
        newProfile.configDir = newConfigDir
        newProfile.activeProviderId = nil
        let clonedProviders = providers(for: profile.id).map { p -> Provider in
            var np = p
            np.id = UUID()
            np.profileId = newProfile.id
            return np
        }
        profiles.append(newProfile)
        providers.append(contentsOf: clonedProviders)
        persist()
    }

    // MARK: - Provider CRUD

    func addProvider(_ provider: Provider) {
        providers.append(provider)
        persist()
    }

    func updateProvider(_ provider: Provider) throws {
        guard let idx = providers.firstIndex(where: { $0.id == provider.id }) else { return }
        providers[idx] = provider
        if let profile = profiles.first(where: { $0.activeProviderId == provider.id }) {
            try settingsFile.applyProvider(provider, toConfigDir: profile.configDir)
        }
        persist()
    }

    func deleteProvider(_ provider: Provider) {
        if let idx = profiles.firstIndex(where: { $0.activeProviderId == provider.id }) {
            profiles[idx].activeProviderId = nil
        }
        providers.removeAll { $0.id == provider.id }
        persist()
    }

    func cloneProvider(_ provider: Provider) -> Provider {
        var np = provider
        np.id = UUID()
        np.name = provider.name + " 副本"
        providers.append(np)
        persist()
        return np
    }

    /// 将供应商复制到另一个配置目录，成为目标目录的新供应商（并设为激活）
    func cloneProviderToProfile(_ provider: Provider, targetProfile: Profile) {
        var newProvider = provider
        newProvider.id = UUID()
        newProvider.profileId = targetProfile.id
        newProvider.name = provider.name
        providers.append(newProvider)

        // 将新供应商的 env 写入目标目录的 settings.json，并设为激活供应商
        try? settingsFile.applyProvider(newProvider, toConfigDir: targetProfile.configDir)

        // 更新目标 profile 的激活供应商
        if let idx = profiles.firstIndex(where: { $0.id == targetProfile.id }) {
            profiles[idx].activeProviderId = newProvider.id
        }
        persist()
    }

    // MARK: - 切换供应商

    enum ActivationError: LocalizedError {
        case directoryNotFound(URL)
        var errorDescription: String? {
            switch self {
            case .directoryNotFound(let url):
                return "目录不存在：\(url.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))"
            }
        }
    }

    func activateProvider(_ provider: Provider) throws {
        guard let profileIdx = profiles.firstIndex(where: { $0.id == provider.profileId }) else { return }
        let dir = profiles[profileIdx].configDir
        if !FileManager.default.fileExists(atPath: dir.path) {
            throw ActivationError.directoryNotFound(dir)
        }
        try settingsFile.applyProvider(provider, toConfigDir: dir)
        profiles[profileIdx].activeProviderId = provider.id
        persist()
    }
}
