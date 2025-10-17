//
//  Config.swift
//  OnesecCore
//
//  Created by 王晓雨 on 2025/10/14.
//

actor Config {
    static var UDS_CHANNEL: String = ""
    static var SERVER: String = ""
    static var AUTH_TOKEN: String = ""
    static var DEBUG_MODE: Bool = true
    static var NORMAL_KEY_CODES: [Int64] = [63] // 默认 Fn
    static var COMMAND_KEY_CODES: [Int64] = [63, 55] // 默认 Fn+LCmd

    static func saveHotkeySetting(mode: RecordMode, hotkeyCombination: [String]) {
        let keyCodes = hotkeyCombination.compactMap { KeyMapper.stringToKeyCodeMap[$0] }
        if mode == .normal {
            NORMAL_KEY_CODES = keyCodes
        } else if mode == .command {
            COMMAND_KEY_CODES = keyCodes
        }

        log.info("Hotkey updated for mode: \(mode), keyCodes: \(keyCodes)")
    }
}
