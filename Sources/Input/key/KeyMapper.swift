//
//  KeyMapper.swift
//  OnesecCore
//
//  Created by 王晓雨 on 2025/10/16.
//

import Foundation

/// 键码映射器
class KeyMapper {
    static let keyCodeMap: [Int64: String] = [
        // 字母键
        0: "A",
        1: "S",
        2: "D",
        3: "F",
        4: "H",
        5: "G",
        6: "Z",
        7: "X",
        8: "C",
        9: "V",
        11: "B",
        12: "Q",
        13: "W",
        14: "E",
        15: "R",
        16: "Y",
        17: "T",
        31: "O",
        32: "U",
        34: "I",
        35: "P",
        37: "L",
        38: "J",
        40: "K",
        45: "N",
        46: "M",
        
        // 功能键
        49: "Space",
        36: "Return",
        48: "Tab",
        51: "Delete",
        53: "Escape",
        
        // 修饰键（左侧）
        55: "Left Command ⌘",
        56: "Left Shift ⇧",
        58: "Left Option ⌥",
        59: "Left Control ⌃",
        
        // 修饰键（右侧）
        54: "Right Command ⌘",
        60: "Right Shift ⇧",
        61: "Right Option ⌥",
        62: "Right Control ⌃",
        
        // Fn 键
        63: "Fn"
    ]
    
    /// 将键码转换为可读字符串
    /// - Parameter keyCode: 键码
    /// - Returns: 对应的字符串描述
    static func keyCodeToString(_ keyCode: Int64) -> String {
        return keyCodeMap[keyCode] ?? "Key(\(keyCode))"
    }
}

