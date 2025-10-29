//
//  AXElementAccessor.swift
//  OnesecCore
//
//  Created by 王晓雨 on 2025/10/29.
//

import ApplicationServices

/// AXUIElement 基础访问器
/// 提供对可访问性元素的属性、层次结构的访问功能
class AXElementAccessor {
    /// 获取 AX 元素的属性值
    /// - Parameters:
    ///   - element: AX UI 元素
    ///   - attribute: 属性名称
    /// - Returns: 属性值的字符串表示，如果获取失败返回 nil
    static func getAttributeValue(element: AXUIElement, attribute: String) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)

        guard result == .success, let value else {
            return nil
        }

        let stringValue = "\(value)"
        return stringValue.isEmpty ? nil : stringValue
    }

    /// 获取 AX 元素的父元素
    /// - Parameter element: AX UI 元素
    /// - Returns: 父元素，如果不存在返回 nil
    static func getParent(of element: AXUIElement) -> AXUIElement? {
        var parentRef: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(element, kAXParentAttribute as CFString, &parentRef)
            == .success
        else {
            return nil
        }
        return (parentRef as! AXUIElement)
    }

    /// 获取 AX 元素的子元素列表
    /// - Parameter element: AX UI 元素
    /// - Returns: 子元素数组，如果不存在返回 nil
    static func getChildren(of element: AXUIElement) -> [AXUIElement]? {
        var children: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
            == .success,
            let childrenArray = children as? [AXUIElement]
        else {
            return nil
        }
        return childrenArray
    }
}

