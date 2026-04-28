import AppKit
import SwiftUI

class SettingsWindowController: NSWindowController {
    private let appState: AppState

    convenience init(appState: AppState) {
        self.init(appState: appState, initialProfileId: nil)
    }

    init(appState: AppState, initialProfileId: UUID?) {
        self.appState = appState
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 480),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "CC Switch 设置"
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let hostingController = NSHostingController(
            rootView: SettingsRootView(initialProfileId: initialProfileId)
                .environmentObject(appState)
        )
        // 阻止 NSHostingController 把窗口压缩成 intrinsicContentSize
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        window.contentViewController = hostingController
        // 强制设置窗口大小（在 contentViewController 赋值后）
        window.setContentSize(NSSize(width: 720, height: 480))
        window.contentMinSize = NSSize(width: 500, height: 350)
        window.center()
        super.init(window: window)
        // 监听窗口关闭，通知 AppDelegate 释放引用，让下次重新创建并 center()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose),
            name: NSWindow.willCloseNotification,
            object: window
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    @objc private func windowWillClose() {
        // 通知 AppDelegate 清理引用
        NotificationCenter.default.post(name: .settingsWindowDidClose, object: self)
    }

    /// 重新定位到指定 Profile（窗口已打开时使用）
    func selectProfile(_ profileId: UUID) {
        let rootView = SettingsRootView(initialProfileId: profileId)
            .environmentObject(appState)
        window?.contentViewController = NSHostingController(rootView: rootView)
    }
}

extension Notification.Name {
    static let settingsWindowDidClose = Notification.Name("settingsWindowDidClose")
}
