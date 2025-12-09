import AppKit
import CoreAudio

@MainActor
final class MenuBuilder {
    static let shared = MenuBuilder()
    private var overlay: OverlayController { OverlayController.shared }
    private var audioDeviceManager: AudioDeviceManager = .shared

    @objc private func handleTranslateModeToggle() {
        if Config.shared.TEXT_PROCESS_MODE == .translate {
            Config.shared.TEXT_PROCESS_MODE = .auto
        } else {
            Config.shared.TEXT_PROCESS_MODE = .translate
        }
    }

    @objc private func handleAudioDeviceChange(_ sender: NSMenuItem) {
        audioDeviceManager.selectedDeviceID = AudioDeviceID(sender.tag)
    }

    func showMenu(in view: NSView) {
        let menu = NSMenu()

        // 音频设备选择
        let audioItem = NSMenuItem(title: "麦克风", action: nil, keyEquivalent: "")
        let audioSubmenu = NSMenu()

        audioDeviceManager.refreshDevices()
        let devices = audioDeviceManager.inputDevices

        for device in devices {
            let item = NSMenuItem(title: device.name, action: #selector(handleAudioDeviceChange(_:)), keyEquivalent: "")
            item.target = self
            item.tag = Int(device.id)
            item.state = device.isDefault ? .on : .off
            audioSubmenu.addItem(item)
        }

        audioItem.submenu = audioSubmenu
        menu.addItem(audioItem)
        menu.addItem(NSMenuItem.separator())

        let translateItem = NSMenuItem(title: "翻译模式", action: #selector(handleTranslateModeToggle), keyEquivalent: "")
        translateItem.target = self
        translateItem.state = Config.shared.TEXT_PROCESS_MODE == .translate ? .on : .off
        menu.addItem(translateItem)

        menu.update()
        let location = NSPoint(x: view.bounds.midX - menu.size.width / 2, y: 40)
        menu.popUp(positioning: nil, at: location, in: view)
    }
}
