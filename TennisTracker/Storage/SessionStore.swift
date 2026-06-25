import Foundation
import SwiftUI

/// Persists session data using JSON files in the app's Documents directory
class SessionStore: ObservableObject {
    @Published var sessions: [SessionRecord] = []
    
    private let fileManager = FileManager.default
    private lazy var documentsDirectory: URL = {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }()
    private lazy var sessionsDirectory: URL = {
        let dir = documentsDirectory.appendingPathComponent("Sessions", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }()
    
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = .prettyPrinted
        return e
    }()
    
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
    
    init() {
        load()
    }
    
    // MARK: - CRUD Operations
    
    func load() {
        guard let files = try? fileManager.contentsOfDirectory(at: sessionsDirectory, includingPropertiesForKeys: nil) else {
            sessions = []
            return
        }
        
        var loaded: [SessionRecord] = []
        for file in files where file.pathExtension == "json" {
            if let data = try? Data(contentsOf: file),
               let session = try? decoder.decode(SessionRecord.self, from: data) {
                loaded.append(session)
            }
        }
        
        // Sort by date descending
        sessions = loaded.sorted { $0.date > $1.date }
    }
    
    func save(_ session: SessionRecord) {
        let fileURL = sessionsDirectory.appendingPathComponent("\(session.id.uuidString).json")
        
        if let data = try? encoder.encode(session) {
            try? data.write(to: fileURL)
        }
        
        // Update in-memory list
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        } else {
            sessions.insert(session, at: 0)
        }
        
        sessions.sort { $0.date > $1.date }
    }
    
    func delete(_ session: SessionRecord) {
        let fileURL = sessionsDirectory.appendingPathComponent("\(session.id.uuidString).json")
        try? fileManager.removeItem(at: fileURL)
        sessions.removeAll { $0.id == session.id }
    }
    
    func deleteAll() {
        for session in sessions {
            let fileURL = sessionsDirectory.appendingPathComponent("\(session.id.uuidString).json")
            try? fileManager.removeItem(at: fileURL)
        }
        sessions.removeAll()
    }
    
    // MARK: - Export
    
    func exportAll() -> Data? {
        return try? encoder.encode(sessions)
    }
    
    func exportSingle(_ session: SessionRecord) -> Data? {
        return try? encoder.encode(session)
    }
    
    /// Returns a summary string for sharing
    func summaryText(for session: SessionRecord) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        let durationMins = Int(session.duration / 60)
        let durationSecs = Int(session.duration.truncatingRemainder(dividingBy: 60))
        
        return """
        🎾 TennisTracker 训练报告
        日期: \(formatter.string(from: session.date))
        时长: \(durationMins)分\(durationSecs)秒
        总击球: \(session.summary.totalHits)次
        平均速度: \(String(format: "%.0f", session.summary.avgSpeed)) km/h
        最高速度: \(String(format: "%.0f", session.summary.maxSpeed)) km/h
        正手: \(session.summary.forehandCount) | 反手: \(session.summary.backhandCount)
        发球: \(session.summary.serveCount)
        """
    }
}
