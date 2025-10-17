//
//  Command.swift
//  OnesecCore
//
//  Created by 王晓雨 on 2025/10/14.
//

import ArgumentParser

struct CommandParser: ParsableCommand {
    @Option(name: .shortAndLong, help: "")
    var udsChannel: String = "/tmp/com.ripplestars.miaoyan.uds.test"

    @Option(name: .shortAndLong, help: "服务器主机地址")
    var server = "114.55.98.75:8000" // 114.55.98.75:8000 staging-api.miaoyan.cn

    @Option(name: .shortAndLong, help: "设置鉴权 Token")
    var authToken: String

    @Option(name: .shortAndLong, help: "设置 Debug 模式")
    var debugMode: Bool = true
    
    @Option(name: .shortAndLong, help: "普通模式按键组合 (如: Fn, Fn+Space)")
    var normalKeys: String = "Fn"
    
    @Option(name: .shortAndLong, help: "命令模式按键组合 (如: Fn+Space, Fn+Return)")
    var commandKeys: String = "Fn+Space"

    mutating func run() throws {
        Config.UDS_CHANNEL = udsChannel
        Config.SERVER = server
        Config.AUTH_TOKEN = authToken
        Config.DEBUG_MODE = debugMode
        
        // 解析普通模式按键
        if let normalKeyCodes = KeyMapper.parseKeyString(normalKeys) {
            Config.NORMAL_KEY_CODES = normalKeyCodes
        } else {
            throw ValidationError("无效的普通模式按键配置: \(normalKeys)")
        }
        
        // 解析命令模式按键
        if let commandKeyCodes = KeyMapper.parseKeyString(commandKeys) {
            Config.COMMAND_KEY_CODES = commandKeyCodes
        } else {
            throw ValidationError("无效的命令模式按键配置: \(commandKeys)")
        }
    }
}
