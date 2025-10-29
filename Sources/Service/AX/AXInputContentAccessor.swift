//
//  AXInputContentAccessor.swift
//  OnesecCore
//
//  Created by 王晓雨 on 2025/10/28.
//

import Cocoa
import Vision

class AXInputContentAccessor {
    /// 获取元素的内容
    /// 当元素有输入时，直接获取输入内容 200
    /// 当元素没有输入时，相邻元素的上下文内容作为补充 (History 400)
    static func getInputContent(element: AXUIElement) -> String? {
        // 获取选中文本状态
        var selectedTextRef: CFTypeRef?
        let isSelectedEmpty =
            AXUIElementCopyAttributeValue(
                element, kAXSelectedTextAttribute as CFString, &selectedTextRef,
            ) != .success
            || (selectedTextRef as? String)?.isEmpty != false

        // 如果有输入则直接获取
        if !isSelectedEmpty {
            return getContextAroundCursor(element: element)
        }

        // 检查是否有内容
        var lengthRef: CFTypeRef?
        let hasContent =
            AXUIElementCopyAttributeValue(
                element, kAXNumberOfCharactersAttribute as CFString, &lengthRef,
            ) == .success && (lengthRef as? Int ?? 0) > 0

        if !hasContent {
            return nil
        }

        return getContextAroundCursor(element: element)
    }

    static func getContextAroundCursor(element: AXUIElement, contextLength: Int = 200)
        -> String?
    {
        // 获取文本长度
        var lengthRef: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(
                element, kAXNumberOfCharactersAttribute as CFString, &lengthRef,
            ) == .success,
            let totalLength = lengthRef as? Int
        else {
            log.warning("Cannot get text length")
            return nil
        }

        // 获取光标位置
        var selectedRange: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(
                element, kAXSelectedTextRangeAttribute as CFString, &selectedRange,
            ) == .success,
            let rangeValue = selectedRange as! AXValue?
        else {
            log.warning("Cannot get cursor position")
            return nil
        }

        var cursorRange = CFRange()
        guard AXValueGetValue(rangeValue, .cfRange, &cursorRange) else {
            return nil
        }

        let cursorPosition = cursorRange.location
        let halfLength = contextLength / 2

        // 计算要获取的范围，确保不超出边界
        let start = max(0, cursorPosition - halfLength)
        let end = min(totalLength, cursorPosition + halfLength)
        let actualLength = end - start

        var targetRange = CFRangeMake(start, actualLength)
        let targetRangeValue = AXValueCreate(.cfRange, &targetRange)!

        // 直接获取指定范围的文本
        var textRef: CFTypeRef?
        guard
            AXUIElementCopyParameterizedAttributeValue(
                element, kAXStringForRangeParameterizedAttribute as CFString, targetRangeValue,
                &textRef,
            ) == .success,
            let text = textRef as? String
        else {
            log.warning("Cannot get text for range, fallback to full content")
            // 降级方案：获取全部内容
            var value: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value)
                == .success,
                let fullText = value as? String
            {
                let startIndex =
                    fullText.index(
                        fullText.startIndex, offsetBy: start, limitedBy: fullText.endIndex,
                    )
                    ?? fullText.startIndex
                let endIndex =
                    fullText.index(fullText.startIndex, offsetBy: end, limitedBy: fullText.endIndex)
                        ?? fullText.endIndex
                return String(fullText[startIndex ..< endIndex])
            }
            return nil
        }

        return text
    }
}
