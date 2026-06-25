import Foundation
import SwiftUI

// MARK: - Hit Type

enum HitType: String, Codable, CaseIterable, Identifiable {
    case forehand = "正手"
    case backhand = "反手"
    case serve = "发球"
    case volley = "截击"
    case unknown = "未知"
    
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .forehand: return "figure.tennis"
        case .backhand: return "figure.tennis"
        case .serve: return "arrow.up.circle.fill"
        case .volley: return "hand.raised.fill"
        case .unknown: return "questionmark.circle"
        }
    }
    var color: Color {
        switch self {
        case .forehand: return Color(red: 0.78, green: 0.90, blue: 0.20)
        case .backhand: return .blue
        case .serve: return .orange
        case .volley: return .purple
        case .unknown: return .gray
        }
    }
}

// MARK: - Court Zone

enum CourtZone: String, Codable, CaseIterable, Identifiable {
    case crossCourt = "斜线"
    case downTheLine = "直线"
    case deep = "深球"
    case short = "短球"
    case wide = "大角度"
    case center = "中路"
    
    var id: String { rawValue }
    
    var color: Color {
        switch self {
        case .crossCourt: return .blue
        case .downTheLine: return .green
        case .deep: return .orange
        case .short: return .red
        case .wide: return .purple
        case .center: return .cyan
        }
    }
}

// MARK: - Hit Event Record

struct HitEventRecord: Codable, Identifiable {
    let id: UUID
    let position: CGPoint
    let speed: Double        // km/h
    let direction: Double    // degrees
    let timestamp: TimeInterval
    let hitType: HitType
    
    init(id: UUID = UUID(), position: CGPoint, speed: Double, direction: Double, timestamp: TimeInterval, hitType: HitType = .unknown) {
        self.id = id
        self.position = position
        self.speed = speed
        self.direction = direction
        self.timestamp = timestamp
        self.hitType = hitType
    }
}

// MARK: - Landing Point

struct LandingPoint: Codable, Identifiable {
    let id: UUID
    let position: CGPoint
    let timestamp: TimeInterval
    let speed: Double
    
    init(id: UUID = UUID(), position: CGPoint, timestamp: TimeInterval, speed: Double) {
        self.id = id
        self.position = position
        self.timestamp = timestamp
        self.speed = speed
    }
}

// MARK: - Player Position

struct PlayerPosition: Codable, Identifiable {
    let id: UUID
    let position: CGPoint
    let timestamp: TimeInterval
    
    init(id: UUID = UUID(), position: CGPoint, timestamp: TimeInterval) {
        self.id = id
        self.position = position
        self.timestamp = timestamp
    }
}

// MARK: - Session Summary

struct SessionSummary: Codable {
    var totalHits: Int = 0
    var avgSpeed: Double = 0
    var maxSpeed: Double = 0
    var forehandCount: Int = 0
    var backhandCount: Int = 0
    var serveCount: Int = 0
    var volleyCount: Int = 0
    var unknownCount: Int = 0
    var duration: TimeInterval = 0
    
    var hitTypeCounts: [HitType: Int] {
        return [
            .forehand: forehandCount,
            .backhand: backhandCount,
            .serve: serveCount,
            .volley: volleyCount,
            .unknown: unknownCount
        ]
    }
}

// MARK: - Session Record

class SessionRecord: ObservableObject, Codable, Identifiable {
    let id: UUID
    var date: Date
    var duration: TimeInterval
    var hitEvents: [HitEventRecord]
    var ballLandingPoints: [LandingPoint]
    var playerPositions: [PlayerPosition]
    var summary: SessionSummary
    
    init(id: UUID = UUID(), date: Date = Date(), duration: TimeInterval = 0, hitEvents: [HitEventRecord] = [], ballLandingPoints: [LandingPoint] = [], playerPositions: [PlayerPosition] = [], summary: SessionSummary = SessionSummary()) {
        self.id = id
        self.date = date
        self.duration = duration
        self.hitEvents = hitEvents
        self.ballLandingPoints = ballLandingPoints
        self.playerPositions = playerPositions
        self.summary = summary
    }
    
    // Codable
    enum CodingKeys: String, CodingKey {
        case id, date, duration, hitEvents, ballLandingPoints, playerPositions, summary
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        hitEvents = try container.decode([HitEventRecord].self, forKey: .hitEvents)
        ballLandingPoints = try container.decode([LandingPoint].self, forKey: .ballLandingPoints)
        playerPositions = try container.decode([PlayerPosition].self, forKey: .playerPositions)
        summary = try container.decode(SessionSummary.self, forKey: .summary)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(date, forKey: .date)
        try container.encode(duration, forKey: .duration)
        try container.encode(hitEvents, forKey: .hitEvents)
        try container.encode(ballLandingPoints, forKey: .ballLandingPoints)
        try container.encode(playerPositions, forKey: .playerPositions)
        try container.encode(summary, forKey: .summary)
    }
}

// MARK: - Court Zone Classification

extension SessionRecord {
    /// Classify a position into court zones
    static func classifyZones(for position: CGPoint, isLandingPoint: Bool = false) -> [CourtZone] {
        var zones: [CourtZone] = []
        
        // Deep vs Short (Y axis: 0=top, 1=bottom)
        // Deep = near baseline (high Y from player perspective)
        if position.y > 0.7 {
            zones.append(.deep)
        } else if position.y < 0.3 {
            zones.append(.short)
        }
        
        // Wide vs Center (X axis)
        if position.x < 0.2 || position.x > 0.8 {
            zones.append(.wide)
        } else if position.x > 0.35 && position.x < 0.65 {
            zones.append(.center)
        }
        
        // Cross-court vs Down-the-line (based on position relative to center)
        let centerOffset = abs(position.x - 0.5)
        if centerOffset > 0.2 {
            zones.append(.crossCourt)
        } else {
            zones.append(.downTheLine)
        }
        
        if zones.isEmpty {
            zones.append(.center)
        }
        
        return zones
    }
}
