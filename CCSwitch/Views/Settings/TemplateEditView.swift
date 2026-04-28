import SwiftUI

struct TemplateEditView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    let profile: Profile

    @State private var jsonText: String = ""
    @State private var errorMessage: String?
    private let settingsFile = SettingsFileService()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("配置模版 — \(profile.name)")
                        .font(.headline)
                    Text(profile.configDir.appendingPathComponent("settings.json").path)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.bottom, 12)

            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                Text("env 字段由供应商配置统一管理，保存时将保留当前激活供应商的 env 值")
                    .font(.caption)
            }
            .foregroundColor(.orange)
            .padding(8)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(6)
            .padding(.bottom, 10)

            TextEditor(text: $jsonText)
                .font(.system(size: 12, design: .monospaced))
                .frame(minHeight: 300)
                .border(Color.secondary.opacity(0.3))

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 4)
            }

            Divider().padding(.vertical, 12)
            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button("保存模版") { saveTemplate() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 540, height: 480)
        .onAppear { loadTemplate() }
    }

    private func loadTemplate() {
        if let template = try? settingsFile.readTemplate(fromConfigDir: profile.configDir),
           !template.isEmpty,
           let data = try? JSONSerialization.data(withJSONObject: template, options: [.prettyPrinted, .sortedKeys]),
           let str = String(data: data, encoding: .utf8) {
            jsonText = str
        } else {
            jsonText = "{}"
        }
    }

    private func saveTemplate() {
        errorMessage = nil
        guard let data = jsonText.data(using: .utf8) else {
            errorMessage = "文本编码错误"
            return
        }
        let json: [String: Any]
        do {
            guard let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                errorMessage = "JSON 格式错误：顶层必须是对象（{}）"
                return
            }
            json = parsed
        } catch {
            errorMessage = "JSON 格式错误：\(error.localizedDescription)"
            return
        }
        let activeProvider = appState.activeProvider(for: profile)
        do {
            try settingsFile.saveTemplate(json, configDir: profile.configDir, activeProvider: activeProvider)
            dismiss()
        } catch {
            errorMessage = "写入失败：\(error.localizedDescription)"
        }
    }
}
