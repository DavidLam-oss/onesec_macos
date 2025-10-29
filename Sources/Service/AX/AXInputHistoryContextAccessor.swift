//
//  AXInputHistoryContextAccessor.swift
//  OnesecCore
//
//  Created by 王晓雨 on 2025/10/29.
//

import Cocoa
import Vision

class AXInputHistoryContextAccessor {
    static let needHistoryLength = 400

    /// 获取输入框上方的聊天历史内容
    static func getChatHistory(from element: AXUIElement) -> String? {
        var current = element
        var bestContent = ""

        for level in 0 ..< 10 {
            guard let parent = AXElementAccessor.getParent(of: current) else { break }
            current = parent

            if let content = searchChatContent(in: current, excludeElement: element),
               content.count > bestContent.count
            {
                bestContent = content

                if content.count >= needHistoryLength {
                    log.debug("Level \(level): reached target, stopping")
                    return bestContent
                }
            }
        }

        return bestContent.isEmpty ? nil : bestContent
    }

    private static func searchChatContent(in element: AXUIElement, excludeElement: AXUIElement)
        -> String?
    {
        let text = collectTextMessages(
            from: element, excludeElement: excludeElement, maxChars: needHistoryLength,
        )
        return text.isEmpty ? nil : text
    }

    /// 递归收集文本消息 (限制字数，从后往前收集)
    private static func collectTextMessages(
        from element: AXUIElement,
        excludeElement: AXUIElement,
        maxChars: Int,
        depth: Int = 0,
    ) -> String {
        guard maxChars > 0 else { return "" }

        if CFEqual(element, excludeElement) {
            log.debug("[\(depth)] skipping excluded element (self)")
            return ""
        }

        guard let childrenArray = AXElementAccessor.getChildren(of: element) else {
            return ""
        }

        var texts: [String] = []
        var totalChars = 0

        // 从后往前遍历 (最新的消息在后面)
        for (index, child) in childrenArray.reversed().enumerated() {
            if totalChars >= maxChars {
                log.debug("[\(depth)] reached maxChars limit: \(totalChars)")
                break
            }

            if CFEqual(child, excludeElement) || containsElement(child, target: excludeElement) {
                continue
            }

            guard
                let role: String = AXElementAccessor.getAttributeValue(
                    element: child, attribute: kAXRoleAttribute
                )
            else {
                continue
            }

            // 收集文本内容
            if role.contains("TextArea") || role.contains("StaticText") || role.contains("Text") || role.contains("AXHeading") {
                // 尝试从多个属性获取文本：
                // 1. kAXValueAttribute - 通常用于输入框、文本区域
                // 2. kAXDescriptionAttribute - 描述性文本
                // 3. kAXTitleAttribute - 标题文本，特别适用于 AXHeading
                if let text: String = AXElementAccessor.getAttributeValue(
                    element: child, attribute: kAXValueAttribute
                )
                    ?? AXElementAccessor.getAttributeValue(
                        element: child, attribute: kAXDescriptionAttribute
                    )
                    ?? AXElementAccessor.getAttributeValue(
                        element: child, attribute: kAXTitleAttribute
                    )
                {
                    let cleaned = text.cleaned

                    if !cleaned.isEmpty {
                        texts.append(cleaned)
                        totalChars += cleaned.count
                    }
                }
            }
            // 递归搜索容器
            else if shouldRecurseIntoRole(role) {
                let remainingChars = max(0, maxChars - totalChars)
                let childText = collectTextMessages(
                    from: child,
                    excludeElement: excludeElement,
                    maxChars: remainingChars,
                    depth: depth + 1,
                )
                if !childText.isEmpty {
                    texts.append(childText)
                    totalChars += childText.count
                }
            } else {
                log.debug("[\(depth).\(index)] ✗ skipping role: \(role)")
            }
        }

        // 反转回正确顺序, 拼接并截取最后 maxChars 字符
        let result = texts.reversed().joined(separator: " ")
        return result.count <= maxChars ? result : String(result.suffix(maxChars))
    }

    private static func shouldRecurseIntoRole(_ role: String) -> Bool {
        let recursiveRoles = [
            "ScrollArea", "Group", "SplitGroup", "List",
            "Row", "Column", "Container", "WebArea",
            "Section", "Pane", "Content", "View",
        ]

        return recursiveRoles.contains { role.contains($0) }
    }

    private static func containsElement(_ element: AXUIElement, target: AXUIElement) -> Bool {
        if CFEqual(element, target) {
            return true
        }

        guard let childrenArray = AXElementAccessor.getChildren(of: element) else {
            return false
        }

        return childrenArray.contains { containsElement($0, target: target) }
    }
}
