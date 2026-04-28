import SwiftUI

struct ProviderEditView: View {
    @Environment(\.dismiss) var dismiss
    let profileId: UUID
    let original: Provider?
    let onSave: (Provider) -> Void

    @State private var name: String
    @State private var env: EnvFields
    @State private var showToken: Bool = false

    init(profileId: UUID, provider: Provider?, onSave: @escaping (Provider) -> Void) {
        self.profileId = profileId
        self.original = provider
        self.onSave = onSave
        _name = State(initialValue: provider?.name ?? "")
        _env = State(initialValue: provider?.env ?? EnvFields())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(original == nil ? "添加供应商" : "编辑：\(original!.name)")
                .font(.headline)
                .padding(.bottom, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    fieldRow(label: "名称") {
                        TextField("如：MiniMax 生产", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }
                    fieldRow(label: "ANTHROPIC_AUTH_TOKEN") {
                        HStack {
                            if showToken {
                                TextField("sk-...", text: $env.anthropicAuthToken)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 12, design: .monospaced))
                            } else {
                                SecureField("sk-...", text: $env.anthropicAuthToken)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 12, design: .monospaced))
                            }
                            Button(showToken ? "隐藏" : "显示") { showToken.toggle() }
                                .buttonStyle(.plain)
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    fieldRow(label: "ANTHROPIC_BASE_URL") {
                        TextField("https://api.anthropic.com", text: $env.anthropicBaseURL)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12, design: .monospaced))
                    }
                    fieldRow(label: "ANTHROPIC_MODEL") {
                        TextField("claude-sonnet-4-5", text: $env.anthropicModel)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12, design: .monospaced))
                    }
                    HStack(spacing: 12) {
                        fieldRow(label: "HAIKU_MODEL") {
                            TextField("", text: $env.anthropicDefaultHaikuModel)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12, design: .monospaced))
                        }
                        fieldRow(label: "SONNET_MODEL") {
                            TextField("", text: $env.anthropicDefaultSonnetModel)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12, design: .monospaced))
                        }
                    }
                    HStack(spacing: 12) {
                        fieldRow(label: "OPUS_MODEL") {
                            TextField("", text: $env.anthropicDefaultOpusModel)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12, design: .monospaced))
                        }
                        fieldRow(label: "API_TIMEOUT_MS") {
                            TextField("3000000", text: $env.apiTimeoutMs)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12, design: .monospaced))
                        }
                    }
                    fieldRow(label: "DISABLE_NONESSENTIAL_TRAFFIC") {
                        TextField("0 或 1", text: $env.claudeCodeDisableNonessentialTraffic)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12, design: .monospaced))
                    }
                }
            }

            Divider().padding(.vertical, 12)
            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button("保存") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 480)
    }

    @ViewBuilder
    private func fieldRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            content()
        }
    }

    private func save() {
        var provider = original ?? Provider(profileId: profileId, name: name, env: env)
        provider.name = name
        provider.env = env
        onSave(provider)
        dismiss()
    }
}
