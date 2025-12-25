//
//  Command.swift
//  OnesecCore
//
//  Created by 王晓雨 on 2025/10/14.
//

import ArgumentParser

struct CommandParser: ParsableCommand {
    @Option(name: .shortAndLong, help: "UDS服务器地址")
    var udsChannel: String = "/tmp/com.ripplestars.miaoyan.uds.test"

    @Option(name: .shortAndLong, help: "服务器主机地址")
    var server = "114.55.98.75" // 114.55.98.75:8000 staging-api.miaoyan.cn 192.168.50.171:8000

    @Option(name: .shortAndLong, help: "设置鉴权 Token")
    var authToken: String = ""

    @Option(name: .shortAndLong, help: "普通模式按键组合 (如: Fn)")
    var normalKeys: String = ""

    @Option(name: .shortAndLong, help: "命令模式按键组合 (如: Fn+LCmd)")
    var commandKeys: String = ""

    @Option(name: .shortAndLong, help: "自由模式按键组合 (如: Fn+Space)")
    var freeKeys: String = ""

    mutating func run() throws {
        guard ServerValidator.isValid(server) else {
            throw ValidationError("Invalid Server: \(server)")
        }

        _ = Config.shared.USER_CONFIG

        Config.shared.UDS_CHANNEL = udsChannel
        Config.shared.SERVER = server

        if !authToken.isEmpty {
            Config.shared.USER_CONFIG.authToken = authToken
        }

        if !normalKeys.isEmpty {
            let normalKeyArray = normalKeys.split(separator: "+").map { String($0) }
            Config.shared.saveHotkeySetting(mode: .normal, hotkeyCombination: normalKeyArray)
        }

        if !commandKeys.isEmpty {
            let commandKeyArray = commandKeys.split(separator: "+").map { String($0) }
            Config.shared.saveHotkeySetting(mode: .command, hotkeyCombination: commandKeyArray)
        }

        if !freeKeys.isEmpty {
            let freeKeyArray = freeKeys.split(separator: "+").map { String($0) }
            Config.shared.saveHotkeySetting(mode: .free, hotkeyCombination: freeKeyArray)
        }
    }
}
