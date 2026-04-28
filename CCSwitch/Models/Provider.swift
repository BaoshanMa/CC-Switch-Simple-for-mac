import Foundation

struct Provider: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var profileId: UUID
    var name: String
    var env: EnvFields
}

struct EnvFields: Codable, Equatable {
    var anthropicAuthToken: String = ""
    var anthropicBaseURL: String = ""
    var anthropicModel: String = ""
    var anthropicDefaultHaikuModel: String = ""
    var anthropicDefaultSonnetModel: String = ""
    var anthropicDefaultOpusModel: String = ""
    var apiTimeoutMs: String = ""
    var claudeCodeDisableNonessentialTraffic: String = ""

    /// 所有 8 个字段均写入（含空字符串），确保完整覆写整个 env 节点，不残留旧字段
    func toDictionary() -> [String: String] {
        return [
            "ANTHROPIC_AUTH_TOKEN": anthropicAuthToken,
            "ANTHROPIC_BASE_URL": anthropicBaseURL,
            "ANTHROPIC_MODEL": anthropicModel,
            "ANTHROPIC_DEFAULT_HAIKU_MODEL": anthropicDefaultHaikuModel,
            "ANTHROPIC_DEFAULT_SONNET_MODEL": anthropicDefaultSonnetModel,
            "ANTHROPIC_DEFAULT_OPUS_MODEL": anthropicDefaultOpusModel,
            "API_TIMEOUT_MS": apiTimeoutMs,
            "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": claudeCodeDisableNonessentialTraffic,
        ]
    }
}
