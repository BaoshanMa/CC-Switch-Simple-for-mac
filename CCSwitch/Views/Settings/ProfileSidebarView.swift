import SwiftUI

struct ProfileSidebarView: View {
    @EnvironmentObject var appState: AppState
    @Binding var selectedProfileId: UUID?
    @State private var showAddSheet = false
    @State private var cloneTarget: Profile?

    var body: some View {
        VStack(spacing: 0) {
            Text("配置目录")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            List(appState.profiles, selection: $selectedProfileId) { profile in
                ProfileSidebarRowView(
                    profile: profile,
                    isSelected: selectedProfileId == profile.id,
                    onClone: { cloneTarget = profile },
                    onDelete: { deleteProfile(profile) }
                )
                .tag(profile.id)
            }

            Divider()
            Button("+ 添加目录") { showAddSheet = true }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .padding(10)
        }
        .sheet(isPresented: $showAddSheet) {
            AddProfileSheet { name, url in
                let profile = Profile(name: name, configDir: url)
                appState.addProfile(profile)
                selectedProfileId = profile.id
            }
        }
        .sheet(item: $cloneTarget) { profile in
            CloneProfileSheet(original: profile) { name, url in
                appState.cloneProfile(profile, newName: name, newConfigDir: url)
            }
        }
    }

    private func deleteProfile(_ profile: Profile) {
        appState.deleteProfile(profile)
        if selectedProfileId == profile.id {
            selectedProfileId = appState.profiles.first?.id
        }
    }
}

struct ProfileSidebarRowView: View {
    let profile: Profile
    let isSelected: Bool
    let onClone: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name).font(.system(size: 13))
                Text(profile.configDir.abbreviatingWithTildeInPath)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if isSelected {
                HStack(spacing: 6) {
                    Button("克隆") { onClone() }
                        .buttonStyle(.plain)
                        .font(.caption2)
                        .foregroundColor(.blue)
                    Button("删除") { onDelete() }
                        .buttonStyle(.plain)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
        .contextMenu {
            Button("克隆", action: onClone)
            Button("删除", role: .destructive, action: onDelete)
        }
    }
}

struct AddProfileSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var selectedURL: URL?
    let onAdd: (String, URL) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("添加配置目录").font(.headline)
            TextField("名称（如：公司）", text: $name)
                .textFieldStyle(.roundedBorder)
            HStack {
                Text(selectedURL?.abbreviatingWithTildeInPath ?? "未选择目录")
                    .foregroundColor(selectedURL == nil ? .secondary : .primary)
                    .font(.system(size: 12, design: .monospaced))
                Spacer()
                Button("选择目录") { selectDirectory() }
            }
            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button("添加") {
                    if let url = selectedURL, !name.isEmpty {
                        onAdd(name, url)
                        dismiss()
                    }
                }
                .disabled(name.isEmpty || selectedURL == nil)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 380)
    }

    private func selectDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        if panel.runModal() == .OK { selectedURL = panel.url }
    }
}

struct CloneProfileSheet: View {
    @Environment(\.dismiss) var dismiss
    let original: Profile
    @State private var name: String
    @State private var selectedURL: URL?
    let onClone: (String, URL) -> Void

    init(original: Profile, onClone: @escaping (String, URL) -> Void) {
        self.original = original
        self._name = State(initialValue: original.name + " 副本")
        self.onClone = onClone
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("克隆配置目录").font(.headline)
            TextField("新名称", text: $name)
                .textFieldStyle(.roundedBorder)
            HStack {
                Text(selectedURL?.abbreviatingWithTildeInPath ?? "选择新目录路径")
                    .foregroundColor(selectedURL == nil ? .secondary : .primary)
                    .font(.system(size: 12, design: .monospaced))
                Spacer()
                Button("选择目录") { selectDirectory() }
            }
            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button("克隆") {
                    if let url = selectedURL, !name.isEmpty {
                        onClone(name, url)
                        dismiss()
                    }
                }
                .disabled(name.isEmpty || selectedURL == nil)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 380)
    }

    private func selectDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        if panel.runModal() == .OK { selectedURL = panel.url }
    }
}
