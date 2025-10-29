//
//  Context.swift
//  OnesecCore
//
//  Created by 王晓雨 on 2025/10/16.
//

import ApplicationServices
import Cocoa
import Vision

class ContextService {
    static func getAppInfo() -> AppInfo {
        var appName = "未知应用"
        var bundleID = "未知 Bundle ID"
        var shortVersion = "未知版本"

        if let frontApp = NSWorkspace.shared.frontmostApplication {
            appName = frontApp.localizedName ?? "未知应用"
            bundleID = frontApp.bundleIdentifier ?? "未知 Bundle ID"

            if let bundleURL = frontApp.bundleURL {
                let bundle = Bundle(url: bundleURL)
                if let bundle {
                    if let version = bundle.object(
                        forInfoDictionaryKey: "CFBundleShortVersionString") as? String
                    {
                        shortVersion = version
                    }
                }
            }
        }

        return AppInfo(appName: appName, bundleID: bundleID, shortVersion: shortVersion)
    }

    static func copyCurrentSelectionAndRestore() async -> String? {
        let pasteboard = NSPasteboard.general
        let oldContents = pasteboard.string(forType: .string)

        // 模拟 Cmd+C 复制
        let source = CGEventSource(stateID: .hidSystemState)
        let cDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true)
        cDown?.flags = .maskCommand
        let cUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)
        cUp?.flags = .maskCommand

        cDown?.post(tap: .cghidEventTap)
        cUp?.post(tap: .cghidEventTap)

        // 等待复制功能完成
        try? await Task.sleep(nanoseconds: 100_000_000)

        let copiedText = pasteboard.string(forType: .string)

        // 恢复原剪贴板内容
        pasteboard.clearContents()
        if let oldContents {
            pasteboard.setString(oldContents, forType: .string)
        }

        return copiedText
    }
    
    static func pasteTextToActiveApp(_ text: String) {
        log.info("Paste Text To Active App: \(text)")

        // 保存当前剪贴板内容
        let pasteboard = NSPasteboard.general
        let oldContents = pasteboard.string(forType: .string)

        // 将文本复制到剪贴板
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // 模拟 Cmd+V 粘贴
        let source = CGEventSource(stateID: .hidSystemState)

        // 按下 Cmd
        let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true)
        cmdDown?.flags = .maskCommand

        // 按下 V
        let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        vDown?.flags = .maskCommand

        // 释放 V
        let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        vUp?.flags = .maskCommand

        // 释放 Cmd
        _ = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false)

        // 发送事件
        vDown?.post(tap: .cghidEventTap)
        vUp?.post(tap: .cghidEventTap)

        // 延迟后恢复原剪贴板内容
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let oldContents {
                pasteboard.clearContents()
                pasteboard.setString(oldContents, forType: .string)
            }
        }
    }

    /// 获取应用焦点元素
    /// 返回当前正在接收键盘输入的 UI 元素
    /// 例如：正在编辑的文本框、被选中的按钮、激活的窗口控件等
    static func getFocusedElement() -> AXUIElement? {
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedElement: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            systemWideElement, kAXFocusedUIElementAttribute as CFString, &focusedElement,
        )

        guard result == .success, let element = focusedElement as! AXUIElement? else {
            log.warning("Cannot get focused element: \(result.rawValue)")
            return nil
        }

        return element
    }

    static func getInputContent() -> String? {
        guard let element = getFocusedElement() else {
            return nil
        }

        return AXInputContentAccessor.getInputContent(element: element)
    }

    static func getHistoryContent() -> String? {
        guard let element = getFocusedElement() else {
            return nil
        }

        return AXInputHistoryContextAccessor.getChatHistory(from: element)
    }

    static func getSelectedText() async -> String? {
        guard let element = getFocusedElement() else {
            return await copyCurrentSelectionAndRestore()
        }

        // 方法1: 直接获取选中文本
        var selectedText: CFTypeRef?
        if AXUIElementCopyAttributeValue(
            element, kAXSelectedTextAttribute as CFString, &selectedText,
        ) == .success,
            let text = selectedText as? String
        {
            return text
        }

        // 方法2: 通过选中范围获取
        var selectedRange: CFTypeRef?
        if AXUIElementCopyAttributeValue(
            element, kAXSelectedTextRangeAttribute as CFString, &selectedRange,
        ) == .success,
            let range = selectedRange
        {
            var value: CFTypeRef?
            if AXUIElementCopyParameterizedAttributeValue(
                element, kAXStringForRangeParameterizedAttribute as CFString, range, &value,
            )
                == .success,
                let text = value as? String
            {
                return text
            }
        }

        // 使用 Cmd+C 备用方案
        return await copyCurrentSelectionAndRestore()
    }

    static func getFocusElementInfo() -> FocusElementInfo {
        guard let element = getFocusedElement() else {
            return FocusElementInfo.empty
        }

        let axRole = AXElementAccessor.getAttributeValue(element: element, attribute: kAXRoleAttribute) ?? ""
        let axRoleDescription =
            AXElementAccessor.getAttributeValue(element: element, attribute: kAXRoleDescriptionAttribute) ?? ""
        let axPlaceholderValue =
            AXElementAccessor.getAttributeValue(element: element, attribute: kAXPlaceholderValueAttribute) ?? ""
        let axDescription =
            AXElementAccessor.getAttributeValue(element: element, attribute: kAXDescriptionAttribute) ?? ""

        return FocusElementInfo(
            windowTitle: getWindowTitle(for: element),
            axRole: axRole,
            axRoleDescription: axRoleDescription,
            axPlaceholderValue: axPlaceholderValue,
            axDescription: axDescription,
        )
    }

    static func getWindowTitle(for element: AXUIElement) -> String {
        var currentElement = element

        // 向上遍历找到窗口元素
        for _ in 0 ..< 10 {
            if let role = AXElementAccessor.getAttributeValue(element: currentElement, attribute: kAXRoleAttribute),
               role.contains("Window")
            {
                if let title = AXElementAccessor.getAttributeValue(element: currentElement, attribute: kAXTitleAttribute),
                   !title.isEmpty
                {
                    return title
                }
            }

            currentElement = AXElementAccessor.getParent(of: currentElement) ?? currentElement
        }

        return "Unknown Window"
    }
}
