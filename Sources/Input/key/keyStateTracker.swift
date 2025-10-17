//
//  keyStateTracker.swift
//  OnesecCore
//
//  Created by 王晓雨 on 2025/10/15.
//

import CoreGraphics
import Foundation

enum KeyMatchResult {
    case startMatch(RecordMode) // 从不匹配变为匹配
    case endMatch // 从匹配变为不匹配
    case stillMatching // 持续匹配
    case notMatching // 持续不匹配
    case modeUpgrade(from: RecordMode, to: RecordMode) // 模式转换
}

/// 追踪按键状态
/// 用于快捷键设置与按键监测
class KeyStateTracker {
    private var pressedKeys: Set<Int64> = []
    private var currentModifiers: CGEventFlags = []
    private let modifierMasks: [CGEventFlags] = [.maskCommand, .maskAlternate, .maskControl, .maskShift, .maskSecondaryFn]

    /// 追踪当前是否处于匹配状态
    private var isCurrentlyMatched: Bool = false
    
    /// 追踪当前激活的模式
    private var currentActiveMode: RecordMode?
    
    private var keyConfigs: [KeyConfig] = [
        KeyConfig(keyCodes: Config.NORMAL_KEY_CODES, description: "normal", mode: .normal),
        KeyConfig(keyCodes: Config.COMMAND_KEY_CODES, description: "command", mode: .command)
    ]
    
    /// 处理键盘事件（用于快捷键设置模式）
    /// - Returns: 当松开键时返回完整的快捷键组合，否则返回空
    func handleKeyEvent(type: CGEventType, event: CGEvent) -> [Int64]? {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        
        switch type {
        case .flagsChanged:
            return handleModifierChange(keyCode: keyCode, newModifiers: event.flags)
            
        case .keyDown:
            addKey(keyCode)
            
        case .keyUp:
            // 松开普通键时，如果有修饰键被按下，则完成快捷键设置
            removeKey(keyCode)
            return currentModifiers.isEmpty ? nil : Array(pressedKeys)
            
        default:
            break
        }
        
        return nil
    }
    
    /// 处理键盘事件并检查匹配状态（用于录音控制模式）
    /// - Returns: 返回按键匹配结果
    func handleKeyEventWithMatch(type: CGEventType, event: CGEvent) -> KeyMatchResult {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        
        switch type {
        case .flagsChanged:
            _ = handleModifierChange(keyCode: keyCode, newModifiers: event.flags)
            
        case .keyDown:
            addKey(keyCode)
            
        case .keyUp:
            removeKey(keyCode)
            
        default:
            break
        }
        
        // 检查匹配状态
        return checkMatchStatus()
    }
    
    private func handleModifierChange(keyCode: Int64, newModifiers: CGEventFlags) -> [Int64]? {
        let isPressed = modifierMasks.contains { newModifiers.contains($0) && !currentModifiers.contains($0) }
        let isReleased = modifierMasks.contains { !newModifiers.contains($0) && currentModifiers.contains($0) }
        
        if isPressed {
            addKey(keyCode)
        } else if isReleased {
            removeKey(keyCode)
            currentModifiers = newModifiers
            return Array(pressedKeys) // 松开修饰键时返回快捷键组合
        }
        
        currentModifiers = newModifiers
        return nil
    }
    
    private func addKey(_ keyCode: Int64) {
        log.info("😑 按下: \(KeyMapper.keyCodeToString(keyCode))")
        pressedKeys.insert(keyCode)
    }
    
    private func removeKey(_ keyCode: Int64) {
        log.info("🥹 松开: \(KeyMapper.keyCodeToString(keyCode))")
        pressedKeys.remove(keyCode)
    }
    
    private func checkMatchStatus() -> KeyMatchResult {
        // 没有按键按下
        if pressedKeys.isEmpty {
            if isCurrentlyMatched {
                isCurrentlyMatched = false
                currentActiveMode = nil
                return .endMatch
            }
            return .notMatching
        }
        
        // 检查是否匹配任何配置
        let matchedConfig = keyConfigs.first { config in
            config.matches(Array(pressedKeys))
        }
        
        let isNowMatched = matchedConfig != nil
        let newMode = matchedConfig?.mode
        
        if isNowMatched, !isCurrentlyMatched {
            // 从不匹配变为匹配 -> 开始录音
            log.info("🎯 按键命中\(newMode == .normal ? "普通模式" : "命令模式")")
            
            isCurrentlyMatched = true
            currentActiveMode = newMode
            return .startMatch(newMode!)
            
        } else if !isNowMatched, isCurrentlyMatched {
            // 从匹配变为不匹配 -> 停止录音
            log.info("❌ 按键组合不再匹配: \(currentActiveMode!.rawValue)")
            
            isCurrentlyMatched = false
            currentActiveMode = nil
            return .endMatch
            
        } else if isNowMatched, isCurrentlyMatched {
            // 持续匹配状态，但需要检查是否有模式转换
            if let currentMode = currentActiveMode, let newMode, currentMode != newMode {
                // 模式转换发生
                log.info("🔄 模式转换: \(currentMode.description) → \(newMode.description)")
                
                currentActiveMode = newMode
                return .modeUpgrade(from: currentMode, to: newMode)
            }
            return .stillMatching
            
        } else {
            return .notMatching
        }
    }
    
    func clear() {
        pressedKeys.removeAll()
        currentModifiers = []
        isCurrentlyMatched = false
        currentActiveMode = nil
    }
}
