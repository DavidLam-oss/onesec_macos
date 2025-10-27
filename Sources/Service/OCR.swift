//
//  OCR.swift
//  OnesecCore
//
//  Created by AI Assistant on 2025/10/27.
//

import Cocoa
import CoreGraphics
@preconcurrency import Vision

// MARK: - 识别结果

struct RecognizedText {
    let text: String
    let boundingBox: CGRect // 归一化坐标 (0.0-1.0)
}

// MARK: - OCR服务

class OCRService {
    /// 截取前台窗口并识别文字
    static func captureFrontWindowAndRecognize() async -> [RecognizedText] {
        guard let windowImage = captureFrontWindow() else {
            log.error("无法截取前台窗口")
            return []
        }
        
        return await recognizeText(from: windowImage)
    }
    
    /// 获取前台窗口的纯文本内容
    static func captureFrontWindowText() async -> String {
        let results = await captureFrontWindowAndRecognize()
        return results.map(\.text).joined(separator: "\n")
    }
    
    /// 保存识别结果到桌面txt文件
    static func saveToDesktop(_ results: [RecognizedText]) {
        let timestamp = DateFormatter().apply {
            $0.dateFormat = "yyyyMMdd_HHmmss"
        }.string(from: Date())
        
        let filename = "OCR_\(timestamp).txt"
        let desktopPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop")
            .appendingPathComponent(filename)
        
        let content = results.enumerated().map { index, result in
            "[\(index + 1)] \(result.text) (x:\(String(format: "%.3f", result.boundingBox.origin.x)), y:\(String(format: "%.3f", result.boundingBox.origin.y)))"
        }.joined(separator: "\n")
        
        try? content.write(to: desktopPath, atomically: true, encoding: .utf8)
        log.info("📄 OCR结果已保存: \(desktopPath.path)")
    }
    
    // MARK: - Private Methods
    
    /// 获取前台窗口的截图
    private static func captureFrontWindow() -> CGImage? {
        // 1. 获取窗口列表
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            log.error("🔍 DEBUG: 无法获取窗口列表 (CGWindowListCopyWindowInfo 失败)")
            return nil
        }
        log.debug("🔍 DEBUG: 成功获取窗口列表，共 \(windowList.count) 个窗口")
        
        // 2. 获取前台应用
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            log.error("🔍 DEBUG: 无法获取前台应用 (NSWorkspace.shared.frontmostApplication 为 nil)")
            return nil
        }
        
        let frontPID = frontApp.processIdentifier
        let frontAppName = frontApp.localizedName ?? "Unknown"
        log.debug("🔍 DEBUG: 前台应用: \(frontAppName) (PID: \(frontPID))")
        
        // 3. 找到前台应用的主窗口
        var matchedWindowsCount = 0
        for (index, window) in windowList.enumerated() {
            let ownerPID = window[kCGWindowOwnerPID as String] as? Int32
            let windowLayer = window[kCGWindowLayer as String] as? Int
            let bounds = window[kCGWindowBounds as String] as? [String: CGFloat]
            
            // 调试：打印前5个窗口的信息
            if index < 5 {
                log.debug("🔍 DEBUG: 窗口[\(index)] PID=\(ownerPID ?? -1), Layer=\(windowLayer ?? -1), Bounds=\(bounds != nil ? "有" : "无")")
            }
            
            // 检查是否属于前台应用
            guard let pid = ownerPID, pid == frontPID else {
                continue
            }
            
            matchedWindowsCount += 1
            log.debug("🔍 DEBUG: 找到匹配的窗口 #\(matchedWindowsCount), Layer=\(windowLayer ?? -1)")
            
            // 检查窗口层级
            guard let layer = windowLayer, layer == 0 else {
                log.debug("🔍 DEBUG: 跳过窗口（Layer 不是 0）")
                continue
            }
            
            // 检查边界
            guard let windowBounds = bounds,
                  let x = windowBounds["X"],
                  let y = windowBounds["Y"],
                  let width = windowBounds["Width"],
                  let height = windowBounds["Height"] else {
                log.debug("🔍 DEBUG: 跳过窗口（无法获取边界信息）")
                continue
            }
            
            // 检查尺寸
            guard width > 100, height > 100 else {
                log.debug("🔍 DEBUG: 跳过窗口（尺寸太小: \(Int(width))x\(Int(height))）")
                continue
            }
            
            let windowRect = CGRect(x: x, y: y, width: width, height: height)
            log.info("📸 截取前台窗口: \(frontAppName) - 尺寸: \(Int(width))x\(Int(height))")
            
            // 4. 创建截图
            guard let image = CGDisplayCreateImage(CGMainDisplayID(), rect: windowRect) else {
                log.error("🔍 DEBUG: CGDisplayCreateImage 失败（rect: \(windowRect)）")
                continue
            }
            
            log.debug("🔍 DEBUG: 成功创建窗口截图")
            return image
        }
        
        log.warning("🔍 DEBUG: 未找到前台应用的有效窗口（共找到 \(matchedWindowsCount) 个匹配 PID 的窗口），回退到全屏截图")
        
        // 5. 回退到全屏截图
        guard let fullScreenImage = CGDisplayCreateImage(CGMainDisplayID()) else {
            log.error("🔍 DEBUG: 全屏截图也失败了！可能没有屏幕录制权限")
            return nil
        }
        
        log.debug("🔍 DEBUG: 使用全屏截图")
        return fullScreenImage
    }
    
    /// 从图像识别文字
    private static func recognizeText(from image: CGImage) async -> [RecognizedText] {
        await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    log.error("OCR识别失败: \(error.localizedDescription)")
                    continuation.resume(returning: [])
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                
                let results = observations.compactMap { observation -> RecognizedText? in
                    guard let candidate = observation.topCandidates(1).first else {
                        return nil
                    }
                    return RecognizedText(text: candidate.string, boundingBox: observation.boundingBox)
                }
                
                log.info("OCR识别完成，共识别 \(results.count) 个文本块")
                continuation.resume(returning: results)
            }
            
            // 配置识别参数
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]
            
            // 执行识别
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    log.error("OCR请求执行失败: \(error.localizedDescription)")
                    continuation.resume(returning: [])
                }
            }
        }
    }
}

// MARK: - Helper Extension

private extension DateFormatter {
    func apply(_ closure: (DateFormatter) -> Void) -> DateFormatter {
        closure(self)
        return self
    }
}
