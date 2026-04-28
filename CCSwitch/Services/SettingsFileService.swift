import Foundation

class SettingsFileService {

    /// 切换供应商：读取现有 settings.json，替换 env 字段后写回
    func applyProvider(_ provider: Provider, toConfigDir dir: URL) throws {
        let settingsURL = dir.appendingPathComponent("settings.json")
        var json: [String: Any] = [:]
        if FileManager.default.fileExists(atPath: settingsURL.path) {
            let data = try Data(contentsOf: settingsURL)
            json = (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        }
        json["env"] = provider.env.toDictionary()
        let output = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
        try output.write(to: settingsURL, options: .atomic)
    }

    /// 读取配置模版：返回去掉 env 字段后的 JSON 字典，用于模版编辑器初始值
    func readTemplate(fromConfigDir dir: URL) throws -> [String: Any] {
        let settingsURL = dir.appendingPathComponent("settings.json")
        guard FileManager.default.fileExists(atPath: settingsURL.path) else { return [:] }
        let data = try Data(contentsOf: settingsURL)
        var json = (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        json.removeValue(forKey: "env")
        return json
    }

    /// 保存模版：将模版 JSON 与激活 Provider 的 env 合并后写入
    /// 若当前无激活 Provider，保留文件中已有的 env 字段（不清除）
    func saveTemplate(_ templateJson: [String: Any], configDir dir: URL, activeProvider: Provider?) throws {
        var json = templateJson
        json.removeValue(forKey: "env")
        if let provider = activeProvider {
            json["env"] = provider.env.toDictionary()
        } else {
            // 无激活 Provider 时，从现有文件读取 env 并保留，避免清除用户配置
            let settingsURL = dir.appendingPathComponent("settings.json")
            if FileManager.default.fileExists(atPath: settingsURL.path),
               let data = try? Data(contentsOf: settingsURL),
               let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let existingEnv = existing["env"] {
                json["env"] = existingEnv
            }
        }
        let settingsURL = dir.appendingPathComponent("settings.json")
        let output = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
        try output.write(to: settingsURL, options: .atomic)
    }
}
