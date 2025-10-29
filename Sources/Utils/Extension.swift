//
//  extension.swift
//  OnesecCore
//
//  Created by 王晓雨 on 2025/10/29.
//

extension String {
    var cleaned: String {
        self.replacingOccurrences(
            of: "\\s+", with: " ", options: .regularExpression
        ).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
