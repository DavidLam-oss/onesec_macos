//
//  UserConfig.swift
//  OnesecCore
//
//  Created by 王晓雨 on 2025/11/20.
//

import Combine
import Foundation

class UserConfigService {
    static let shared = UserConfigService()

    private let fileManager = FileManager.default
    private let configFileName = "config.json"
    private var configDirectory: URL?

    private init() {
        setupConfigDirectory()
    }

    private func setupConfigDirectory() {
        guard let appSupport = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else {
            return
        }

        configDirectory = appSupport.appendingPathComponent("com.ripplestar.miaoyan")

        if let dir = configDirectory, !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    private var configFileURL: URL? {
        configDirectory?.appendingPathComponent(configFileName)
    }

    func getLastSyncFocusJudgmentSheetTime() -> Date? {
        guard let fileURL = configFileURL,
              let data = try? Data(contentsOf: fileURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let timestamp = json["lastSyncFocusJudgmentSheetTime"] as? TimeInterval
        else {
            return nil
        }
        return Date(timeIntervalSince1970: timestamp)
    }

    func setLastSyncFocusJudgmentSheetTime(_ date: Date) {
        guard let fileURL = configFileURL else { return }

        var json: [String: Any] = [:]
        if let data = try? Data(contentsOf: fileURL),
           let existingJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        {
            json = existingJson
        }

        json["lastSyncFocusJudgmentSheetTime"] = date.timeIntervalSince1970

        if let data = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) {
            try? data.write(to: fileURL)
        }
    }

    func saveData(_ data: Any, filename: String) {
        guard let dir = configDirectory else { return }

        let fileURL = dir.appendingPathComponent(filename)

        if let jsonData = try? JSONSerialization.data(withJSONObject: data, options: .prettyPrinted) {
            try? jsonData.write(to: fileURL)
            log.info("Saved \(filename)")
        }
    }
}
