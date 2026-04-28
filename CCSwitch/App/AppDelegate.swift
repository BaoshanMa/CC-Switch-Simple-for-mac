import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    private var settingsWindowController: SettingsWindowController?
    let appState = AppState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        log("applicationDidFinishLaunching START")
        setupMainMenu()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.title = "CC"
            button.action = #selector(togglePopover)
            button.target = self
            log("statusItem button configured, action=\(String(describing: button.action))")
        } else {
            log("ERROR: statusItem?.button is nil!")
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onSettingsWindowClosed),
            name: .settingsWindowDidClose,
            object: nil
        )
        log("applicationDidFinishLaunching END")
    }

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        // Edit menu (确保 Cmd+C/V/A 等标准快捷键在所有文本框可用)
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z"))
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        let editMenuItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        // Window menu (确保窗口级快捷键如 Cmd+W 有效)
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(NSMenuItem(title: "Minimize", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m"))
        windowMenu.addItem(NSMenuItem(title: "Close", action: #selector(NSWindow.close), keyEquivalent: "w"))
        let windowMenuItem = NSMenuItem(title: "Window", action: nil, keyEquivalent: "")
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)

        NSApp.mainMenu = mainMenu
    }

    @objc func togglePopover() {
        log("togglePopover called, popover.isShown=\(popover?.isShown ?? false)")
        if let popover, popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        log("showPopover called")
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 400)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PopoverRootView(onOpenSettings: { [weak self] profileId in
                self?.log("onOpenSettings callback fired, profileId=\(String(describing: profileId))")
                // 先关闭 popover，再异步打开设置窗口，避免 transient 关闭与窗口激活竞争
                self?.popover?.performClose(nil)
                DispatchQueue.main.async {
                    self?.log("DispatchQueue.main.async openSettings called")
                    self?.openSettings(focusProfileId: profileId)
                }
            }).environmentObject(appState)
        )
        if let button = statusItem?.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            log("popover shown")
        }
        self.popover = popover
    }

    func openSettings(focusProfileId: UUID? = nil) {
        log("openSettings called, existing controller visible=\(settingsWindowController?.window?.isVisible ?? false)")
        if let controller = settingsWindowController, controller.window?.isVisible == true {
            if let profileId = focusProfileId {
                controller.selectProfile(profileId)
            }
            controller.window?.makeKeyAndOrderFront(nil)
            log("reusing existing window, makeKeyAndOrderFront called")
        } else {
            settingsWindowController = SettingsWindowController(
                appState: appState,
                initialProfileId: focusProfileId
            )
            settingsWindowController?.showWindow(nil)
            log("new SettingsWindowController created and showWindow called")
        }
        // .accessory 策略的 app：orderFrontRegardless 强制前置，makeKey 确保成为 key window 接收键盘事件
        if let win = settingsWindowController?.window {
            win.orderFrontRegardless()
            win.makeKey()
        }
        log("orderFrontRegardless + makeKey done, window frame=\(String(describing: settingsWindowController?.window?.frame))")
    }

    private func log(_ msg: String) {
        let line = "[\(Date())] \(msg)\n"
        if let data = line.data(using: .utf8) {
            let url = URL(fileURLWithPath: "/tmp/ccswitch_debug.log")
            if let fh = try? FileHandle(forWritingTo: url) {
                fh.seekToEndOfFile()
                fh.write(data)
                fh.closeFile()
            } else {
                try? data.write(to: url)
            }
        }
    }

    @objc private func onSettingsWindowClosed() {
        settingsWindowController = nil
    }
}
