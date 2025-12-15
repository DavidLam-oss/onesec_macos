//
//  DatabaseService.swift
//  OnesecCore
//
//  Created by 王晓雨 on 2025/12/15.
//

import Foundation
import SQLite

// MARK: - Database Error

enum DatabaseError: Error {
    case notInitialized
    case operationFailed(String)
}

// MARK: - Database Service

final class DatabaseService {
    static let shared = DatabaseService()

    private var db: Connection?
    private let queue = DispatchQueue(label: "com.onesec.database", qos: .userInitiated)

    // Tables
    private let audios = Table("audios")

    // Columns
    private let id = Expression<String>("id")
    private let sessionID = Expression<String>("session_id")
    private let createdAt = Expression<Int64>("created_at")
    private let filename = Expression<String>("filename")
    private let error = Expression<String?>("error")
    private let content = Expression<String?>("content")

    private init() {}

    // MARK: - Initialization

    func initialize() throws {
        guard let dbURL = UserConfigService.shared.databaseDirectory else {
            throw DatabaseError.operationFailed("Database directory not available")
        }

        try queue.sync {
            db = try Connection(dbURL.path)
            try createTables()
            log.info("Database initialized at: \(dbURL.path)")
        }
    }

    private func createTables() throws {
        guard let db = db else {
            throw DatabaseError.notInitialized
        }

        try db.run(audios.create(ifNotExists: true) { t in
            t.column(id, primaryKey: true)
            t.column(sessionID)
            t.column(createdAt)
            t.column(filename)
            t.column(content)
            t.column(error)
        })

        try db.run(audios.createIndex(createdAt, ifNotExists: true))
        try db.run(audios.createIndex(sessionID, ifNotExists: true))

        log.info("Database tables created successfully")
    }

    // MARK: - Recording Operations

    func saveAudios(sessionID: String, filename: String, content: String? = nil, error: String? = nil) throws {
        guard let db = db else {
            throw DatabaseError.notInitialized
        }

        try queue.sync {
            let insert = audios.insert(
                self.id <- UUID().uuidString,
                self.sessionID <- sessionID,
                createdAt <- Int64(Date().timeIntervalSince1970),
                self.filename <- filename,
                self.content <- content,
                self.error <- error
            )
            try db.run(insert)
            log.info("Audio saved to file: \(filename)")
        }
    }

    func getAudios(id: String) throws -> Audios? {
        guard let db = db else {
            throw DatabaseError.notInitialized
        }

        return try queue.sync {
            let query = audios.filter(self.id == id)
            guard let row = try db.pluck(query) else {
                return nil
            }

            return Audios(
                id: row[self.id],
                sessionID: row[self.sessionID],
                createdAt: Date(timeIntervalSince1970: TimeInterval(row[createdAt])),
                filename: row[filename],
                error: row[error],
                content: row[content]
            )
        }
    }

    func getAllAudios(limit: Int? = nil, offset: Int = 0) throws -> [Audios] {
        guard let db = db else {
            throw DatabaseError.notInitialized
        }

        return try queue.sync {
            var query = audios.order(createdAt.desc)

            if let limit = limit {
                query = query.limit(limit, offset: offset)
            }

            return try db.prepare(query).map { row in
                Audios(
                    id: row[self.id],
                    sessionID: row[self.sessionID],
                    createdAt: Date(timeIntervalSince1970: TimeInterval(row[createdAt])),
                    filename: row[filename],
                    error: row[error],
                    content: row[content]
                )
            }
        }
    }

    func deleteAudios(id: String) throws {
        guard let db = db else {
            throw DatabaseError.notInitialized
        }

        try queue.sync {
            let recording = audios.filter(self.id == id)
            let deleted = try db.run(recording.delete())

            if deleted > 0 {
                log.info("Recording deleted: \(id)")
            } else {
                log.warning("Recording not found: \(id)")
            }
        }
    }

    func updateAudios(id: String, error: String? = nil, content: String? = nil) throws {
        guard let db = db else {
            throw DatabaseError.notInitialized
        }

        try queue.sync {
            let recording = audios.filter(self.id == id)
            var setters: [Setter] = []

            if let error = error {
                setters.append(self.error <- error)
            }
            if let content = content {
                setters.append(self.content <- content)
            }

            guard !setters.isEmpty else {
                log.warning("No fields to update for: \(id)")
                return
            }

            let updated = try db.run(recording.update(setters))

            if updated > 0 {
                log.info("Recording updated: \(id)")
            } else {
                log.warning("Recording not found: \(id)")
            }
        }
    }

    func getAudiosCount() throws -> Int {
        guard let db = db else {
            throw DatabaseError.notInitialized
        }

        return try queue.sync {
            try db.scalar(audios.count)
        }
    }

    func clearAllAudios() throws {
        guard let db = db else {
            throw DatabaseError.notInitialized
        }

        try queue.sync {
            try db.run(audios.delete())
            log.info("All recordings cleared")
        }
    }

    // MARK: - Query by SessionID

    func getAudiosBySession(sessionID: String) throws -> [Audios] {
        guard let db = db else {
            throw DatabaseError.notInitialized
        }

        return try queue.sync {
            let query = audios.filter(self.sessionID == sessionID).order(createdAt.desc)
            return try db.prepare(query).map { row in
                Audios(
                    id: row[self.id],
                    sessionID: row[self.sessionID],
                    createdAt: Date(timeIntervalSince1970: TimeInterval(row[createdAt])),
                    filename: row[filename],
                    error: row[error],
                    content: row[content]
                )
            }
        }
    }

    func deleteAudiosBySession(sessionID: String) throws {
        guard let db = db else {
            throw DatabaseError.notInitialized
        }

        try queue.sync {
            let recordings = audios.filter(self.sessionID == sessionID)
            let deleted = try db.run(recordings.delete())

            if deleted > 0 {
                log.info("Deleted \(deleted) recordings for session: \(sessionID)")
            } else {
                log.warning("No recordings found for session: \(sessionID)")
            }
        }
    }
}

// MARK: - Data Models

struct Audios: Codable, Identifiable {
    let id: String
    let sessionID: String
    let createdAt: Date
    let filename: String
    let error: String?
    let content: String?

    var asDictionary: [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "session_id": sessionID,
            "created_at": Int(createdAt.timeIntervalSince1970),
            "filename": filename,
        ]
        if let error = error {
            dict["error"] = error
        }
        if let content = content {
            dict["content"] = content
        }
        return dict
    }
}
