import XCTest
@testable import CCSwitch

final class SettingsFileServiceTests: XCTestCase {
    var tempDir: URL!
    var service: SettingsFileService!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        service = SettingsFileService()
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func test_applyProvider_writesEnvToSettingsJson() throws {
        let env = EnvFields(
            anthropicAuthToken: "sk-test",
            anthropicBaseURL: "https://api.test.com",
            anthropicModel: "TestModel"
        )
        let provider = Provider(profileId: UUID(), name: "Test", env: env)
        try service.applyProvider(provider, toConfigDir: tempDir)

        let settingsURL = tempDir.appendingPathComponent("settings.json")
        let data = try Data(contentsOf: settingsURL)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let envDict = json["env"] as! [String: String]
        XCTAssertEqual(envDict["ANTHROPIC_AUTH_TOKEN"], "sk-test")
        XCTAssertEqual(envDict["ANTHROPIC_BASE_URL"], "https://api.test.com")
        XCTAssertEqual(envDict["ANTHROPIC_MODEL"], "TestModel")
    }

    func test_applyProvider_preservesExistingTemplateFields() throws {
        let existing: [String: Any] = [
            "permissions": ["allow": ["Bash"]],
            "theme": "dark",
            "env": ["OLD_KEY": "OLD_VALUE"]
        ]
        let existingData = try JSONSerialization.data(withJSONObject: existing)
        let settingsURL = tempDir.appendingPathComponent("settings.json")
        try existingData.write(to: settingsURL)

        let env = EnvFields(anthropicModel: "NewModel")
        let provider = Provider(profileId: UUID(), name: "Test", env: env)
        try service.applyProvider(provider, toConfigDir: tempDir)

        let data = try Data(contentsOf: settingsURL)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertNotNil(json["permissions"])
        XCTAssertEqual(json["theme"] as? String, "dark")
        let envDict = json["env"] as! [String: String]
        XCTAssertNil(envDict["OLD_KEY"])
        XCTAssertEqual(envDict["ANTHROPIC_MODEL"], "NewModel")
        XCTAssertEqual(envDict.count, 8) // 完整 8 个字段
    }

    func test_readTemplate_returnsEmptyDict_whenFileNotExists() throws {
        let result = try service.readTemplate(fromConfigDir: tempDir)
        XCTAssertTrue(result.isEmpty)
    }

    func test_saveTemplate_writesJsonAndPreservesActiveEnv() throws {
        let env = EnvFields(anthropicModel: "ActiveModel")
        let provider = Provider(profileId: UUID(), name: "Active", env: env)

        let templateJson: [String: Any] = ["permissions": ["allow": ["Bash"]]]
        try service.saveTemplate(templateJson, configDir: tempDir, activeProvider: provider)

        let settingsURL = tempDir.appendingPathComponent("settings.json")
        let data = try Data(contentsOf: settingsURL)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertNotNil(json["permissions"])
        let envDict = json["env"] as! [String: String]
        XCTAssertEqual(envDict["ANTHROPIC_MODEL"], "ActiveModel")
    }
}
