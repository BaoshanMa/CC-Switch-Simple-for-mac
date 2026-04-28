import AppKit

func writeLog(_ msg: String) {
    let line = "[\(Date())] MAIN: \(msg)\n"
    if let data = line.data(using: .utf8) {
        let url = URL(fileURLWithPath: "/tmp/ccswitch_debug.log")
        if let fh = try? FileHandle(forWritingTo: url) {
            fh.seekToEndOfFile(); fh.write(data); fh.closeFile()
        } else { try? data.write(to: url) }
    }
}

writeLog("main.swift started")
let app = NSApplication.shared
writeLog("NSApplication.shared obtained")
let delegate = AppDelegate()
writeLog("AppDelegate created")
app.delegate = delegate
writeLog("delegate assigned")
app.setActivationPolicy(.accessory)
writeLog("activation policy set, calling run()")
app.run()
writeLog("run() returned")
