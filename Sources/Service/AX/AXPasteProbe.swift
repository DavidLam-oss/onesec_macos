import AppKit

class AXPasteProbe {
    private static var lazyPasteProbeHit = false
    private static var readCount = 0
    private static var timeMarker: Date?
    private static var pasteContent: String = ""

    static func runPasteProbe(_ content: String) {
        readCount = 0
        timeMarker = nil
        lazyPasteProbeHit = false
        pasteContent = content

        NSPasteboard.general.declareTypes([.string], owner: self)
        timeMarker = Date()
        AXPasteboardController.simulatePaste()

        DispatchQueue.global(qos: .userInitiated).async {
            let deadline = Date().addingTimeInterval(0.6)
            while !lazyPasteProbeHit, Date() < deadline {
                Thread.sleep(forTimeInterval: 0.01)
            }
            log.debug("🧪  \(lazyPasteProbeHit ? "可输入" : "不可输入")")
        }
    }
}

extension AXPasteProbe {
    @objc static func pasteboard(_ pasteboard: NSPasteboard, provideDataForType _: NSPasteboard.PasteboardType) {
        lazyPasteProbeHit = true
        readCount += 1

        if let startTime = timeMarker {
            let elapsed = Date().timeIntervalSince(startTime) * 1000
            if readCount == 1 {
                NSPasteboard.general.declareTypes([.string], owner: self)
                log.info("第一次simulatePaste到第一次被读的时间: \(String(format: "%.2f", elapsed))ms")
            } else if readCount == 2 {
                pasteboard.setString(pasteContent, forType: .string)
                log.info("第二次declareTypes到第二次被读取的时间: \(String(format: "%.2f", elapsed))ms")
            } else {
                log.info("剪切板被读取 \(readCount) 次, 间隔时间: \(String(format: "%.2f", elapsed))ms")
            }
            timeMarker = nil
        }

        timeMarker = Date()
    }
}
