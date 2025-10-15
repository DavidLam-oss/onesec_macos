import Foundation

CommandParser.main()

SignalHandler.shared.setupSignalHandlers()
PermissionManager.shared.checkAllPermissions { results in
    log.info("Check permission: \(results)")
}

log.info(ConnectionCenter.shared)

// 保持对 VoiceInputController 的强引用，防止对象被释放
let voiceInputController = VoiceInputController()

RunLoop.main.run()
