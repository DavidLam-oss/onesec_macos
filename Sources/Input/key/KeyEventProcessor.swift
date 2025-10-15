//
//  KeyEventProcessor.swift
//  OnesecCore
//
//  Created by 王晓雨 on 2025/10/15.
//

import Carbon
import Cocoa
import Foundation

enum RecognitionMode: String, CaseIterable {
    case normal
    case command

    var description: String {
        switch self {
        case .normal:
            return "普通识别模式"
        case .command:
            return "命令识别模式"
        }
    }
}

enum KeyEventResult {
    case startRecording // 开始录音
    case stopRecording // 停止录音
    case modeUpgrade // 模式升级
    case continueRecording // 继续录音
    case noAction // 无操作，完全无关的按键
}

struct KeyConfig {
    let keyCodes: [Int64] // 按键组合的键码数组
    let description: String // 配置描述
    let mode: RecognitionMode // 识别模式

    init(keyCodes: [Int64], description: String, mode: RecognitionMode) {
        self.keyCodes = keyCodes.sorted()
        self.description = description
        self.mode = mode
    }

    /// 检查是否匹配指定的按键组合
    func matches(_ pressedKeys: [Int64]) -> Bool {
        let sortedPressedKeys = Set(pressedKeys.sorted())
        let sortedConfigKeys = Set(keyCodes.sorted())
        return sortedPressedKeys == sortedConfigKeys
    }
}

struct DualModeKeyConfig {
    let normalModeConfig: KeyConfig
    let commandModeConfig: KeyConfig

    init(normalKeyCodes: [Int64], commandKeyCodes: [Int64]) {
        let normalDescription = normalKeyCodes
            .compactMap { KeyMapper.keyCodeMap[$0] }
            .joined(separator: "+")

        let commandDescription = commandKeyCodes
            .compactMap { KeyMapper.keyCodeMap[$0] }
            .joined(separator: "+")

        self.normalModeConfig = KeyConfig(
            keyCodes: normalKeyCodes,
            description: "普通模式 \(normalDescription)",
            mode: .normal
        )
        self.commandModeConfig = KeyConfig(
            keyCodes: commandKeyCodes,
            description: "命令模式 \(commandDescription)",
            mode: .command
        )
    }

    /// 根据按键组合获取对应的配置
    func getConfig(for pressedKeys: [Int64]) -> KeyConfig? {
        // 优先检查命令模式
        if commandModeConfig.matches(pressedKeys) {
            return commandModeConfig
        } else if normalModeConfig.matches(pressedKeys) {
            return normalModeConfig
        }
        return nil
    }

    /// 检查是否匹配任何配置的按键组合
    func matchesAny(_ pressedKeys: [Int64]) -> Bool {
        return getConfig(for: pressedKeys) != nil
    }
}

class KeyEventProcessor {
    var dualModeConfig: DualModeKeyConfig
    var isHotkeySetting = false
    var hotkeySettingMode: String?

    private var keyStateTracker: KeyStateTracker = .init()

    init(normalKeyCodes: [Int64], commandKeyCodes: [Int64]) {
        self.dualModeConfig = DualModeKeyConfig(
            normalKeyCodes: normalKeyCodes,
            commandKeyCodes: commandKeyCodes
        )
        log.debug("initialized")
        log.debug("普通模式: \(dualModeConfig.normalModeConfig.description)")
        log.debug("命令模式: \(dualModeConfig.commandModeConfig.description)")
    }

    func startHotkeySetting(mode: String) {
        log.info("Hotkey setting start: \(mode)")

        keyStateTracker.clear()

        isHotkeySetting = true
        hotkeySettingMode = mode
    }

    func endHotkeySetting() {
        guard isHotkeySetting else { return }

        log.info("Hotkey setting done")

        isHotkeySetting = false
        hotkeySettingMode = nil
    }

    func handleHotkeySettingEvent(type: CGEventType, event: CGEvent) -> Bool {
        guard isHotkeySetting else { return false }

        return keyStateTracker.handleKeyEvent(type: type, event: event) != nil
    }

    func handlekeyEvent(type: CGEventType, event: CGEvent) -> KeyEventResult {
        return .noAction
    }
}
