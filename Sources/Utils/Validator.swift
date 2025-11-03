//
//  Validator.swift
//  OnesecCore
//
//  Created by 王晓雨 on 2025/10/23.
//

import Foundation

enum JWTValidator {
    static func isValid(_ token: String) -> Bool {
        let parts = token.components(separatedBy: ".")
        return parts.count == 3 && parts.allSatisfy { !$0.isEmpty }
    }
}

enum ServerValidator {
    private static let maxDomainLength = 253
    private static let maxLabelLength = 63
    private static let minPort = 1
    private static let maxPort = 65535
    private static let ipv4ComponentCount = 4
    private static let maxIPv4Value = 255

    private static let domainPattern = #"^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)*[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?$"#

    /// 验证服务器地址格式: "example.com:443" 或 "192.168.1.1:8080"
    static func isValid(_ server: String) -> Bool {
        let components = server.split(separator: ":")
        guard components.count <= 2 else { return false }

        let host = String(components[0])
        guard isValidHost(host) else { return false }

        if components.count == 2 {
            guard let port = Int(components[1]),
                  (minPort ... maxPort).contains(port)
            else {
                return false
            }
        }

        return true
    }

    /// 解析服务器地址为主机和端口
    static func parse(_ server: String) -> (host: String, port: Int?)? {
        guard isValid(server) else { return nil }

        let components = server.split(separator: ":")
        let host = String(components[0])
        let port = components.count == 2 ? Int(components[1]) : nil

        return (host, port)
    }

    private static func isValidHost(_ host: String) -> Bool {
        isValidDomain(host) || isValidIPv4(host)
    }

    private static func isValidDomain(_ domain: String) -> Bool {
        guard domain.count <= maxDomainLength,
              domain.range(of: domainPattern, options: .regularExpression) != nil
        else {
            return false
        }

        return domain.split(separator: ".").allSatisfy { $0.count <= maxLabelLength }
    }

    private static func isValidIPv4(_ ip: String) -> Bool {
        let parts = ip.split(separator: ".")
        guard parts.count == ipv4ComponentCount else { return false }

        return parts.allSatisfy { part in
            guard let num = Int(part),
                  (0 ... maxIPv4Value).contains(num),
                  String(num) == part
            else {
                return false
            }
            return true
        }
    }
}
