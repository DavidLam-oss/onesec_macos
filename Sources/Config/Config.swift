//
//  Config.swift
//  OnesecCore
//
//  Created by 王晓雨 on 2025/10/14.
//

// MARK: - 文本处理模式

enum TextProcessMode: String, CaseIterable {
    case auto = "AUTO"
    case raw = "RAW"
    case clean = "CLEAN"
    case format = "FORMAT"

    var displayName: String {
        switch self {
        case .auto:
            "自动风格"
        case .raw:
            "极速风格"
        case .clean:
            "清理风格"
        case .format:
            "整理风格"
        }
    }

    var description: String {
        switch self {
        case .auto:
            "智能判断，一键省心"
        case .raw:
            "快速识别，原样呈现"
        case .clean:
            "去噪理顺，轻度优化"
        case .format:
            "结构重组，深度优化"
        }
    }
}

actor Config {
    static var UDS_CHANNEL: String = ""
    static var SERVER: String = ""
    static var AUTH_TOKEN: String = ""
    static var DEBUG_MODE: Bool = true
    static var NORMAL_KEY_CODES: [Int64] = [63, 49] // 默认 Fn
    static var COMMAND_KEY_CODES: [Int64] = [63, 55] // 默认 Fn+LCmd
    static var TEXT_PROCESS_MODE: TextProcessMode = .auto // 默认自动模式

    static func saveHotkeySetting(mode: RecordMode, hotkeyCombination: [String]) {
        let keyCodes = hotkeyCombination.compactMap { KeyMapper.stringToKeyCodeMap[$0] }
        if mode == .normal {
            NORMAL_KEY_CODES = keyCodes
        } else if mode == .command {
            COMMAND_KEY_CODES = keyCodes
        }

        log.info("Hotkey updated for mode: \(mode), keyCodes: \(keyCodes)")
    }

    static func setTextProcessMode(_ mode: TextProcessMode) {
        TEXT_PROCESS_MODE = mode
        log.info("Text process mode updated to: \(mode.rawValue)")
    }
}
