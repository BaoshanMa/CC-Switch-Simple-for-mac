import SwiftUI

struct ProviderListView: View {
    @EnvironmentObject var appState: AppState
    let profile: Profile
    let onOpenSettings: (UUID?) -> Void

    var providers: [Provider] { appState.providers(for: profile.id) }

    var body: some View {
        VStack(spacing: 0) {
            Text(profile.name + " / 供应商")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 6)

            ScrollView {
                VStack(spacing: 4) {
                    ForEach(providers) { provider in
                        ProviderRowView(provider: provider, profileId: profile.id)
                    }
                }
                .padding(.horizontal, 8)
            }

            Divider().padding(.top, 6)
            HStack {
                Button("管理供应商...") { onOpenSettings(profile.id) }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }
}

struct ProviderRowView: View {
    @EnvironmentObject var appState: AppState
    let provider: Provider
    let profileId: UUID
    @State private var alertMessage: String?
    @State private var showAlert = false
    @State private var showCreateDirAlert = false
    @State private var pendingProviderForDirCreation: Provider?

    var isActive: Bool {
        appState.profiles.first(where: { $0.id == profileId })?.activeProviderId == provider.id
    }

    var body: some View {
        Button {
            do {
                try appState.activateProvider(provider)
            } catch AppState.ActivationError.directoryNotFound(let url) {
                alertMessage = "配置目录不存在：\(url.path)\n是否创建该目录？"
                pendingProviderForDirCreation = provider
                showCreateDirAlert = true
            } catch {
                alertMessage = error.localizedDescription
                showAlert = true
            }
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(isActive ? Color.green : Color.secondary.opacity(0.4))
                    .frame(width: 7, height: 7)
                VStack(alignment: .leading, spacing: 1) {
                    Text(provider.name).font(.system(size: 13))
                    if !provider.env.anthropicBaseURL.isEmpty {
                        Text(provider.env.anthropicBaseURL)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                if isActive {
                    Text("使用中")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(isActive ? Color.green.opacity(0.08) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .alert("切换失败", isPresented: $showAlert) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "未知错误")
        }
        .alert("目录不存在", isPresented: $showCreateDirAlert) {
            Button("创建目录") {
                if let p = pendingProviderForDirCreation,
                   let profile = appState.profiles.first(where: { $0.id == p.profileId }) {
                    do {
                        try FileManager.default.createDirectory(at: profile.configDir, withIntermediateDirectories: true)
                        try appState.activateProvider(p)
                    } catch {
                        alertMessage = "操作失败：\(error.localizedDescription)"
                        showAlert = true
                    }
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
    }
}
