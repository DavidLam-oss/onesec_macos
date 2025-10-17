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
    static var COMMAND_KEY_CODES: [Int64] = [63, 49] // 默认 Fn+Space
    
}
