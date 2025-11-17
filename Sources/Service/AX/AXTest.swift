import Cocoa

class AXTest {
    static let shared = AXTest()
    private static var lazyPasteProbeHit = false

    @objc static func pasteboard(_: NSPasteboard, provideDataForType type: NSPasteboard.PasteboardType) {
        lazyPasteProbeHit = true
        log.info("Lazy Paste Probe Hit")
    }

    static func runLazyPasteboardProbe() {
        let pb = NSPasteboard.general
        lazyPasteProbeHit = false

        pb.declareTypes([.string], owner: self)
        AXPasteboardController.simulatePaste()
        let deadline = Date().addingTimeInterval(0.3) // 最长等待约 300 ms，可按需调整
        while !lazyPasteProbeHit, Date() < deadline {
            // 跑一下当前 runloop，处理默认模式下的事件（包括 pasteboard 回调）
            CFRunLoopRunInMode(.defaultMode, 0.01, false) // 每次运行 10 ms
        }

        // 根据 pasteboard:provideDataForType: 是否被触发来做判定
        if lazyPasteProbeHit {
            print("🧪 LazyPaste 探针：检测到目标应用请求粘贴数据，推断当前在可输入环境")
        } else {
            print("🧪 LazyPaste 探针：未检测到粘贴数据请求，推断当前不在可输入环境")
        }
    }
}
