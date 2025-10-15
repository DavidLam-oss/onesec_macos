//
//  keyStateTracker.swift
//  OnesecCore
//
//  Created by 王晓雨 on 2025/10/15.
//

import CoreGraphics
import Foundation

class KeyStateTracker {
    /// 当前按住的键码数组
    private var pressedKeys: [Int64] = []
    private var currentModifiers: CGEventFlags = []

    func handleKeyEvent(type: CGEventType, event: CGEvent) -> [Int64]? {
        switch type {
        case .flagsChanged:
            log.info("⬇️ 按下: flagsChanged")
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let newModifiers = event.flags
            if handleModifierChange(keyCode: keyCode, oldModifiers: currentModifiers, newModifiers: newModifiers) {
                return pressedKeys
            }
            currentModifiers = newModifiers

        case .keyDown:
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            log.info("⬇️ 按下: \(KeyMapper.keyCodeToString(keyCode))")

            if !pressedKeys.contains(keyCode) {
                pressedKeys.append(keyCode)
            }

        case .keyUp:
            log.info("⬆️ 松开: \(KeyMapper.keyCodeToString(event.getIntegerValueField(.keyboardEventKeycode)))")

            // 如果松开的是普通键，且有修饰键，则完成录制
            if !currentModifiers.isEmpty {
                return pressedKeys
            }

        default:
            break
        }

        return nil
    }

    private func handleModifierChange(keyCode: Int64, oldModifiers: CGEventFlags, newModifiers: CGEventFlags) -> Bool {
        let modifierMasks: [CGEventFlags] = [.maskCommand, .maskAlternate, .maskControl, .maskShift, .maskSecondaryFn]
        for mask in modifierMasks {
            if !oldModifiers.contains(mask), newModifiers.contains(mask) {
                // 修饰键按下
                log.info("⬇️ 按下: \(KeyMapper.keyCodeToString(keyCode)) (keyCode: \(keyCode))")
                if !pressedKeys.contains(keyCode) {
                    pressedKeys.append(keyCode)
                }
                return false
            } else if oldModifiers.contains(mask), !newModifiers.contains(mask) {
                // 修饰键松开
                log.info("⬆️ 松开: \(KeyMapper.keyCodeToString(keyCode)) (keyCode: \(keyCode))")
                if let index = pressedKeys.firstIndex(of: keyCode) {
                    pressedKeys.remove(at: index)
                }
                return true
            }
        }
        return false
    }


    func clear() {
        pressedKeys.removeAll()
    }
}
