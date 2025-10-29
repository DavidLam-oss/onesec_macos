//
//  AXInputContentAccessor.swift
//  OnesecCore
//
//  Created by 王晓雨 on 2025/10/28.
//

import Cocoa
import Vision

class AXInputContentAccessor {
    /// 获取焦点元素的内容
    /// 当元素有输入内容时，直接获取输入内容 200
    static func getFocusElementInputContent() -> String? {
        guard let element = AXElementAccessor.getFocusedElement() else {
            return nil
        }

        // 检查是否有内容 (选中文本或总字符数)
        let hasSelectedText = (AXElementAccessor.getAttributeValue(
            element: element, attribute: kAXSelectedTextAttribute,
        ) as String?)?.isEmpty == false

        let contentLength: Int = AXElementAccessor.getAttributeValue(
            element: element, attribute: kAXNumberOfCharactersAttribute,
        ) ?? 0

        guard hasSelectedText || contentLength > 0 else {
            return nil
        }

        guard let text = getContextAroundCursor(element: element) else {
            return nil
        }

        return text.cleaned
    }

    static func getContextAroundCursor(element: AXUIElement, contextLength: Int = 200) -> String? {
        guard let totalLength: Int = AXElementAccessor.getAttributeValue(
            element: element, attribute: kAXNumberOfCharactersAttribute,
        ) else {
            log.warning("Cannot get text length")
            return nil
        }

        guard let rangeValue: AXValue = AXElementAccessor.getAttributeValue(
            element: element, attribute: kAXSelectedTextRangeAttribute,
        ) else {
            log.warning("Cannot get cursor position")
            return nil
        }

        var cursorRange = CFRange()
        guard AXValueGetValue(rangeValue, .cfRange, &cursorRange) else { return nil }

        let cursorPosition = cursorRange.location

        // 计算范围
        let halfLength = contextLength / 2
        let start = max(0, cursorPosition - halfLength)
        let end = min(totalLength, cursorPosition + halfLength)
        var targetRange = CFRangeMake(start, end - start)

        // 获取文本
        let targetRangeValue = AXValueCreate(.cfRange, &targetRange)!
        if let text: String = AXElementAccessor.getParameterizedAttributeValue(
            element: element,
            attribute: kAXStringForRangeParameterizedAttribute,
            parameter: targetRangeValue
        ) {
            return text
        }

        // 降级方案: 全文截取
        log.warning("Cannot get text for range, fallback to full content")
        guard let fullText: String = AXElementAccessor.getAttributeValue(
            element: element, attribute: kAXValueAttribute,
        ) else {
            return nil
        }

        let startIndex = fullText.index(fullText.startIndex, offsetBy: start, limitedBy: fullText.endIndex) ?? fullText.startIndex
        let endIndex = fullText.index(fullText.startIndex, offsetBy: end, limitedBy: fullText.endIndex) ?? fullText.endIndex
        return String(fullText[startIndex ..< endIndex])
    }
}
