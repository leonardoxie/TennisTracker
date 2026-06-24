import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit
import Vision

/// Detects tennis ball in video frames using color filtering + contour detection
class BallDetector {
    
    // Tennis ball HSV color range (bright yellow-green)
    // These values work for standard tennis balls under indoor lighting
    struct ColorRange {
        var minHue: Double        // 0.15 ≈ yellow-green
        var maxHue: Double        // 0.40 ≈ green
        var minSaturation: Double // 0.30 minimum saturation
        var maxSaturation: Double // 1.00
        var minBrightness: Double // 0.40 minimum brightness
        var maxBrightness: Double // 1.00
        
        static let `default` = ColorRange(
            minHue: 0.13, maxHue: 0.38,
            minSaturation: 0.25, maxSaturation: 1.0,
            minBrightness: 0.35, maxBrightness: 1.0
        )
        
        // Indoor lighting (warmer, less green)
        static let indoor = ColorRange(
            minHue: 0.10, maxHue: 0.42,
            minSaturation: 0.20, maxSaturation: 1.0,
            minBrightness: 0.30, maxBrightness: 1.0
        )
        
        // Outdoor (brighter, more contrast)
        static let outdoor = ColorRange(
            minHue: 0.15, maxHue: 0.35,
            minSaturation: 0.35, maxSaturation: 1.0,
            minBrightness: 0.45, maxBrightness: 1.0
        )
    }
    
    struct Detection {
        let center: CGPoint      // Normalized coordinates (0-1)
        let radius: CGFloat      // Normalized radius
        let confidence: Float    // Detection confidence 0-1
        let boundingBox: CGRect  // Normalized bounding box
        let timestamp: TimeInterval
    }
    
    var colorRange: ColorRange = .default
    var minBallRadius: CGFloat = 0.005  // Minimum radius as fraction of frame
    var maxBallRadius: CGFloat = 0.08   // Maximum radius as fraction of frame
    
    private let ciContext = CIContext()
    
    // MARK: - Public API
    
    /// Detect tennis ball in a pixel buffer
    func detect(in pixelBuffer: CVPixelBuffer, timestamp: TimeInterval) -> Detection? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        // Step 1: Color filter to isolate yellow-green
        guard let filtered = applyColorFilter(to: ciImage) else { return nil }
        
        // Step 2: Find contours/blobs
        guard let detection = findBall(in: filtered, originalSize: ciImage.extent.size, timestamp: timestamp) else {
            return nil
        }
        
        return detection
    }
    
    // MARK: - Color Filtering
    
    private func applyColorFilter(to image: CIImage) -> CIImage? {
        // Convert to HSV-like filtering using CIColorMatrix + threshold
        // CIKernel approach for better performance
        
        // Step 1: Apply slight blur to reduce noise
        let blur = CIFilter.gaussianBlur()
        blur.inputImage = image
        blur.radius = 2
        
        guard let blurred = blur.outputImage else { return nil }
        
        // Step 2: Color threshold using custom kernel
        // This filters for yellow-green colors (tennis ball)
        let kernel = CIColorKernel(source: """
            kernel vec4 colorThreshold(__sample image, float minH, float maxH, float minS, float maxS, float minB, float maxB) {
                float r = image.r;
                float g = image.g;
                float b = image.b;
                
                // RGB to HSV
                float maxC = max(r, max(g, b));
                float minC = min(r, min(g, b));
                float delta = maxC - minC;
                
                float h = 0.0;
                float s = maxC > 0.0 ? delta / maxC : 0.0;
                float v = maxC;
                
                if (delta > 0.0) {
                    if (maxC == r) {
                        h = 60.0 * mod((g - b) / delta, 6.0);
                    } else if (maxC == g) {
                        h = 60.0 * ((b - r) / delta + 2.0);
                    } else {
                        h = 60.0 * ((r - g) / delta + 4.0);
                    }
                    if (h < 0.0) h += 360.0;
                }
                
                // Normalize H to 0-1
                h = h / 360.0;
                
                // Check if color is in range
                if (h >= minH && h <= maxH && s >= minS && s <= maxS && v >= minB && v <= maxB) {
                    return vec4(1.0, 1.0, 1.0, 1.0); // White = ball pixel
                } else {
                    return vec4(0.0, 0.0, 0.0, 1.0); // Black = not ball
                }
            }
            """)
        
        guard let colorKernel = kernel else { return nil }
        
        let filtered = colorKernel.apply(
            extent: image.extent,
            arguments: [
                blurred,
                colorRange.minHue,
                colorRange.maxHue,
                colorRange.minSaturation,
                colorRange.maxSaturation,
                colorRange.minBrightness,
                colorRange.maxBrightness
            ]
        )
        
        return filtered
    }
    
    // MARK: - Ball Detection (Contour Analysis)
    
    private func findBall(in filteredImage: CIImage, originalSize: CGSize, timestamp: TimeInterval) -> Detection? {
        // Render filtered image to a bitmap for analysis
        guard let cgImage = ciContext.createCGImage(filteredImage, from: filteredImage.extent) else {
            return nil
        }
        
        // Analyze the binary image to find the ball
        // We look for a cluster of white pixels that forms a roughly circular shape
        
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = cgImage.bytesPerRow
        let bitsPerPixel = cgImage.bitsPerPixel
        
        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data else { return nil }
        
        let buffer = CFDataGetBytePtr(data)!
        let bytesPerPixel = bitsPerPixel / 8
        
        // Accumulate white pixel positions
        var sumX: CGFloat = 0
        var sumY: CGFloat = 0
        var count: Int = 0
        var minX = width, maxX = 0, minY = height, maxY = 0
        
        // Sample every 2nd pixel for speed
        let step = 2
        for y in stride(from: 0, to: height, by: step) {
            for x in stride(from: 0, to: width, by: step) {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let r = buffer[offset]
                let g = buffer[offset + 1]
                let b = buffer[offset + 2]
                
                // Check if pixel is white (ball) — threshold for brightness
                let brightness = (Int(r) + Int(g) + Int(b)) / 3
                if brightness > 200 {
                    sumX += CGFloat(x)
                    sumY += CGFloat(y)
                    count += 1
                    if x < minX { minX = x }
                    if x > maxX { maxX = x }
                    if y < minY { minY = y }
                    if y > maxY { maxY = y }
                }
            }
        }
        
        // Need minimum number of pixels to be a ball
        let minPixels = 30
        guard count >= minPixels else { return nil }
        
        // Calculate center of mass
        let centerX = sumX / CGFloat(count)
        let centerY = sumY / CGFloat(count)
        
        // Calculate approximate radius from bounding box
        let bboxWidth = CGFloat(maxX - minX)
        let bboxHeight = CGFloat(maxY - minY)
        let radius = max(bboxWidth, bboxHeight) / 2
        
        // Normalize coordinates
        let normalizedCenter = CGPoint(
            x: centerX / CGFloat(width),
            y: 1.0 - centerY / CGFloat(height) // Flip Y for SwiftUI coordinates
        )
        let normalizedRadius = radius / CGFloat(width)
        
        // Size sanity check
        guard normalizedRadius >= minBallRadius && normalizedRadius <= maxBallRadius else {
            return nil
        }
        
        // Calculate confidence based on roundness and pixel density
        let expectedArea = CGFloat.pi * radius * radius
        let actualArea = CGFloat(count) * 4 // *4 because we sample every 2nd pixel in both dims
        let roundness = min(actualArea, expectedArea) / max(actualArea, expectedArea)
        let density = Float(count) / Float(width * height / (step * step))
        let confidence = min(1.0, Float(roundness) * 0.7 + min(density * 50, 0.3))
        
        // Bounding box (normalized)
        let bbox = CGRect(
            x: CGFloat(minX) / CGFloat(width),
            y: 1.0 - CGFloat(maxY) / CGFloat(height),
            width: bboxWidth / CGFloat(width),
            height: bboxHeight / CGFloat(height)
        )
        
        return Detection(
            center: normalizedCenter,
            radius: normalizedRadius,
            confidence: confidence,
            boundingBox: bbox,
            timestamp: timestamp
        )
    }
}
