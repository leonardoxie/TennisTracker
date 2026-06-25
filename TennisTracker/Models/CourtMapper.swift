import Foundation
import SwiftUI
import CoreGraphics

/// Maps normalized camera coordinates to court positions
class CourtCoordinateSystem {
    
    // MARK: - Configuration
    
    /// Perspective correction parameters
    struct PerspectiveConfig {
        var topCompression: CGFloat = 0.6    // How much the far end is compressed
        var bottomExpansion: CGFloat = 1.2   // How much the near end is expanded
        var horizonY: CGFloat = 0.4          // Where the horizon/vanishing point is
        var xOffset: CGFloat = 0.0           // Horizontal offset
        var yOffset: CGFloat = 0.0           // Vertical offset
    }
    
    var perspective: PerspectiveConfig = PerspectiveConfig()
    
    // Standard court dimensions (meters)
    static let courtLength: CGFloat = 23.77   // Baseline to baseline (doubles)
    static let courtWidth: CGFloat = 10.97    // Doubles sideline to sideline
    static let singlesWidth: CGFloat = 8.23   // Singles sideline to sideline
    static let serviceLineDistance: CGFloat = 6.40  // Net to service line
    
    // MARK: - Coordinate Mapping
    
    /// Maps a normalized point (0-1 in camera space) to a court-space point (0-1)
    /// where 0,0 is top-left from player perspective (far baseline, left sideline)
    func mapToCourt(normalizedPoint: CGPoint) -> CGPoint {
        let x = normalizedPoint.x
        let y = normalizedPoint.y
        
        // Apply simple perspective correction
        // Near the camera (high y values in normalized space), points are more spread out
        // Far from camera (low y values), points are compressed
        let perspectiveFactor = 1.0 + (y - perspective.horizonY) * 0.3
        let correctedX = 0.5 + (x - 0.5) * perspectiveFactor + perspective.xOffset
        let correctedY = y + perspective.yOffset
        
        // Clamp to 0-1
        return CGPoint(
            x: max(0, min(1, correctedX)),
            y: max(0, min(1, correctedY))
        )
    }
    
    /// Classifies a court-space point into zones
    func getCourtZone(point: CGPoint) -> CourtZone {
        // Deep vs Short: Y axis
        // In camera view, top (low Y) = far baseline, bottom (high Y) = near
        if point.y > 0.7 {
            return .deep
        } else if point.y < 0.3 {
            return .short
        }
        
        // Wide vs Center: X axis
        if point.x < 0.2 || point.x > 0.8 {
            return .wide
        }
        
        // If center
        if point.x >= 0.35 && point.x <= 0.65 {
            return .center
        }
        
        // Default
        return .crossCourt
    }
    
    /// Maps camera coordinate to a specific zone with context
    func classifyHit(normalizedPoint: CGPoint, velocity: CGPoint) -> (zone: CourtZone, hitType: HitType) {
        let courtPoint = mapToCourt(normalizedPoint: normalizedPoint)
        let zone = getCourtZone(point: courtPoint)
        
        // Heuristic hit type classification based on direction
        let angle = atan2(velocity.y, velocity.x) * 180 / .pi
        let hitType: HitType
        
        // Serve: ball moving upward (negative y velocity in normalized space) and high speed
        if angle < -60 && angle > -120 {
            hitType = .serve
        }
        // Volley: ball near the net (middle Y) and moving forward
        else if courtPoint.y > 0.35 && courtPoint.y < 0.65 {
            hitType = .volley
        }
        // Forehand vs Backhand: based on X position and velocity direction
        else if velocity.x > 0 {
            hitType = .forehand
        } else {
            hitType = .backhand
        }
        
        return (zone, hitType)
    }
}
