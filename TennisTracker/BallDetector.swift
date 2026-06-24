import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit
import Vision

/// Detects tennis ball using Core ML model (primary) or color-based detection (fallback)
class BallDetector {
    
    // MARK: - Types
    
    struct Detection {
        let center: CGPoint      // Normalized coordinates (0-1)
        let radius: CGFloat      // Normalized radius
        let confidence: Float    // Detection confidence 0-1
        let boundingBox: CGRect  // Normalized bounding box
        let timestamp: TimeInterval
        let classId: Int         // 0=Player, 1=Racket, 2=Tennis Ball
        let className: String
    }
    
    // MARK: - Config
    
    var confidenceThreshold: Float = 0.35
    var nmsThreshold: Float = 0.45
    var detectAllClasses: Bool = false  // true = detect all, false = ball only
    
    // MARK: - Detection Mode
    
    enum DetectionMode {
        case coreML     // Uses YOLOv8 Core ML model (best quality)
        case colorBased // Uses HSV color filtering (fallback)
    }
    
    private(set) var mode: DetectionMode = .colorBased
    private var vnModel: VNCoreMLModel?
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    
    // MARK: - Color-based detection config
    
    struct ColorRange {
        var minHue: Double, maxHue: Double
        var minSaturation: Double, maxSaturation: Double
        var minBrightness: Double, maxBrightness: Double
        
        static let `default` = ColorRange(minHue: 0.13, maxHue: 0.38, minSaturation: 0.25, maxSaturation: 1.0, minBrightness: 0.35, maxBrightness: 1.0)
        static let indoor = ColorRange(minHue: 0.10, maxHue: 0.42, minSaturation: 0.20, maxSaturation: 1.0, minBrightness: 0.30, maxBrightness: 1.0)
        static let outdoor = ColorRange(minHue: 0.15, maxHue: 0.35, minSaturation: 0.35, maxSaturation: 1.0, minBrightness: 0.45, maxBrightness: 1.0)
    }
    var colorRange: ColorRange = .default
    
    // MARK: - Init
    
    init() {
        loadCoreMLModel()
    }
    
    private func loadCoreMLModel() {
        // Try to load YOLOv8 Core ML model from bundle
        if let modelURL = Bundle.main.url(forResource: "YOLOv8", withExtension: "mlmodelc") {
            loadModel(from: modelURL)
        } else if let modelURL = Bundle.main.url(forResource: "TennisDetector", withExtension: "mlmodelc") {
            loadModel(from: modelURL)
        } else if let modelURL = Bundle.main.url(forResource: "YOLOv8", withExtension: "mlmodel") {
            loadModel(from: modelURL)
        } else if let modelURL = Bundle.main.url(forResource: "TennisDetector", withExtension: "mlmodel") {
            loadModel(from: modelURL)
        } else {
            print("⚠️ No Core ML model found, using color-based detection")
            mode = .colorBased
        }
    }
    
    private func loadModel(from url: URL) {
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .all  // Use Neural Engine if available
            let mlModel = try MLModel(contentsOf: url, configuration: config)
            vnModel = try VNCoreMLModel(for: mlModel)
            mode = .coreML
            print("✅ Core ML model loaded: \(url.lastPathComponent)")
        } catch {
            print("❌ Failed to load Core ML model: \(error)")
            mode = .colorBased
        }
    }
    
    // MARK: - Public API
    
    func detect(in pixelBuffer: CVPixelBuffer, timestamp: TimeInterval) -> [Detection] {
        switch mode {
        case .coreML:
            return detectWithCoreML(in: pixelBuffer, timestamp: timestamp)
        case .colorBased:
            return detectWithColor(in: pixelBuffer, timestamp: timestamp)
        }
    }
    
    // MARK: - Core ML Detection
    
    private func detectWithCoreML(in pixelBuffer: CVPixelBuffer, timestamp: TimeInterval) -> [Detection] {
        guard let vnModel = vnModel else { return [] }
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let imageWidth = ciImage.extent.width
        let imageHeight = ciImage.extent.height
        
        let request = VNCoreMLRequest(model: vnModel)
        request.imageCropAndScaleOption = .scaleFill
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        
        do {
            try handler.perform([request])
        } catch {
            print("Vision request error: \(error)")
            return []
        }
        
        guard let results = request.results as? [VNRecognizedObjectObservation] else {
            return []
        }
        
        var detections: [Detection] = []
        
        for obs in results {
            guard let topLabel = obs.labels.first else { continue }
            
            let classId = classIdFromLabel(topLabel.identifier)
            
            // Filter by target class if not detecting all
            if !detectAllClasses && classId != 2 { continue } // 2 = Tennis Ball
            
            let confidence = topLabel.confidence
            guard confidence >= confidenceThreshold else { continue }
            
            // VNRecognizedObjectObservation.bbox is normalized [0,1], origin = bottom-left
            let bbox = obs.boundingBox
            let centerX = bbox.origin.x + bbox.width / 2
            let centerY = bbox.origin.y + bbox.height / 2
            let radius = max(bbox.width, bbox.height) / 2
            
            detections.append(Detection(
                center: CGPoint(x: centerX, y: centerY),
                radius: radius,
                confidence: confidence,
                boundingBox: CGRect(
                    x: bbox.origin.x,
                    y: bbox.origin.y,
                    width: bbox.width,
                    height: bbox.height
                ),
                timestamp: timestamp,
                classId: classId,
                className: classNameForId(classId)
            ))
        }
        
        // NMS
        return applyNMS(detections)
    }
    
    private func classIdFromLabel(_ label: String) -> Int {
        let lower = label.lowercased()
        if lower.contains("ball") || lower.contains("tennis") { return 2 }
        if lower.contains("racket") || lower.contains("racquet") { return 1 }
        if lower.contains("player") || lower.contains("person") { return 0 }
        // COCO class mapping: sports ball = 32 → map to our class 2
        if lower.contains("sports") { return 2 }
        return 0
    }
    
    private func classNameForId(_ id: Int) -> String {
        switch id {
        case 0: return "Player"
        case 1: return "Racket"
        case 2: return "Tennis Ball"
        default: return "Unknown"
        }
    }
    
    // MARK: - Color-based Detection (Fallback)
    
    private func detectWithColor(in pixelBuffer: CVPixelBuffer, timestamp: TimeInterval) -> [Detection] {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        guard let filtered = applyColorFilter(to: ciImage) else { return [] }
        guard let detection = findBall(in: filtered, originalSize: ciImage.extent.size, timestamp: timestamp) else {
            return []
        }
        
        return [detection]
    }
    
    private func applyColorFilter(to image: CIImage) -> CIImage? {
        let blur = CIFilter.gaussianBlur()
        blur.inputImage = image
        blur.radius = 2
        guard let blurred = blur.outputImage else { return nil }
        
        let kernel = CIColorKernel(source: """
            kernel vec4 colorThreshold(__sample image, float minH, float maxH, float minS, float maxS, float minB, float maxB) {
                float r = image.r, g = image.g, b = image.b;
                float maxC = max(r, max(g, b)), minC = min(r, min(g, b)), delta = maxC - minC;
                float h = 0.0, s = maxC > 0.0 ? delta / maxC : 0.0, v = maxC;
                if (delta > 0.0) {
                    if (maxC == r) h = 60.0 * mod((g - b) / delta, 6.0);
                    else if (maxC == g) h = 60.0 * ((b - r) / delta + 2.0);
                    else h = 60.0 * ((r - g) / delta + 4.0);
                    if (h < 0.0) h += 360.0;
                }
                h = h / 360.0;
                if (h >= minH && h <= maxH && s >= minS && s <= maxS && v >= minB && v <= maxB) {
                    return vec4(1.0, 1.0, 1.0, 1.0);
                } else {
                    return vec4(0.0, 0.0, 0.0, 1.0);
                }
            }
            """)
        guard let colorKernel = kernel else { return nil }
        return colorKernel.apply(extent: image.extent, arguments: [blurred, colorRange.minHue, colorRange.maxHue, colorRange.minSaturation, colorRange.maxSaturation, colorRange.minBrightness, colorRange.maxBrightness])
    }
    
    private func findBall(in filteredImage: CIImage, originalSize: CGSize, timestamp: TimeInterval) -> Detection? {
        guard let cgImage = ciContext.createCGImage(filteredImage, from: filteredImage.extent) else { return nil }
        let width = cgImage.width, height = cgImage.height
        let bytesPerRow = cgImage.bytesPerRow, bitsPerPixel = cgImage.bitsPerPixel
        guard let dataProvider = cgImage.dataProvider, let data = dataProvider.data else { return nil }
        let buffer = CFDataGetBytePtr(data)!
        let bytesPerPixel = bitsPerPixel / 8
        
        var sumX: CGFloat = 0, sumY: CGFloat = 0, count: Int = 0
        var minX = width, maxX = 0, minY = height, maxY = 0
        let step = 2
        
        for y in stride(from: 0, to: height, by: step) {
            for x in stride(from: 0, to: width, by: step) {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let brightness = (Int(buffer[offset]) + Int(buffer[offset + 1]) + Int(buffer[offset + 2])) / 3
                if brightness > 200 {
                    sumX += CGFloat(x); sumY += CGFloat(y); count += 1
                    if x < minX { minX = x }; if x > maxX { maxX = x }
                    if y < minY { minY = y }; if y > maxY { maxY = y }
                }
            }
        }
        
        guard count >= 30 else { return nil }
        let centerX = sumX / CGFloat(count), centerY = sumY / CGFloat(count)
        let bboxW = CGFloat(maxX - minX), bboxH = CGFloat(maxY - minY)
        let radius = max(bboxW, bboxH) / 2
        let normCenter = CGPoint(x: centerX / CGFloat(width), y: 1.0 - centerY / CGFloat(height))
        let normRadius = radius / CGFloat(width)
        guard normRadius >= 0.005 && normRadius <= 0.08 else { return nil }
        
        let bbox = CGRect(x: CGFloat(minX) / CGFloat(width), y: 1.0 - CGFloat(maxY) / CGFloat(height), width: bboxW / CGFloat(width), height: bboxH / CGFloat(height))
        
        return Detection(center: normCenter, radius: normRadius, confidence: 0.7, boundingBox: bbox, timestamp: timestamp, classId: 2, className: "Tennis Ball")
    }
    
    // MARK: - NMS
    
    private func applyNMS(_ detections: [Detection]) -> [Detection] {
        let sorted = detections.sorted { $0.confidence > $1.confidence }
        var kept: [Detection] = []
        var suppressed = Set<Int>()
        
        for i in 0..<sorted.count {
            if suppressed.contains(i) { continue }
            kept.append(sorted[i])
            for j in (i + 1)..<sorted.count {
                if suppressed.contains(j) || sorted[i].classId != sorted[j].classId { continue }
                if calculateIoU(sorted[i].boundingBox, sorted[j].boundingBox) > nmsThreshold {
                    suppressed.insert(j)
                }
            }
        }
        return kept
    }
    
    private func calculateIoU(_ a: CGRect, _ b: CGRect) -> Float {
        let inter = a.intersection(b)
        guard !inter.isEmpty else { return 0 }
        let interArea = inter.width * inter.height
        let unionArea = a.width * a.height + b.width * b.height - interArea
        return Float(interArea / unionArea)
    }
}
