import SwiftUI

struct ProfileListView: View {
    @EnvironmentObject var appState: AppState
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text("配置目录")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 6)

            ScrollView {
                VStack(spacing: 4) {
                    ForEach(appState.profiles) { profile in
                        NavigationLink(value: profile) {
                            ProfileRowView(profile: profile)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
            }

            Divider().padding(.top, 6)
            HStack {
                Button("管理目录...") { onOpenSettings() }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("退出") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }
}

struct ProfileRowView: View {
    @EnvironmentObject var appState: AppState
    let profile: Profile

    var activeProviderName: String {
        appState.activeProvider(for: profile)?.name ?? "未选择供应商"
    }

    var isActive: Bool {
        appState.activeProvider(for: profile) != nil
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isActive ? Color.blue : Color.secondary.opacity(0.4))
                .frame(width: 7, height: 7)
            VStack(alignment: .leading, spacing: 1) {
                Text(profile.name).font(.system(size: 13))
                Text(profile.configDir.abbreviatingWithTildeInPath + " · " + activeProviderName)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(isActive ? Color.blue.opacity(0.12) : Color.clear)
        .cornerRadius(6)
    }
}

extension URL {
    var abbreviatingWithTildeInPath: String {
        path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }
}
