# CC Switch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 构建 macOS 原生菜单栏工具，管理多套 Claude Code 配置目录和供应商，一键切换并写入 settings.json。

**Architecture:** 使用 SwiftUI + AppKit 构建，数据层用 Codable JSON 持久化到 App Support，核心逻辑（读写 settings.json）与 UI 完全分离，便于独立测试。菜单栏 NSStatusItem 内嵌 SwiftUI PopoverView，设置窗口为独立 NSWindow。

**Tech Stack:** Swift 5.9, SwiftUI, AppKit, XCTest（单元测试），Xcode 15+，macOS 13 Ventura+

---

## 文件结构

```
CCSwitch/
├── CCSwitch.xcodeproj
└── CCSwitch/
    ├── App/
    │   ├── CCswitchApp.swift          # @main 入口，NSApplicationDelegate
    │   └── AppDelegate.swift          # NSStatusItem 菜单栏管理
    ├── Models/
    │   ├── Profile.swift              # Profile 数据模型
    │   ├── Provider.swift             # Provider 数据模型 + EnvFields
    │   └── AppState.swift             # 全局状态（所有 Profile/Provider）
    ├── Services/
    │   ├── StorageService.swift       # 读写 ~/Library/Application Support/CCSwitch/config.json
    │   └── SettingsFileService.swift  # 读写 {configDir}/settings.json
    ├── Views/
    │   ├── Popover/
    │   │   ├── PopoverRootView.swift          # 菜单栏弹出面板根视图（NavigationStack）
    │   │   ├── ProfileListView.swift          # 一级：Profile 列表
    │   │   └── ProviderListView.swift         # 二级：Provider 列表（切换用）
    │   └── Settings/
    │       ├── SettingsWindowController.swift # NSWindowController 包装
    │       ├── SettingsRootView.swift         # 设置窗口根视图（左右分栏）
    │       ├── ProfileSidebarView.swift       # 左侧 Profile 列表
    │       ├── ProviderListPanelView.swift    # 右侧 Provider 卡片列表
    │       ├── ProviderEditView.swift         # 供应商编辑弹窗
    │       └── TemplateEditView.swift         # 配置模版 JSON 编辑弹窗
    └── Tests/
        ├── StorageServiceTests.swift
        └── SettingsFileServiceTests.swift
```

---

## Task 1: 创建 Xcode 项目骨架

**Files:**
- Create: `CCSwitch.xcodeproj`
- Create: `CCSwitch/App/CCswitchApp.swift`
- Create: `CCSwitch/App/AppDelegate.swift`

- [ ] **Step 1: 用 Xcode 创建新项目**

  File → New → Project → macOS → App
  - Product Name: `CCSwitch`
  - Bundle Identifier: `com.yourname.ccswitch`
  - Interface: SwiftUI
  - Language: Swift
  - 不勾选 Core Data / Tests（后续手动添加 Unit Test Target）
  - 保存到 `/Users/baoshanma/souceCode/home/mac-cc-switch/`

- [ ] **Step 2: 删除默认的 ContentView.swift**

  删除 Xcode 自动生成的 `ContentView.swift`

- [ ] **Step 3: 配置为菜单栏应用**

  编辑 `Info.plist`，添加：
  ```xml
  <key>LSUIElement</key>
  <true/>
  ```
  这样应用不出现在 Dock 和 App Switcher。

- [ ] **Step 4: 替换 CCswitchApp.swift**

  ```swift
  // CCSwitch/App/CCswitchApp.swift
  import SwiftUI

  @main
  struct CCswitchApp: App {
      @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

      var body: some Scene {
          Settings { EmptyView() }
      }
  }
  ```

- [ ] **Step 5: 创建 AppDelegate.swift 桩代码**

  ```swift
  // CCSwitch/App/AppDelegate.swift
  import AppKit

  class AppDelegate: NSObject, NSApplicationDelegate {
      var statusItem: NSStatusItem?

      func applicationDidFinishLaunching(_ notification: Notification) {
          statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
          statusItem?.button?.title = "CC"
      }
  }
  ```

- [ ] **Step 6: 构建确认无编译错误**

  Xcode → Product → Build（⌘B）
  预期：Build Succeeded，菜单栏出现 "CC" 文字图标

- [ ] **Step 7: 提交**

  ```bash
  git add CCSwitch/
  git commit -m "feat: scaffold xcode project with menubar LSUIElement"
  ```

---

## Task 2: 数据模型

**Files:**
- Create: `CCSwitch/Models/Profile.swift`
- Create: `CCSwitch/Models/Provider.swift`
- Create: `CCSwitch/Models/AppState.swift`

- [ ] **Step 1: 创建 Profile.swift**

  ```swift
  // CCSwitch/Models/Profile.swift
  import Foundation

  struct Profile: Identifiable, Codable, Equatable {
      var id: UUID = UUID()
      var name: String
      var configDir: URL
      var activeProviderId: UUID?
  }
  ```

- [ ] **Step 2: 创建 Provider.swift**

  ```swift
  // CCSwitch/Models/Provider.swift
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

      /// 转为写入 settings.json 的 [String: String] 字典
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
  ```

- [ ] **Step 3: 创建 AppState.swift**

  ```swift
  // CCSwitch/Models/AppState.swift
  import Foundation
  import Combine

  class AppState: ObservableObject {
      @Published var profiles: [Profile] = []
      @Published var providers: [Provider] = []

      func providers(for profileId: UUID) -> [Provider] {
          providers.filter { $0.profileId == profileId }
      }

      func activeProvider(for profile: Profile) -> Provider? {
          guard let id = profile.activeProviderId else { return nil }
          return providers.first { $0.id == id }
      }

      func profile(for provider: Provider) -> Profile? {
          profiles.first { $0.id == provider.profileId }
      }
  }
  ```

- [ ] **Step 4: 构建确认无编译错误**

  Xcode → ⌘B，预期：Build Succeeded

- [ ] **Step 5: 提交**

  ```bash
  git add CCSwitch/Models/
  git commit -m "feat: add Profile, Provider, AppState models"
  ```

---

## Task 3: StorageService（持久化）

**Files:**
- Create: `CCSwitch/Services/StorageService.swift`
- Create: `CCSwitchTests/StorageServiceTests.swift`

- [ ] **Step 1: 添加 Unit Test Target**

  Xcode → File → New → Target → Unit Testing Bundle
  - Product Name: `CCSwitchTests`
  - Target to be Tested: `CCSwitch`

- [ ] **Step 2: 写 StorageService 的失败测试**

  ```swift
  // CCSwitchTests/StorageServiceTests.swift
  import XCTest
  @testable import CCSwitch

  final class StorageServiceTests: XCTestCase {
      var tempDir: URL!
      var service: StorageService!

      override func setUp() {
          super.setUp()
          tempDir = FileManager.default.temporaryDirectory
              .appendingPathComponent(UUID().uuidString)
          try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
          service = StorageService(storageURL: tempDir.appendingPathComponent("config.json"))
      }

      override func tearDown() {
          try? FileManager.default.removeItem(at: tempDir)
          super.tearDown()
      }

      func test_saveAndLoad_roundtrip() throws {
          let profile = Profile(name: "公司", configDir: URL(fileURLWithPath: "/tmp/test"))
          let provider = Provider(
              profileId: profile.id,
              name: "MiniMax",
              env: EnvFields(anthropicBaseURL: "https://api.test.com")
          )
          try service.save(profiles: [profile], providers: [provider])
          let (loadedProfiles, loadedProviders) = try service.load()
          XCTAssertEqual(loadedProfiles, [profile])
          XCTAssertEqual(loadedProviders, [provider])
      }

      func test_load_returnsEmpty_whenFileNotExists() throws {
          let (profiles, providers) = try service.load()
          XCTAssertTrue(profiles.isEmpty)
          XCTAssertTrue(providers.isEmpty)
      }
  }
  ```

- [ ] **Step 3: 运行测试，确认失败**

  Xcode → ⌘U，预期：编译错误（StorageService 未定义）

- [ ] **Step 4: 实现 StorageService.swift**

  ```swift
  // CCSwitch/Services/StorageService.swift
  import Foundation

  class StorageService {
      private let storageURL: URL

      init(storageURL: URL = Self.defaultURL) {
          self.storageURL = storageURL
      }

      static var defaultURL: URL {
          let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
          let dir = appSupport.appendingPathComponent("CCSwitch")
          try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
          return dir.appendingPathComponent("config.json")
      }

      struct StorageData: Codable {
          var profiles: [Profile]
          var providers: [Provider]
      }

      func save(profiles: [Profile], providers: [Provider]) throws {
          let data = StorageData(profiles: profiles, providers: providers)
          let encoded = try JSONEncoder().encode(data)
          try encoded.write(to: storageURL, options: .atomic)
      }

      func load() throws -> ([Profile], [Provider]) {
          guard FileManager.default.fileExists(atPath: storageURL.path) else {
              return ([], [])
          }
          let data = try Data(contentsOf: storageURL)
          let decoded = try JSONDecoder().decode(StorageData.self, from: data)
          return (decoded.profiles, decoded.providers)
      }
  }
  ```

- [ ] **Step 5: 运行测试，确认通过**

  Xcode → ⌘U，预期：2 tests passed

- [ ] **Step 6: 提交**

  ```bash
  git add CCSwitch/Services/StorageService.swift CCSwitchTests/StorageServiceTests.swift
  git commit -m "feat: add StorageService with round-trip tests"
  ```

---

## Task 4: SettingsFileService（读写 settings.json）

**Files:**
- Create: `CCSwitch/Services/SettingsFileService.swift`
- Create: `CCSwitchTests/SettingsFileServiceTests.swift`

- [ ] **Step 1: 写失败测试**

  ```swift
  // CCSwitchTests/SettingsFileServiceTests.swift
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
          // 先写一个有 permissions 的 settings.json
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
          // permissions 和 theme 应保留
          XCTAssertNotNil(json["permissions"])
          XCTAssertEqual(json["theme"] as? String, "dark")
          // env 应被完整替换
          let envDict = json["env"] as! [String: String]
          XCTAssertNil(envDict["OLD_KEY"])
          XCTAssertEqual(envDict["ANTHROPIC_MODEL"], "NewModel")
      }

      func test_readTemplate_returnsEmptyDict_whenFileNotExists() throws {
          let result = try service.readTemplate(fromConfigDir: tempDir)
          XCTAssertTrue(result.isEmpty)
      }

      func test_saveTemplate_writesJsonAndPreservesActiveEnv() throws {
          // 准备：已有激活 provider
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
  ```

- [ ] **Step 2: 运行测试，确认失败**

  预期：编译错误（SettingsFileService 未定义）

- [ ] **Step 3: 实现 SettingsFileService.swift**

  ```swift
  // CCSwitch/Services/SettingsFileService.swift
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
      func saveTemplate(_ templateJson: [String: Any], configDir dir: URL, activeProvider: Provider?) throws {
          var json = templateJson
          json.removeValue(forKey: "env")
          if let provider = activeProvider {
              let envDict = provider.env.toDictionary()
              if !envDict.isEmpty { json["env"] = envDict }
          }
          let settingsURL = dir.appendingPathComponent("settings.json")
          let output = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
          try output.write(to: settingsURL, options: .atomic)
      }
  }
  ```

- [ ] **Step 4: 运行测试，确认通过**

  Xcode → ⌘U，预期：4 tests passed

- [ ] **Step 5: 提交**

  ```bash
  git add CCSwitch/Services/SettingsFileService.swift CCSwitchTests/SettingsFileServiceTests.swift
  git commit -m "feat: add SettingsFileService with env merge logic and tests"
  ```

---

## Task 5: AppState 集成 Services + 启动加载

**Files:**
- Modify: `CCSwitch/Models/AppState.swift`
- Modify: `CCSwitch/App/AppDelegate.swift`

- [ ] **Step 1: 升级 AppState，注入 Services**

  ```swift
  // CCSwitch/Models/AppState.swift
  import Foundation
  import Combine

  class AppState: ObservableObject {
      @Published var profiles: [Profile] = []
      @Published var providers: [Provider] = []

      private let storage: StorageService
      private let settingsFile: SettingsFileService

      init(storage: StorageService = StorageService(),
           settingsFile: SettingsFileService = SettingsFileService()) {
          self.storage = storage
          self.settingsFile = settingsFile
          load()
      }

      // MARK: - 查询

      func providers(for profileId: UUID) -> [Provider] {
          providers.filter { $0.profileId == profileId }
      }

      func activeProvider(for profile: Profile) -> Provider? {
          guard let id = profile.activeProviderId else { return nil }
          return providers.first { $0.id == id }
      }

      // MARK: - 持久化

      func load() {
          guard let (p, v) = try? storage.load() else { return }
          profiles = p
          providers = v
      }

      private func persist() {
          try? storage.save(profiles: profiles, providers: providers)
      }

      // MARK: - Profile CRUD

      func addProfile(_ profile: Profile) {
          profiles.append(profile)
          persist()
      }

      func updateProfile(_ profile: Profile) {
          guard let idx = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
          profiles[idx] = profile
          persist()
      }

      func deleteProfile(_ profile: Profile) {
          providers.removeAll { $0.profileId == profile.id }
          profiles.removeAll { $0.id == profile.id }
          persist()
      }

      func cloneProfile(_ profile: Profile, newName: String, newConfigDir: URL) {
          var newProfile = profile
          newProfile.id = UUID()
          newProfile.name = newName
          newProfile.configDir = newConfigDir
          newProfile.activeProviderId = nil
          let clonedProviders = providers(for: profile.id).map { p -> Provider in
              var np = p
              np.id = UUID()
              np.profileId = newProfile.id
              return np
          }
          profiles.append(newProfile)
          providers.append(contentsOf: clonedProviders)
          persist()
      }

      // MARK: - Provider CRUD

      func addProvider(_ provider: Provider) {
          providers.append(provider)
          persist()
      }

      func updateProvider(_ provider: Provider) {
          guard let idx = providers.firstIndex(where: { $0.id == provider.id }) else { return }
          providers[idx] = provider
          // 若该 provider 为激活状态，重新写入 settings.json
          if let profile = profiles.first(where: { $0.activeProviderId == provider.id }) {
              try? settingsFile.applyProvider(provider, toConfigDir: profile.configDir)
          }
          persist()
      }

      func deleteProvider(_ provider: Provider) {
          // 若正在使用，清除激活状态
          if let idx = profiles.firstIndex(where: { $0.activeProviderId == provider.id }) {
              profiles[idx].activeProviderId = nil
          }
          providers.removeAll { $0.id == provider.id }
          persist()
      }

      func cloneProvider(_ provider: Provider) -> Provider {
          var np = provider
          np.id = UUID()
          np.name = provider.name + " 副本"
          providers.append(np)
          persist()
          return np
      }

      // MARK: - 切换供应商

      func activateProvider(_ provider: Provider) throws {
          guard let profileIdx = profiles.firstIndex(where: { $0.id == provider.profileId }) else { return }
          try settingsFile.applyProvider(provider, toConfigDir: profiles[profileIdx].configDir)
          profiles[profileIdx].activeProviderId = provider.id
          persist()
      }
  }
  ```

- [ ] **Step 2: 在 AppDelegate 中初始化 AppState**

  ```swift
  // CCSwitch/App/AppDelegate.swift
  import AppKit
  import SwiftUI

  class AppDelegate: NSObject, NSApplicationDelegate {
      var statusItem: NSStatusItem?
      var popover: NSPopover?
      let appState = AppState()

      func applicationDidFinishLaunching(_ notification: Notification) {
          statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
          if let button = statusItem?.button {
              button.title = "CC"
              button.action = #selector(togglePopover)
              button.target = self
          }
      }

      @objc func togglePopover() {
          if let popover, popover.isShown {
              popover.performClose(nil)
          } else {
              showPopover()
          }
      }

      private func showPopover() {
          let popover = NSPopover()
          popover.contentSize = NSSize(width: 300, height: 400)
          popover.behavior = .transient
          popover.contentViewController = NSHostingController(
              rootView: PopoverRootView().environmentObject(appState)
          )
          if let button = statusItem?.button {
              popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
          }
          self.popover = popover
      }
  }
  ```

- [ ] **Step 3: 创建 PopoverRootView 桩代码（避免编译错误）**

  ```swift
  // CCSwitch/Views/Popover/PopoverRootView.swift
  import SwiftUI

  struct PopoverRootView: View {
      @EnvironmentObject var appState: AppState
      var body: some View {
          Text("CC Switch")
              .padding()
      }
  }
  ```

- [ ] **Step 4: 构建确认无错误**

  Xcode → ⌘B，预期：Build Succeeded，点击菜单栏 "CC" 弹出面板

- [ ] **Step 5: 提交**

  ```bash
  git add CCSwitch/
  git commit -m "feat: integrate AppState with services, wire up popover"
  ```

---

## Task 6: 菜单栏弹出面板 UI

**Files:**
- Modify: `CCSwitch/Views/Popover/PopoverRootView.swift`
- Create: `CCSwitch/Views/Popover/ProfileListView.swift`
- Create: `CCSwitch/Views/Popover/ProviderListView.swift`

- [ ] **Step 1: 实现 ProfileListView（一级）**

  ```swift
  // CCSwitch/Views/Popover/ProfileListView.swift
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
  ```

- [ ] **Step 2: 实现 ProviderListView（二级）**

  ```swift
  // CCSwitch/Views/Popover/ProviderListView.swift
  import SwiftUI

  struct ProviderListView: View {
      @EnvironmentObject var appState: AppState
      let profile: Profile
      let onOpenSettings: () -> Void

      var providers: [Provider] { appState.providers(for: profile.id) }

      var body: some View {
          VStack(spacing: 0) {
              HStack {
                  Text(profile.name + " / 供应商")
                      .font(.caption)
                      .foregroundColor(.secondary)
              }
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
                  Button("管理供应商...") { onOpenSettings() }
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

      var isActive: Bool {
          appState.profiles.first(where: { $0.id == profileId })?.activeProviderId == provider.id
      }

      var body: some View {
          Button {
              try? appState.activateProvider(provider)
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
      }
  }
  ```

- [ ] **Step 3: 实现 PopoverRootView（NavigationStack 两级）**

  ```swift
  // CCSwitch/Views/Popover/PopoverRootView.swift
  import SwiftUI

  struct PopoverRootView: View {
      @EnvironmentObject var appState: AppState
      @State private var navigationPath = NavigationPath()
      let onOpenSettings: (() -> Void)?

      init(onOpenSettings: (() -> Void)? = nil) {
          self.onOpenSettings = onOpenSettings
      }

      var body: some View {
          NavigationStack(path: $navigationPath) {
              ProfileListView(onOpenSettings: onOpenSettings ?? {})
                  .navigationDestination(for: Profile.self) { profile in
                      ProviderListView(profile: profile, onOpenSettings: onOpenSettings ?? {})
                  }
          }
          .frame(width: 300)
      }
  }
  ```

- [ ] **Step 4: 在 AppDelegate 传入 onOpenSettings 回调（桩）**

  修改 `AppDelegate.showPopover()` 中的 `PopoverRootView()` 构造：
  ```swift
  rootView: PopoverRootView(onOpenSettings: { [weak self] in
      self?.openSettings()
  }).environmentObject(appState)
  ```
  并添加桩方法：
  ```swift
  func openSettings() {
      // Task 7 实现
  }
  ```

- [ ] **Step 5: 构建并手动测试菜单栏弹出面板**

  - 点击菜单栏 "CC" → 弹出面板显示（空列表）
  - 面板底部有「管理目录...」和「退出」

- [ ] **Step 6: 提交**

  ```bash
  git add CCSwitch/Views/Popover/
  git commit -m "feat: implement menubar popover with two-level navigation"
  ```

---

## Task 7: 设置窗口框架 + Profile 侧边栏

**Files:**
- Create: `CCSwitch/Views/Settings/SettingsWindowController.swift`
- Create: `CCSwitch/Views/Settings/SettingsRootView.swift`
- Create: `CCSwitch/Views/Settings/ProfileSidebarView.swift`
- Create: `CCSwitch/Views/Settings/ProviderListPanelView.swift`（桩）
- Modify: `CCSwitch/App/AppDelegate.swift`

- [ ] **Step 1: 创建 SettingsWindowController**

  ```swift
  // CCSwitch/Views/Settings/SettingsWindowController.swift
  import AppKit
  import SwiftUI

  class SettingsWindowController: NSWindowController {
      convenience init(appState: AppState) {
          let window = NSWindow(
              contentRect: NSRect(x: 0, y: 0, width: 720, height: 480),
              styleMask: [.titled, .closable, .resizable, .miniaturizable],
              backing: .buffered,
              defer: false
          )
          window.title = "CC Switch 设置"
          window.center()
          window.contentViewController = NSHostingController(
              rootView: SettingsRootView().environmentObject(appState)
          )
          self.init(window: window)
      }
  }
  ```

- [ ] **Step 2: 创建 SettingsRootView（左右分栏）**

  ```swift
  // CCSwitch/Views/Settings/SettingsRootView.swift
  import SwiftUI

  struct SettingsRootView: View {
      @EnvironmentObject var appState: AppState
      @State private var selectedProfileId: UUID?

      var selectedProfile: Profile? {
          appState.profiles.first { $0.id == selectedProfileId }
      }

      var body: some View {
          HSplitView {
              ProfileSidebarView(selectedProfileId: $selectedProfileId)
                  .frame(minWidth: 200, maxWidth: 220)
              if let profile = selectedProfile {
                  ProviderListPanelView(profile: profile)
              } else {
                  Text("请选择一个配置目录")
                      .foregroundColor(.secondary)
                      .frame(maxWidth: .infinity, maxHeight: .infinity)
              }
          }
          .onAppear {
              if selectedProfileId == nil {
                  selectedProfileId = appState.profiles.first?.id
              }
          }
      }
  }
  ```

- [ ] **Step 3: 创建 ProfileSidebarView**

  ```swift
  // CCSwitch/Views/Settings/ProfileSidebarView.swift
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
          VStack(alignment: .leading, spacing: 2) {
              Text(profile.name).font(.system(size: 13))
              Text(profile.configDir.abbreviatingWithTildeInPath)
                  .font(.caption2)
                  .foregroundColor(.secondary)
          }
          .contextMenu {
              Button("克隆", action: onClone)
              Button("删除", role: .destructive, action: onDelete)
          }
          .overlay(alignment: .trailing) {
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
      }
  }
  ```

- [ ] **Step 4: 创建 AddProfileSheet 和 CloneProfileSheet**

  ```swift
  // 追加到 ProfileSidebarView.swift 末尾

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
  ```

- [ ] **Step 5: 创建 ProviderListPanelView 桩**

  ```swift
  // CCSwitch/Views/Settings/ProviderListPanelView.swift
  import SwiftUI

  struct ProviderListPanelView: View {
      @EnvironmentObject var appState: AppState
      let profile: Profile

      var body: some View {
          Text("供应商列表 - \(profile.name)")
              .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
  }
  ```

- [ ] **Step 6: 在 AppDelegate 实现 openSettings()**

  ```swift
  // AppDelegate.swift 中添加
  private var settingsWindowController: SettingsWindowController?

  func openSettings() {
      if settingsWindowController == nil {
          settingsWindowController = SettingsWindowController(appState: appState)
      }
      settingsWindowController?.showWindow(nil)
      NSApp.activate(ignoringOtherApps: true)
  }
  ```

- [ ] **Step 7: 构建并手动测试**

  - 点击菜单栏「管理目录...」→ 设置窗口打开
  - 左侧侧边栏可显示（空）Profile 列表
  - 点击「+ 添加目录」→ Sheet 弹出，可选择目录

- [ ] **Step 8: 提交**

  ```bash
  git add CCSwitch/Views/Settings/
  git commit -m "feat: add settings window with profile sidebar and add/clone/delete"
  ```

---

## Task 8: Provider 卡片列表 + 编辑弹窗

**Files:**
- Modify: `CCSwitch/Views/Settings/ProviderListPanelView.swift`
- Create: `CCSwitch/Views/Settings/ProviderEditView.swift`

- [ ] **Step 1: 实现完整 ProviderListPanelView**

  ```swift
  // CCSwitch/Views/Settings/ProviderListPanelView.swift
  import SwiftUI

  struct ProviderListPanelView: View {
      @EnvironmentObject var appState: AppState
      let profile: Profile
      @State private var showAddProvider = false
      @State private var editTarget: Provider?
      @State private var showTemplateEditor = false

      var providers: [Provider] { appState.providers(for: profile.id) }

      var body: some View {
          VStack(spacing: 0) {
              // 顶部操作栏
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

              // Provider 卡片列表
              ScrollView {
                  VStack(spacing: 8) {
                      ForEach(providers) { provider in
                          ProviderCardView(
                              provider: provider,
                              profile: profile,
                              onEdit: { editTarget = provider },
                              onClone: {
                                  // 克隆后立即打开编辑弹窗（spec 第六章要求）
                                  let cloned = appState.cloneProvider(provider)
                                  editTarget = cloned
                              },
                              onDelete: { appState.deleteProvider(provider) }
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
                  appState.updateProvider(updated)
              }
          }
          .sheet(isPresented: $showTemplateEditor) {
              TemplateEditView(profile: profile)
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

      var isActive: Bool { profile.activeProviderId == provider.id }

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
                  Button("编辑") { onEdit() }
                      .buttonStyle(.plain)
                      .font(.system(size: 12))
                  Button("删除") { onDelete() }
                      .buttonStyle(.plain)
                      .font(.system(size: 12))
                      .foregroundColor(.secondary)
              }
              // 摘要字段
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
  ```

- [ ] **Step 2: 实现 ProviderEditView（供应商编辑弹窗）**

  ```swift
  // CCSwitch/Views/Settings/ProviderEditView.swift
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
                      // Token 特殊处理（脱敏）
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
  ```

- [ ] **Step 3: 创建 TemplateEditView 桩（Task 9 完整实现）**

  ```swift
  // CCSwitch/Views/Settings/TemplateEditView.swift
  import SwiftUI

  struct TemplateEditView: View {
      @Environment(\.dismiss) var dismiss
      let profile: Profile

      var body: some View {
          VStack {
              Text("配置模版 — \(profile.name)")
                  .font(.headline)
              Text("（Task 9 实现）")
                  .foregroundColor(.secondary)
              Button("关闭") { dismiss() }
          }
          .padding(20)
          .frame(width: 480, height: 300)
      }
  }
  ```

- [ ] **Step 4: 构建并手动测试**

  - 设置窗口右侧可显示 Provider 卡片列表
  - 点击「+ 添加供应商」→ 编辑弹窗打开，填写内容后保存
  - 保存后卡片出现在列表
  - 点击「克隆」→ 新增「xxx 副本」卡片
  - 点击「删除」→ 卡片消失

- [ ] **Step 5: 提交**

  ```bash
  git add CCSwitch/Views/Settings/
  git commit -m "feat: add provider card list and edit sheet"
  ```

---

## Task 9: 配置模版编辑弹窗

**Files:**
- Modify: `CCSwitch/Views/Settings/TemplateEditView.swift`

- [ ] **Step 1: 实现完整 TemplateEditView**

  ```swift
  // CCSwitch/Views/Settings/TemplateEditView.swift
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

              // 提示横幅
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

              // JSON 文本编辑器
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
             let data = try? JSONSerialization.data(withJSONObject: template, options: [.prettyPrinted, .sortedKeys]),
             let str = String(data: data, encoding: .utf8) {
              jsonText = str.isEmpty ? "{}" : str
          } else {
              jsonText = "{}"
          }
      }

      private func saveTemplate() {
          errorMessage = nil
          guard let data = jsonText.data(using: .utf8),
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
              errorMessage = "JSON 格式错误，请检查后重试"
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
  ```

- [ ] **Step 2: 构建并手动测试**

  - 设置窗口点击「📄 配置模版」→ 弹窗打开
  - 显示当前 settings.json 内容（去掉 env）
  - 修改内容后保存 → 文件写入成功
  - 输入非法 JSON → 出现错误提示

- [ ] **Step 3: 提交**

  ```bash
  git add CCSwitch/Views/Settings/TemplateEditView.swift
  git commit -m "feat: implement template editor with JSON validation"
  ```

---

## Task 10: 错误处理 + 目录不存在提示

**Files:**
- Modify: `CCSwitch/Models/AppState.swift`
- Modify: `CCSwitch/Views/Popover/ProviderListView.swift`

- [ ] **Step 1: 在 AppState.activateProvider 增加错误传播**

  `activateProvider` 已声明 `throws`，调用方需处理。

  在 `ProviderRowView` 的 Button action 中捕获错误：

  ```swift
  // ProviderListView.swift 中 ProviderRowView
  @State private var alertMessage: String?
  @State private var showAlert = false

  Button {
      do {
          try appState.activateProvider(provider)
      } catch {
          alertMessage = error.localizedDescription
          showAlert = true
      }
  } label: { ... }
  .alert("切换失败", isPresented: $showAlert) {
      Button("确定", role: .cancel) {}
  } message: {
      Text(alertMessage ?? "未知错误")
  }
  ```

- [ ] **Step 2: 切换时目录不存在 → 提示用户确认创建**

  在 `AppState.activateProvider` 中，写入前检查目录是否存在，若不存在弹出确认框：

  ```swift
  // AppState.activateProvider 修改版
  func activateProvider(_ provider: Provider) throws {
      guard let profileIdx = profiles.firstIndex(where: { $0.id == provider.profileId }) else { return }
      let dir = profiles[profileIdx].configDir
      if !FileManager.default.fileExists(atPath: dir.path) {
          // 通过 pendingActivation 通知 UI 显示确认弹窗（见下方 UI 处理）
          throw ActivationError.directoryNotFound(dir)
      }
      try settingsFile.applyProvider(provider, toConfigDir: dir)
      profiles[profileIdx].activeProviderId = provider.id
      persist()
  }

  enum ActivationError: LocalizedError {
      case directoryNotFound(URL)
      var errorDescription: String? {
          switch self {
          case .directoryNotFound(let url):
              return "目录不存在：\(url.abbreviatingWithTildeInPath)"
          }
      }
  }
  ```

  在 `ProviderRowView` 的 catch 块中区分错误类型，目录不存在时展示「创建目录并继续」选项：

  ```swift
  Button {
      do {
          try appState.activateProvider(provider)
      } catch AppState.ActivationError.directoryNotFound(let url) {
          // 目录不存在：提示用户并提供「创建目录」选项
          alertMessage = "配置目录不存在：\(url.path)\n是否创建该目录？"
          pendingProviderForDirCreation = provider
          showCreateDirAlert = true
      } catch {
          alertMessage = error.localizedDescription
          showAlert = true
      }
  } label: { ... }
  .alert("目录不存在", isPresented: $showCreateDirAlert) {
      Button("创建目录") {
          if let p = pendingProviderForDirCreation,
             let profile = appState.profiles.first(where: { $0.id == p.profileId }) {
              try? FileManager.default.createDirectory(at: profile.configDir, withIntermediateDirectories: true)
              try? appState.activateProvider(p)
          }
      }
      Button("取消", role: .cancel) {}
  } message: {
      Text(alertMessage ?? "")
  }
  ```

- [ ] **Step 3: 构建并测试错误场景**

  - 创建一个 configDir 不存在的 Profile，切换供应商 → 弹出"目录不存在"确认框
  - 点击「创建目录」→ 目录被创建，settings.json 写入成功，Provider 切换为激活状态
  - 点击「取消」→ 激活状态不变

- [ ] **Step 4: 提交**

  ```bash
  git add CCSwitch/
  git commit -m "feat: handle errors on activate, prompt user to create missing configDir"
  ```

---

## Task 11: 打包发布准备

**Files:**
- Modify: `CCSwitch.xcodeproj`（Signing & Capabilities）
- Create: `.github/workflows/release.yml`（可选）

- [ ] **Step 1: 配置 Signing**

  Xcode → 项目 → Signing & Capabilities：
  - Automatically manage signing: 勾选
  - Team: 选择 Apple Developer 账号（或 Personal Team 用于本地）

- [ ] **Step 2: 配置 Hardened Runtime（公证必需）**

  Xcode → 项目 → Signing & Capabilities → + Capability → Hardened Runtime

- [ ] **Step 3: Archive 并导出**

  Xcode → Product → Archive → Distribute App → Direct Distribution → Export

- [ ] **Step 4: 创建 DMG（可选脚本）**

  ```bash
  # 安装 create-dmg
  brew install create-dmg
  create-dmg \
    --volname "CC Switch" \
    --window-size 540 380 \
    --icon-size 128 \
    --icon "CCSwitch.app" 150 190 \
    --app-drop-link 390 190 \
    "CCSwitch-1.0.0.dmg" \
    "export/CCSwitch.app"
  ```

- [ ] **Step 5: 提交 .gitignore 更新**

  ```bash
  # 追加到 .gitignore
  echo "*.xcuserstate" >> .gitignore
  echo "CCSwitch.xcodeproj/xcuserdata/" >> .gitignore
  echo "DerivedData/" >> .gitignore
  git add .gitignore
  git commit -m "chore: update gitignore for xcode artifacts"
  ```

---

## 完成标准

- [ ] 菜单栏图标常驻，点击弹出两级面板
- [ ] 可添加/克隆/删除 Profile（配置目录）
- [ ] 每个 Profile 下可添加/克隆/编辑/删除 Provider（供应商配置）
- [ ] 点击 Provider 一键切换，正确写入 settings.json 的 env 字段
- [ ] 配置模版编辑器可编辑 settings.json 非 env 内容，保存后合并 env
- [ ] Token 在 UI 中脱敏展示
- [ ] 所有数据持久化到 App Support，重启后保留
- [ ] 单元测试：StorageService 和 SettingsFileService 全部通过
