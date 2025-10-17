//
//  ServerValidator.swift
//  OnesecCore
//
//  Created by 王晓雨 on 2025/10/17.
//

import Foundation

enum ServerValidator {
    /// 验证服务器地址是否合法
    /// - Parameter server: 服务器地址，格式: "example.com:443" 或 "192.168.1.1:8080"
    /// - Returns: 是否合法
    static func isValid(_ server: String) -> Bool {
        // 分割主机和端口
        let components = server.split(separator: ":")
        
        guard components.count <= 2 else {
            return false // 超过一个冒号
        }
        
        let host = String(components[0])
        
        // 验证主机部分
        guard isValidHost(host) else {
            return false
        }
        
        // 如果有端口，验证端口
        if components.count == 2 {
            guard let port = Int(components[1]),
                  port > 0,
                  port <= 65535
            else {
                return false
            }
        }
        
        return true
    }
    
    /// 验证主机名（域名或IP）
    private static func isValidHost(_ host: String) -> Bool {
        isValidDomain(host) || isValidIPAddress(host)
    }
    
    /// 验证域名
    private static func isValidDomain(_ domain: String) -> Bool {
        // 域名规则：
        // - 长度 1-253 字符
        // - 只包含字母、数字、连字符和点
        // - 不能以连字符开头或结尾
        // - 标签（点之间的部分）长度 1-63 字符
        let domainPattern = #"^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)*[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?$"#
        
        guard domain.count <= 253,
              domain.range(of: domainPattern, options: .regularExpression) != nil
        else {
            return false
        }
        
        // 检查每个标签长度
        let labels = domain.split(separator: ".")
        return labels.allSatisfy { $0.count <= 63 }
    }
    
    /// 验证 IPv4 地址
    private static func isValidIPAddress(_ ip: String) -> Bool {
        let parts = ip.split(separator: ".")
        
        guard parts.count == 4 else {
            return false
        }
        
        return parts.allSatisfy { part in
            guard let num = Int(part),
                  num >= 0,
                  num <= 255,
                  String(num) == part
            else { // 防止前导零，如 "01"
                return false
            }
            return true
        }
    }
    
    /// 从服务器字符串中提取主机和端口
    static func parse(_ server: String) -> (host: String, port: Int?)? {
        guard isValid(server) else {
            return nil
        }
        
        let components = server.split(separator: ":")
        let host = String(components[0])
        let port = components.count == 2 ? Int(components[1]) : nil
        
        return (host, port)
    }
}
