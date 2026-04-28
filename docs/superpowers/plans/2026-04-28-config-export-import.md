# 全局配置导出/导入功能实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 CC-Switch 设置窗口中添加导出/导入配置功能，支持将所有 Profile 和 Provider 数据备份为 JSON 文件，以及从备份文件恢复配置。

**Architecture:**
- 新增 `ImportExportService` 服务类，负责导出数据的序列化和导入数据的反序列化、冲突处理
- `AppState` 新增 `exportData()` 和 `importData()` 方法作为入口
- UI 层在设置窗口侧边栏底部添加两个按钮，触发 NSSavePanel / NSOpenPanel

**Tech Stack:** Swift, SwiftUI (Settings UI), AppKit (文件对话框), Foundation (JSON)

---

## 文件变更概览

| 文件 | 操作 | 职责 |
|------|------|------|
| `CCSwitch/Services/ImportExportService.swift` | 新增 | 导入导出数据格式定义、序列化/反序列化、冲突处理 |
| `CCSwitch/Models/AppState.swift` | 修改 | 新增 `exportAll()` / `importData()` 方法 |
| `CCSwitch/Views/Settings/SettingsRootView.swift` | 修改 | 添加导出/导入按钮 UI |

---

## Task 1: 创建 ImportExportService

**Files:**
- Create: `CCSwitch/Services/ImportExportService.swift`

- [ ] **Step 1: 编写 ImportExportService**

```swift
import Foundation

struct ExportData: Codable {
    let version: String
    let exportDate: Date
    let profiles: [Profile]
    let providers: [Provider]
}

class ImportExportService {
    static let currentVersion = "1.0"

    // 导出：序列化为 Data
    static func export(profiles: [Profile], providers: [Provider]) throws -> Data {
        let exportData = ExportData(
            version: currentVersion,
            exportDate: Date(),
            profiles: profiles,
            providers: providers
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(exportData)
    }

    enum VersionMismatchError: LocalizedError {
        case incompatibleVersion(String)
        var errorDescription: String? {
            switch self {
            case .incompatibleVersion(let ver):
                return "备份文件版本 (\(ver)) 与当前版本 (\(currentVersion)) 不一致"
            }
        }
    }

    // 导入：反序列化，处理名称冲突
    static func `import`(data: Data, existingProfiles: [Profile]) throws -> ImportResult {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let exportData = try decoder.decode(ExportData.self, from: data)

        // 版本不兼容时抛出错误，由调用方弹出警告对话框
        guard exportData.version == currentVersion else {
            throw VersionMismatchError.incompatibleVersion(exportData.version)
        }

        // 处理 Profile 名称冲突：重命名为 {原名} (导入)
        var profileIdMapping: [UUID: UUID] = [:] // old id -> new id
        var newProfiles: [Profile] = []

        for profile in exportData.profiles {
            var newProfile = profile
            var name = profile.name
            // 检查名称是否冲突
            while newProfiles.contains(where: { $0.name == name }) ||
                  existingProfiles.contains(where: { $0.name == name }) {
                name = "\(profile.name) (导入)"
            }
            newProfile.name = name
            newProfile.id = UUID() // 分配新 ID
            profileIdMapping[profile.id] = newProfile.id
            newProfiles.append(newProfile)
        }

        // 处理 Provider：更新 profileId 映射
        var newProviders: [Provider] = []
        for provider in exportData.providers {
            guard let newProfileId = profileIdMapping[provider.profileId] else {
                continue // 跳过无法映射的 Provider
            }
            var newProvider = provider
            newProvider.id = UUID() // 分配新 ID
            newProvider.profileId = newProfileId
            newProviders.append(newProvider)
        }

        return ImportResult(profiles: newProfiles, providers: newProviders)
    }

    struct ImportResult {
        let profiles: [Profile]
        let providers: [Provider]
    }
}
```

- [ ] **Step 2: 提交**

```bash
git add CCSwitch/Services/ImportExportService.swift
git commit -m "feat: add ImportExportService for config backup and restore

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 2: 在 AppState 中添加导入导出入口

**Files:**
- Modify: `CCSwitch/Models/AppState.swift`

- [ ] **Step 1: 添加导出方法**

在 `AppState.swift` 的 `// MARK: - 持久化` 分区后添加：

```swift
// MARK: - 导入导出

enum ExportError: LocalizedError {
    case noData
    var errorDescription: String? {
        switch self {
        case .noData:
            return "暂无配置可导出"
        }
    }
}

enum ImportError: LocalizedError {
    case invalidFormat
    case parsingFailed(String)
    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "无效的文件格式"
        case .parsingFailed(let reason):
            return "解析失败：\(reason)"
        }
    }
}

struct ImportStats {
    let profileCount: Int
    let providerCount: Int
}

func exportAll() throws -> Data {
    guard !profiles.isEmpty else {
        throw ExportError.noData
    }
    return try ImportExportService.export(profiles: profiles, providers: providers)
}

func importData(_ data: Data) throws -> ImportStats {
    let result = try ImportExportService.import(
        data: data,
        existingProfiles: profiles
    )
    profiles.append(contentsOf: result.profiles)
    providers.append(contentsOf: result.providers)
    persist()
    return ImportStats(
        profileCount: result.profiles.count,
        providerCount: result.providers.count
    )
}
```

- [ ] **Step 2: 提交**

```bash
git add CCSwitch/Models/AppState.swift
git commit -m "feat: add export/import methods to AppState

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 3: 在设置窗口添加导出导入按钮 UI

**Files:**
- Modify: `CCSwitch/Views/Settings/SettingsRootView.swift`

- [ ] **Step 1: 添加导入导出功能到 SettingsRootView**

在 `SettingsRootView.swift` 的 `import SwiftUI` 后添加 `import AppKit`，并将 body 修改为：

```swift
var body: some View {
    HSplitView {
        VStack(spacing: 0) {
            ProfileSidebarView(selectedProfileId: $selectedProfileId)
                .frame(minWidth: 200, maxWidth: 220)

            Divider()

            // 导入导出按钮区域
            HStack(spacing: 12) {
                Button("导出配置") {
                    exportConfig()
                }
                .buttonStyle(.bordered)
                .disabled(appState.profiles.isEmpty)

                Button("导入配置") {
                    importConfig()
                }
                .buttonStyle(.bordered)
            }
            .padding(12)
        }

        if let profile = selectedProfile {
            ProviderListPanelView(profile: profile)
        } else {
            Text("请选择一个配置目录")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    .onAppear {
        if let id = initialProfileId {
            selectedProfileId = id
        } else if selectedProfileId == nil {
            selectedProfileId = appState.profiles.first?.id
        }
    }
}

private func exportConfig() {
    guard !appState.profiles.isEmpty else { return }

    // 警告提示
    let alert = NSAlert()
    alert.messageText = "导出配置包含敏感信息"
    alert.informativeText = "导出的文件包含 API Token，请妥善保管，避免泄露。"
    alert.alertStyle = .warning
    alert.addButton(withTitle: "继续导出")
    alert.addButton(withTitle: "取消")

    guard alert.runModal() == .alertFirstButtonReturn else { return }

    // 文件保存对话框
    let savePanel = NSSavePanel()
    savePanel.allowedContentTypes = [.json]
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyyMMdd"
    savePanel.nameFieldStringValue = "CCSwitch-backup-\(formatter.string(from: Date())).json"

    guard savePanel.runModal() == .OK, let url = savePanel.url else { return }

    do {
        let data = try appState.exportAll()
        try data.write(to: url, options: .atomic)

        let successAlert = NSAlert()
        successAlert.messageText = "导出成功"
        successAlert.informativeText = "配置已保存至：\(url.lastPathComponent)"
        successAlert.alertStyle = .informational
        successAlert.runModal()
    } catch {
        let errorAlert = NSAlert()
        errorAlert.messageText = "导出失败"
        errorAlert.informativeText = error.localizedDescription
        errorAlert.alertStyle = .critical
        errorAlert.runModal()
    }
}

private func importConfig() {
    let openPanel = NSOpenPanel()
    openPanel.allowedContentTypes = [.json]
    openPanel.allowsMultipleSelection = false

    guard openPanel.runModal() == .OK, let url = openPanel.url else { return }

    do {
        let data = try Data(contentsOf: url)
        let stats = try appState.importData(data)

        let successAlert = NSAlert()
        successAlert.messageText = "导入成功"
        successAlert.informativeText = "已导入 \(stats.profileCount) 个配置目录，\(stats.providerCount) 个供应商"
        successAlert.alertStyle = .informational
        successAlert.runModal()
    } catch let error as ImportExportService.VersionMismatchError {
        let errorAlert = NSAlert()
        errorAlert.messageText = "版本不兼容"
        errorAlert.informativeText = error.localizedDescription
        errorAlert.alertStyle = .critical
        errorAlert.runModal()
    } catch {
        let errorAlert = NSAlert()
        errorAlert.messageText = "导入失败"
        errorAlert.informativeText = error.localizedDescription
        errorAlert.alertStyle = .critical
        errorAlert.runModal()
    }
}
```

- [ ] **Step 2: 提交**

```bash
git add CCSwitch/Views/Settings/SettingsRootView.swift
git commit -m "feat: add export/import buttons to settings window

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 4: 验证构建

- [ ] **Step 1: 运行 swift build 验证编译**

```bash
swift build -c release 2>&1 | grep -v "^warning:"
```
预期：Build complete!

- [ ] **Step 2: 运行构建脚本验证 Universal Binary**

```bash
./build.sh 2>&1 | tail -20
```
预期：显示 DMG 和 App 大小，lipo 显示 arm64 + x86_64
