//
//  AXInputContentAccessor.swift
//  OnesecCore
//
//  Created by 王晓雨 on 2025/10/28.
//

import Cocoa
import Vision

class AXInputContentAccessor {
    static func getFocusElementInputContent(contextLength: Int = 200) -> String? {
        guard let element = AXElementAccessor.getFocusedElement() else {
            return nil
        }

        guard let totalLength: Int = AXElementAccessor.getAttributeValue(
            element: element, attribute: kAXNumberOfCharactersAttribute
        ), totalLength > 0 else {
            return nil
        }

        guard let rangeValue: AXValue = AXElementAccessor.getAttributeValue(
            element: element, attribute: kAXSelectedTextRangeAttribute
        ) else {
            return nil
        }

        var cursorRange = CFRange()
        guard AXValueGetValue(rangeValue, .cfRange, &cursorRange) else {
            return nil
        }

        // 计算范围
        let cursorPos = cursorRange.location
        let half = contextLength >> 1
        let start = max(0, cursorPos - half)
        let length = min(totalLength - start, contextLength)

        var targetRange = CFRangeMake(start, length)
        guard let rangeValuePtr = AXValueCreate(.cfRange, &targetRange) else {
            return nil
        }

        if let text: String = AXElementAccessor.getParameterizedAttributeValue(
            element: element,
            attribute: kAXStringForRangeParameterizedAttribute,
            parameter: rangeValuePtr
        ) {
            return text.cleaned
        }

        // 降级: 获取全文并用 UTF8 视图快速切片
        guard let fullText: String = AXElementAccessor.getAttributeValue(
            element: element, attribute: kAXValueAttribute
        ), !fullText.isEmpty else {
            return nil
        }

        // 使用 UTF16 视图进行 O(1) 的索引操作
        let utf16 = fullText.utf16
        let safeStart = min(start, utf16.count)
        let safeEnd = min(start + length, utf16.count)

        guard safeStart < safeEnd else { return nil }

        let startIdx = utf16.index(utf16.startIndex, offsetBy: safeStart)
        let endIdx = utf16.index(utf16.startIndex, offsetBy: safeEnd)

        return String(utf16[startIdx ..< endIdx])?.cleaned
    }
}
