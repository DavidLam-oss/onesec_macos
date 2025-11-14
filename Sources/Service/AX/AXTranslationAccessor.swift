import Combine
import SwiftUI

class AXTranslationAccessor {
    private static var currentSelectedText: String = ""
    private static var isRecording: Bool = false
    private static var cancellable: AnyCancellable?
    private static var translationPanelID: UUID?

    static func setupMouseUpListener() {
        cancellable = ConnectionCenter.shared.$mouseContextState
            .receive(on: DispatchQueue.main)
            .sink { mouseState in
                guard isRecording, !currentSelectedText.isEmpty,
                      let mouseUpPoint = mouseState[.leftMouseUp]?.position
                else {
                    return
                }

                // 鼠标左键up事件发生，结束记录并显示ContentCard
                Task { @MainActor in
                    endTranslationRecording(mousePoint: mouseUpPoint)
                }
            }
    }

    static func scheduleTranslationUIView() {
        Task { @MainActor in
            let text = await ContextService.getSelectedText()
            let previousText = currentSelectedText

            if (text == nil ||
                text!.isEmpty ||
                text!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) &&
                translationPanelID != nil
            {
                OverlayController.shared.hideOverlay(uuid: translationPanelID!)
                translationPanelID = nil
            }

            // 检测从无/空到有的变化，标记记录开始
            if (previousText.isEmpty) && text != nil && !text!.isEmpty {
                // 开始记录
                currentSelectedText = text!
                isRecording = true

                // 确保监听器已设置
                if cancellable == nil {
                    setupMouseUpListener()
                }
                return
            }

            // 更新当前文本
            currentSelectedText = text ?? ""
        }
    }

    @MainActor
    private static func endTranslationRecording(mousePoint: NSPoint) {
        guard isRecording else { return }

        isRecording = false

        // 显示ContentCard
        OverlayController.shared.hideAllOverlays()
        translationPanelID = OverlayController.shared.showOverlayAbovePoint(point: mousePoint) { panelID in
            LazyTranslationCard(
                panelID: panelID,
                title: "识别结果",
                content: currentSelectedText,
                isCompactMode: true,
                expandDirection: .down
            )
        }

        // 清空记录
        currentSelectedText = ""
    }
}
