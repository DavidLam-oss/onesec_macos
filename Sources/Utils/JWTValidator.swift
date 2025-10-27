//
//  JWTValidator.swift
//  OnesecCore
//
//  Created by 王晓雨 on 2025/10/23.
//

import Foundation

struct JWTValidator {
    static func isValid(_ token: String) -> Bool {
        let parts = token.components(separatedBy: ".")
        return parts.count == 3 && parts.allSatisfy { !$0.isEmpty }
    }
}

