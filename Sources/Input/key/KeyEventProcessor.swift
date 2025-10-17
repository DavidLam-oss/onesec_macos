//
//  KeyEventProcessor.swift
//  OnesecCore
//
//  Created by 王晓雨 on 2025/10/15.
//

import Carbon
import Cocoa
import Foundation

enum RecordMode: String, CaseIterable {
    case normal
    case command

    var description: String {
        switch self {
        case .normal:
            "普通模式"
        case .command:
            "命令模式"
        }
    }
}

struct KeyConfig {
    let keyCodes: [Int64] // 按键组合的键码数组
    let description: String // 配置描述
    let mode: RecordMode // 识别模式

    init(keyCodes: [Int64], description: String, mode: RecordMode) {
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
            mode: .normal,
        )
        self.commandModeConfig = KeyConfig(
            keyCodes: commandKeyCodes,
            description: "命令模式 \(commandDescription)",
            mode: .command,
        )
    }
}

class KeyEventProcessor {
    var dualModeConfig: DualModeKeyConfig
    var isHotkeySetting = false
    var hotkeySettingMode: String?

    private var keyStateTracker: KeyStateTracker = .init()

    init() {
        self.dualModeConfig = DualModeKeyConfig(
            normalKeyCodes: Config.NORMAL_KEY_CODES,
            commandKeyCodes: Config.COMMAND_KEY_CODES,
        )

        log.debug("initialized")
        log.debug("普通模式: \(dualModeConfig.normalModeConfig.description)")
        log.debug("命令模式: \(dualModeConfig.commandModeConfig.description)")
    }

    func startHotkeySetting(mode: String) {
        log.info("Hotkey setting start: \(mode)")

        keyStateTracker.clear() // 自动重置匹配状态

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

    func handlekeyEvent(type: CGEventType, event: CGEvent) -> KeyMatchResult {
        // 直接返回 KeyStateTracker 的匹配结果
        return keyStateTracker.handleKeyEventWithMatch(type: type, event: event)
    }
}
