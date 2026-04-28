import SwiftUI

struct ProviderListPanelView: View {
    @EnvironmentObject var appState: AppState
    let profile: Profile
    @State private var showAddProvider = false
    @State private var editTarget: Provider?
    @State private var showTemplateEditor = false
    @State private var updateErrorMessage: String?
    @State private var showUpdateError = false
    @State private var copyToSourceProvider: Provider?

    var providers: [Provider] { appState.providers(for: profile.id) }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(profile.name)
                    .font(.system(size: 13, weight: .medium))
                Text("/ 供应商配置")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Spacer()
                Button("📄 配置模版") { showTemplateEditor = true }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.12))
                    .cornerRadius(5)
                Button("+ 添加供应商") { showAddProvider = true }
                    .buttonStyle(.borderedProminent)
                    .font(.system(size: 12))
                    .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(providers) { provider in
                        ProviderCardView(
                            provider: provider,
                            profile: profile,
                            onEdit: { editTarget = provider },
                            onClone: {
                                let cloned = appState.cloneProvider(provider)
                                editTarget = cloned
                            },
                            onDelete: { appState.deleteProvider(provider) },
                            onCopyToOtherProfile: { copyToSourceProvider = provider }
                        )
                    }
                }
                .padding(16)
            }
        }
        .sheet(isPresented: $showAddProvider) {
            ProviderEditView(profileId: profile.id, provider: nil) { newProvider in
                appState.addProvider(newProvider)
            }
        }
        .sheet(item: $editTarget) { provider in
            ProviderEditView(profileId: profile.id, provider: provider) { updated in
                do {
                    try appState.updateProvider(updated)
                } catch {
                    updateErrorMessage = error.localizedDescription
                    showUpdateError = true
                }
            }
        }
        .alert("保存失败", isPresented: $showUpdateError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(updateErrorMessage ?? "写入 settings.json 失败")
        }
        .sheet(isPresented: $showTemplateEditor) {
            TemplateEditView(profile: profile)
        }
        .sheet(item: $copyToSourceProvider) { provider in
            CloneProviderToProfileSheet(
                sourceProvider: provider,
                profiles: appState.profiles.filter { $0.id != profile.id }
            ) { targetProfile in
                appState.cloneProviderToProfile(provider, targetProfile: targetProfile)
            }
        }
    }
}

struct ProviderCardView: View {
    @EnvironmentObject var appState: AppState
    let provider: Provider
    let profile: Profile
    let onEdit: () -> Void
    let onClone: () -> Void
    let onDelete: () -> Void
    let onCopyToOtherProfile: (() -> Void)?

    var isActive: Bool {
        appState.profiles.first(where: { $0.id == provider.profileId })?.activeProviderId == provider.id
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(isActive ? Color.green : Color.secondary.opacity(0.4))
                    .frame(width: 7, height: 7)
                Text(provider.name)
                    .font(.system(size: 13, weight: .medium))
                if isActive {
                    Text("使用中")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.15))
                        .foregroundColor(.green)
                        .cornerRadius(4)
                }
                Spacer()
                Button("克隆") { onClone() }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundColor(.blue)
                Button("复制到...") { onCopyToOtherProfile?() }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundColor(.orange)
                Button("编辑") { onEdit() }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                Button("删除") { onDelete() }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                if !provider.env.anthropicBaseURL.isEmpty {
                    FieldSummaryView(label: "BASE_URL", value: provider.env.anthropicBaseURL)
                }
                if !provider.env.anthropicModel.isEmpty {
                    FieldSummaryView(label: "MODEL", value: provider.env.anthropicModel)
                }
                if !provider.env.anthropicDefaultHaikuModel.isEmpty {
                    FieldSummaryView(label: "HAIKU", value: provider.env.anthropicDefaultHaikuModel)
                }
                if !provider.env.anthropicDefaultSonnetModel.isEmpty {
                    FieldSummaryView(label: "SONNET", value: provider.env.anthropicDefaultSonnetModel)
                }
            }
        }
        .padding(12)
        .background(isActive ? Color.green.opacity(0.05) : Color(NSColor.controlBackgroundColor))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(isActive ? Color.green.opacity(0.4) : Color.secondary.opacity(0.2)))
        .cornerRadius(8)
    }
}

struct FieldSummaryView: View {
    let label: String
    let value: String
    var body: some View {
        HStack(spacing: 4) {
            Text(label + ":")
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption2)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CloneProviderToProfileSheet: View {
    @Environment(\.dismiss) var dismiss
    let sourceProvider: Provider
    let profiles: [Profile]
    let onSelect: (Profile) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("复制「\(sourceProvider.name)」到")
                .font(.headline)
            Text("选择一个目标配置目录：")
                .font(.caption)
                .foregroundColor(.secondary)
            ScrollView {
                VStack(spacing: 8) {
                    if profiles.isEmpty {
                        Text("没有其他配置目录可选择")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                    }
                    ForEach(profiles) { targetProfile in
                        Button {
                            onSelect(targetProfile)
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(targetProfile.name)
                                        .font(.system(size: 13))
                                    Text(targetProfile.configDir.abbreviatingWithTildeInPath)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "arrow.right")
                                    .foregroundColor(.blue)
                            }
                            .padding(10)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(height: 200)
            HStack {
                Spacer()
                Button("取消") { dismiss() }
            }
        }
        .padding(20)
        .frame(width: 380)
    }
}
