import Foundation
import WatchConnectivity
import Combine

/// Manages WatchConnectivity session between iPhone and Apple Watch
class WatchSessionManager: NSObject, ObservableObject {
    static let shared = WatchSessionManager()
    
    @Published var isConnected = false
    @Published var isSessionActive = false
    @Published var ballCount: Int = 0
    @Published var sessionDuration: TimeInterval = 0
    @Published var currentScore: Int = 0
    @Published var heartRate: Double = 0
    @Published var calories: Double = 0
    @Published var rallyCount: Int = 0
    @Published var lastUpdate: Date = Date()
    
    private var session: WCSession?
    private var timer: Timer?
    
    override init() {
        super.init()
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }
    
    // MARK: - Send Commands to iPhone
    
    func sendStartSession() {
        send(message: ["command": "startSession"])
        DispatchQueue.main.async {
            self.isSessionActive = true
        }
    }
    
    func sendStopSession() {
        send(message: ["command": "stopSession"])
        DispatchQueue.main.async {
            self.isSessionActive = false
        }
    }
    
    func requestDataUpdate() {
        send(message: ["command": "requestUpdate"])
    }
    
    // MARK: - Private
    
    private func send(message: [String: Any]) {
        guard let session = session, session.isReachable else { return }
        session.sendMessage(message, replyHandler: nil, errorHandler: { error in
            print("WC send error: \(error.localizedDescription)")
        })
    }
}

// MARK: - WCSessionDelegate

extension WatchSessionManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isConnected = activationState == .activated
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async {
            if let ballCount = message["ballCount"] as? Int {
                self.ballCount = ballCount
            }
            if let duration = message["sessionDuration"] as? TimeInterval {
                self.sessionDuration = duration
            }
            if let score = message["currentScore"] as? Int {
                self.currentScore = score
            }
            if let hr = message["heartRate"] as? Double {
                self.heartRate = hr
            }
            if let cal = message["calories"] as? Double {
                self.calories = cal
            }
            if let rallies = message["rallyCount"] as? Int {
                self.rallyCount = rallies
            }
            if let active = message["isSessionActive"] as? Bool {
                self.isSessionActive = active
            }
            self.lastUpdate = Date()
        }
    }
}
