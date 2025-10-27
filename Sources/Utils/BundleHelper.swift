//
//  BundleHelper.swift
//  OnesecCore
//
//  资源 Bundle 辅助工具
//

import Foundation

extension Bundle {
    static var resourceBundle: Bundle {
        // 生产环境: 从 App Bundle 的 Contents/Resources 目录加载
        let productionPath = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Resources/OnesecCore_OnesecCore.bundle")
            .path
        
        if let bundle = Bundle(path: productionPath) {
            return bundle
        }
        
        // 开发环境: 使用 SPM 自动生成的 Bundle.module
        // 这会从构建目录加载
        return Bundle.module
    }
}

