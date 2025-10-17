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

        guard ServerValidator.isValid(Config.SERVER) else {
            throw ValidationError("无效的服务器配置: \(server)")
        }

        // 验证并设置按键配置
        Config.NORMAL_KEY_CODES = try parseKeys(normalKeys, name: "普通模式按键")
        Config.COMMAND_KEY_CODES = try parseKeys(commandKeys, name: "命令模式按键")
    }

    private func parseKeys(_ keyString: String, name: String) throws -> [Int64] {
        guard let codes = KeyMapper.parseKeyString(keyString) else {
            throw ValidationError("无效的\(name)配置: \(keyString)")
        }
        return codes
    }
}
