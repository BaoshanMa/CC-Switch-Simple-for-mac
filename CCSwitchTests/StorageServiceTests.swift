import XCTest
@testable import CCSwitch

final class StorageServiceTests: XCTestCase {
    var tempDir: URL!
    var service: StorageService!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        service = StorageService(storageURL: tempDir.appendingPathComponent("config.json"))
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func test_saveAndLoad_roundtrip() throws {
        let profile = Profile(name: "公司", configDir: URL(fileURLWithPath: "/tmp/test"))
        let provider = Provider(
            profileId: profile.id,
            name: "MiniMax",
            env: EnvFields(anthropicBaseURL: "https://api.test.com")
        )
        try service.save(profiles: [profile], providers: [provider])
        let (loadedProfiles, loadedProviders) = try service.load()
        XCTAssertEqual(loadedProfiles, [profile])
        XCTAssertEqual(loadedProviders, [provider])
    }

    func test_load_returnsEmpty_whenFileNotExists() throws {
        let (profiles, providers) = try service.load()
        XCTAssertTrue(profiles.isEmpty)
        XCTAssertTrue(providers.isEmpty)
    }
}
