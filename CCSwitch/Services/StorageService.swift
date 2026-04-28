import Foundation

class StorageService {
    private let storageURL: URL

    init(storageURL: URL = StorageService.defaultURL) {
        self.storageURL = storageURL
    }

    static let defaultURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("CCSwitch")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("config.json")
    }()

    struct StorageData: Codable {
        var profiles: [Profile]
        var providers: [Provider]
    }

    func save(profiles: [Profile], providers: [Provider]) throws {
        let data = StorageData(profiles: profiles, providers: providers)
        let encoded = try JSONEncoder().encode(data)
        try encoded.write(to: storageURL, options: .atomic)
    }

    func load() throws -> ([Profile], [Provider]) {
        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            return ([], [])
        }
        let data = try Data(contentsOf: storageURL)
        let decoded = try JSONDecoder().decode(StorageData.self, from: data)
        return (decoded.profiles, decoded.providers)
    }
}
