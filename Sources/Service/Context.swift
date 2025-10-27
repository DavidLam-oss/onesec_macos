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
        guard AXIsProcessTrusted() else {
            return AppInfo(appName: "权限不足", bundleID: "unknown", shortVersion: "unknown")
        }

        var appName = "未知应用"
        var bundleID = "未知 Bundle ID"
        var shortVersion = "未知版本"

        if let frontApp = NSWorkspace.shared.frontmostApplication {
            appName = frontApp.localizedName ?? "未知应用"
            bundleID = frontApp.bundleIdentifier ?? "未知 Bundle ID"

            if let bundleURL = frontApp.bundleURL {
                let bundle = Bundle(url: bundleURL)
                if let bundle {
                    if let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
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
        
        // 等待复制完成
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        
        let copiedText = pasteboard.string(forType: .string)
        log.debug("✅ 通过 Cmd+C 获取到文本: \(copiedText ?? "")")
        
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
        
        // log.info("Old pasteboard contents \(oldContents ?? "")")
        
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
    
    static func getFocusContextAndElementInfo(includeContext: Bool = true) async -> (FocusContext, FocusElementInfo?) {
        let inputContent = ""
        var focusElementInfo: FocusElementInfo?
        
        // 获取当前焦点元素
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedElement: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        
        if result == .success, let element = focusedElement {
            let axElement = element as! AXUIElement
            
            // 获取焦点元素信息
            focusElementInfo = getFocusElementInfo(from: axElement)
            
            // 获取元素的值（文本内容）- 只有在需要上下文时才获取
            if includeContext {
                log.debug("includeContext::: \(includeContext)")
            } else {
                // log.info("⏰ 跳过元素值获取（普通模式）")
            }
        }
         
        if inputContent.isEmpty {
            // // 当无法通过 AX API 获取输入内容时，使用 OCR 识别前台窗口文字
            // log.debug("尝试通过 OCR 识别前台窗口文字...")
            
            // let startTime = Date()
            // let ocrResults = await OCRService.captureFrontWindowAndRecognize()
            // let duration = Date().timeIntervalSince(startTime)
            
            // inputContent = ocrResults.map(\.text).joined(separator: "\n")
            
            // if !inputContent.isEmpty {
            //     log.info("✅ OCR 识别完成: 识别 \(ocrResults.count) 个文本块，共 \(inputContent.count) 个字符，耗时 \(String(format: "%.2f", duration))秒")
                
            //     // 打印识别结果
            //     ocrResults.enumerated().forEach { index, result in
            //         log.info("  [\(index + 1)] \(result.text)")
            //     }
                
            //     // 保存到桌面
            //     OCRService.saveToDesktop(ocrResults)
            // } else {
            //     log.debug("OCR 未识别到任何文字，耗时 \(String(format: "%.2f", duration))秒")
            // }
        }
        
        // 获取选中文本 - 只有在需要上下文时才获取（命令模式）
        let selectedText: String = if includeContext {
            await getSelectedText() ?? ""
        } else {
            // log.info("⏰ 跳过选中文本获取（普通模式）")
            ""
        }
        
        let focusContext = FocusContext(inputContent: inputContent, selectedText: selectedText)
        log.info("⏰ getFocusContextAndElementInfo 完成")
        return (focusContext, focusElementInfo)
    }
    
    static func getFocusElementInfo(from element: AXUIElement) -> FocusElementInfo {
        let axRole = getAttributeValue(element: element, attribute: kAXRoleAttribute) ?? ""
        let axRoleDescription = getAttributeValue(element: element, attribute: kAXRoleDescriptionAttribute) ?? ""
        let axPlaceholderValue = getAttributeValue(element: element, attribute: kAXPlaceholderValueAttribute) ?? ""
        let axDescription = getAttributeValue(element: element, attribute: kAXDescriptionAttribute) ?? ""
        
        return FocusElementInfo(
            windowTitle: getWindowTitle(for: element),
            axRole: axRole,
            axRoleDescription: axRoleDescription,
            axPlaceholderValue: axPlaceholderValue,
            axDescription: axDescription,
        )
    }

    static func getSelectedText() async -> String? {
        //  获取当前有焦点的应用
        let systemWideElement = AXUIElementCreateSystemWide()
        
        var focusedApp: AnyObject?
        let result = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedApplicationAttribute as CFString,
            &focusedApp,
        )
        
        guard result == .success, let app = focusedApp else {
            return await copyCurrentSelectionAndRestore()
        }
        
        let appElement = app as! AXUIElement
        
        // 遍历并保存所有可访问性元素
        let allElements = collectAllElements(from: appElement)
        saveElementsToFile(allElements)
        
        // 尝试获取 AXTextArea 元素
        if let textArea = findTextArea(in: appElement) {
            log.info("✅ 找到 AXTextArea 元素")
            printTextAreaDetails(textArea)
        } else {
            log.debug("未找到 AXTextArea 元素")
        }
        
        //  获取焦点元素
        var focusedElement: AnyObject?
        AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement,
        )
        
        guard let element = focusedElement else {
            log.warning("Cannot get focusedElement")
            return await copyCurrentSelectionAndRestore()
        }
        
        //  方法1: 直接获取选中文本
        var selectedText: AnyObject?
        let selectedResult = AXUIElementCopyAttributeValue(
            element as! AXUIElement,
            kAXSelectedTextAttribute as CFString,
            &selectedText,
        )
        
        if selectedResult == .success, let text = selectedText as? String {
            return text
        }
        
        //  方法2: 通过选中范围获取
        var selectedRange: AnyObject?
        AXUIElementCopyAttributeValue(
            element as! AXUIElement,
            kAXSelectedTextRangeAttribute as CFString,
            &selectedRange,
        )
        
        if let range = selectedRange {
            var value: AnyObject?
            AXUIElementCopyParameterizedAttributeValue(
                element as! AXUIElement,
                kAXStringForRangeParameterizedAttribute as CFString,
                range as CFTypeRef,
                &value,
            )
            if let text = value as? String {
                return text
            }
        }
        
        // 所有 AX API 方法都失败，使用 Cmd+C  备用方案
        return await copyCurrentSelectionAndRestore()
    }
    
    static func getWindowTitle(for element: AXUIElement) -> String {
        // 向上遍历找到窗口元素
        var currentElement = element
        
        // 最多向上遍历5层
        for _ in 0 ..< 5 {
            if let role = getAttributeValue(element: currentElement, attribute: kAXRoleAttribute),
               role.contains("Window")
            {
                if let title = getAttributeValue(element: currentElement, attribute: kAXTitleAttribute),
                   !title.isEmpty
                {
                    return title
                }
            }
            
            // 获取父元素
            var parent: CFTypeRef?
            if AXUIElementCopyAttributeValue(currentElement, kAXParentAttribute as CFString, &parent) == .success,
               let parentElement = parent
            {
                currentElement = parentElement as! AXUIElement
            } else {
                break
            }
        }
        
        return "未知窗口"
    }
    
    static func getAttributeValue(element: AXUIElement, attribute: String) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        
        if result == .success, let unwrappedValue = value {
            return "\(unwrappedValue)"
        }
        
        return nil
    }
    
    /// 在应用的元素树中查找 AXTextArea 元素
    static func findTextArea(in element: AXUIElement, depth: Int = 0, maxDepth: Int = 10) -> AXUIElement? {
        // 防止递归过深
        guard depth < maxDepth else { return nil }
        
        // 检查当前元素是否是 AXTextArea
        if let role = getAttributeValue(element: element, attribute: kAXRoleAttribute),
           role == "AXTextArea" {
            log.debug("找到 AXTextArea，深度: \(depth)")
            return element
        }
        
        // 获取子元素
        var children: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        
        guard result == .success,
              let childrenArray = children as? [AXUIElement] else {
            return nil
        }
        
        // 递归搜索子元素
        for child in childrenArray {
            if let textArea = findTextArea(in: child, depth: depth + 1, maxDepth: maxDepth) {
                return textArea
            }
        }
        
        return nil
    }
    
    /// 打印 AXTextArea 元素的详细信息
    static func printTextAreaDetails(_ element: AXUIElement) {
        log.info("========== AXTextArea 详细信息 ==========")
        
        // 基本属性
        let role = getAttributeValue(element: element, attribute: kAXRoleAttribute) ?? "N/A"
        let roleDescription = getAttributeValue(element: element, attribute: kAXRoleDescriptionAttribute) ?? "N/A"
        let title = getAttributeValue(element: element, attribute: kAXTitleAttribute) ?? "N/A"
        let description = getAttributeValue(element: element, attribute: kAXDescriptionAttribute) ?? "N/A"
        let value = getAttributeValue(element: element, attribute: kAXValueAttribute) ?? ""
        let placeholderValue = getAttributeValue(element: element, attribute: kAXPlaceholderValueAttribute) ?? "N/A"
        
        log.info("角色 (Role): \(role)")
        log.info("角色描述 (RoleDescription): \(roleDescription)")
        log.info("标题 (Title): \(title)")
        log.info("描述 (Description): \(description)")
        log.info("占位符 (PlaceholderValue): \(placeholderValue)")
        log.info("内容长度: \(value.count) 个字符")
        
        // 打印内容（如果内容较长则截取）
        if !value.isEmpty {
            let previewLength = min(200, value.count)
            let preview = String(value.prefix(previewLength))
            if value.count > previewLength {
                log.info("内容预览: \(preview)... (已截取前\(previewLength)个字符)")
            } else {
                log.info("内容: \(preview)")
            }
        } else {
            log.info("内容: (空)")
        }
        
        // 获取位置和大小
        var position: CFTypeRef?
        var size: CFTypeRef?
        
        if AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &position) == .success,
           let posValue = position {
            log.info("位置 (Position): \(posValue)")
        }
        
        if AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &size) == .success,
           let sizeValue = size {
            log.info("大小 (Size): \(sizeValue)")
        }
        
        // 其他有用属性
        let enabled = getAttributeValue(element: element, attribute: kAXEnabledAttribute) ?? "N/A"
        let focused = getAttributeValue(element: element, attribute: kAXFocusedAttribute) ?? "N/A"
        let editable = getAttributeValue(element: element, attribute: "AXEditable") ?? "N/A"
        
        log.info("已启用 (Enabled): \(enabled)")
        log.info("已聚焦 (Focused): \(focused)")
        log.info("可编辑 (Editable): \(editable)")
        
        // 选中文本相关
        let selectedText = getAttributeValue(element: element, attribute: kAXSelectedTextAttribute) ?? "N/A"
        let selectedTextRange = getAttributeValue(element: element, attribute: kAXSelectedTextRangeAttribute) ?? "N/A"
        
        log.info("选中文本 (SelectedText): \(selectedText)")
        log.info("选中范围 (SelectedTextRange): \(selectedTextRange)")
        
        // 获取所有可用的属性名称
        var attributeNames: CFArray?
        if AXUIElementCopyAttributeNames(element, &attributeNames) == .success,
           let names = attributeNames as? [String] {
            log.info("所有可用属性 (\(names.count)个): \(names.joined(separator: ", "))")
        }
        
        log.info("========================================")
    }
    
    /// 元素信息结构
    struct ElementInfo {
        let depth: Int
        let role: String
        let roleDescription: String
        let title: String
        let description: String
        let value: String
        let enabled: String
        let focused: String
        let position: String
        let size: String
        let childrenCount: Int
        let allAttributes: [String]
    }
    
    /// 收集所有可访问性元素
    static func collectAllElements(from element: AXUIElement, depth: Int = 0, maxDepth: Int = 15) -> [ElementInfo] {
        var elements: [ElementInfo] = []
        
        // 防止递归过深
        guard depth < maxDepth else { return elements }
        
        // 获取当前元素的信息
        let role = getAttributeValue(element: element, attribute: kAXRoleAttribute) ?? "N/A"
        let roleDescription = getAttributeValue(element: element, attribute: kAXRoleDescriptionAttribute) ?? "N/A"
        let title = getAttributeValue(element: element, attribute: kAXTitleAttribute) ?? ""
        let description = getAttributeValue(element: element, attribute: kAXDescriptionAttribute) ?? ""
        let value = getAttributeValue(element: element, attribute: kAXValueAttribute) ?? ""
        let enabled = getAttributeValue(element: element, attribute: kAXEnabledAttribute) ?? "N/A"
        let focused = getAttributeValue(element: element, attribute: kAXFocusedAttribute) ?? "N/A"
        
        // 获取位置和大小
        var position: CFTypeRef?
        var size: CFTypeRef?
        let positionStr = if AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &position) == .success, let posValue = position {
            "\(posValue)"
        } else {
            "N/A"
        }
        
        let sizeStr = if AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &size) == .success, let sizeValue = size {
            "\(sizeValue)"
        } else {
            "N/A"
        }
        
        // 获取所有属性名称
        var attributeNames: CFArray?
        let allAttributes = if AXUIElementCopyAttributeNames(element, &attributeNames) == .success,
           let names = attributeNames as? [String] {
            names
        } else {
            [String]()
        }
        
        // 获取子元素数量
        var children: CFTypeRef?
        let childrenResult = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        let childrenCount = if childrenResult == .success, let childrenArray = children as? [AXUIElement] {
            childrenArray.count
        } else {
            0
        }
        
        // 创建元素信息
        let elementInfo = ElementInfo(
            depth: depth,
            role: role,
            roleDescription: roleDescription,
            title: title,
            description: description,
            value: value,
            enabled: enabled,
            focused: focused,
            position: positionStr,
            size: sizeStr,
            childrenCount: childrenCount,
            allAttributes: allAttributes
        )
        
        elements.append(elementInfo)
        
        // 递归处理子元素
        if childrenResult == .success, let childrenArray = children as? [AXUIElement] {
            for child in childrenArray {
                let childElements = collectAllElements(from: child, depth: depth + 1, maxDepth: maxDepth)
                elements.append(contentsOf: childElements)
            }
        }
        
        return elements
    }
    
    /// 将元素信息保存到文件
    static func saveElementsToFile(_ elements: [ElementInfo]) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        
        let desktopPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
        let fileName = "AXElements_\(timestamp).txt"
        let filePath = desktopPath.appendingPathComponent(fileName)
        
        var content = "可访问性元素树\n"
        content += "生成时间: \(timestamp)\n"
        content += "总元素数: \(elements.count)\n"
        content += String(repeating: "=", count: 100) + "\n\n"
        
        for (index, element) in elements.enumerated() {
            let indent = String(repeating: "  ", count: element.depth)
            
            content += "[\(index + 1)] " + indent + "元素深度: \(element.depth)\n"
            content += indent + "  角色: \(element.role)\n"
            content += indent + "  角色描述: \(element.roleDescription)\n"
            
            if !element.title.isEmpty {
                content += indent + "  标题: \(element.title)\n"
            }
            
            if !element.description.isEmpty {
                content += indent + "  描述: \(element.description)\n"
            }
            
            if !element.value.isEmpty {
                let valuePreview = element.value.count > 100 ? 
                    String(element.value.prefix(100)) + "... (共\(element.value.count)字符)" : 
                    element.value
                content += indent + "  值: \(valuePreview)\n"
            }
            
            content += indent + "  启用: \(element.enabled), 聚焦: \(element.focused)\n"
            content += indent + "  位置: \(element.position), 大小: \(element.size)\n"
            content += indent + "  子元素数: \(element.childrenCount)\n"
            content += indent + "  属性(\(element.allAttributes.count)个): \(element.allAttributes.joined(separator: ", "))\n"
            content += "\n"
        }
        
        do {
            try content.write(to: filePath, atomically: true, encoding: .utf8)
            log.info("✅ 元素树已保存到: \(filePath.path)")
            log.info("📊 共保存 \(elements.count) 个元素")
        } catch {
            log.error("❌ 保存元素树失败: \(error.localizedDescription)")
        }
    }
}
