// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CCSwitch",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "CCSwitch",
            path: "CCSwitch",
            sources: [
                "App/main.swift",
                "App/AppDelegate.swift",
                "Models/Profile.swift",
                "Models/Provider.swift",
                "Models/AppState.swift",
                "Services/StorageService.swift",
                "Services/SettingsFileService.swift",
                "Views/Popover/PopoverRootView.swift",
                "Views/Popover/ProfileListView.swift",
                "Views/Popover/ProviderListView.swift",
                "Views/Settings/SettingsWindowController.swift",
                "Views/Settings/SettingsRootView.swift",
                "Views/Settings/ProfileSidebarView.swift",
                "Views/Settings/ProviderListPanelView.swift",
                "Views/Settings/ProviderEditView.swift",
                "Views/Settings/TemplateEditView.swift",
            ],
            resources: [
                .copy("AppIcon.icns"),
            ],
            swiftSettings: []
        ),
    ]
)
