import Foundation
import WatchConnectivity
import Combine

/// Manages WatchConnectivity on the iPhone side - sends session data to Apple Watch
class PhoneWatchConnector: NSObject, ObservableObject {
    static let shared = PhoneWatchConnector()
    
    @Published var isWatchConnected = false
    @Published var isWatchReachable = false
    
    private var session: WCSession?
    
    override init() {
        super.init()
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }
    
    // MARK: - Send Data to Watch
    
    func sendSessionUpdate(
        ballCount: Int,
        sessionDuration: TimeInterval,
        currentScore: Int,
        heartRate: Double,
        calories: Double,
        rallyCount: Int,
        isSessionActive: Bool
    ) {
        guard let session = session, session.isReachable else { return }
        
        let message: [String: Any] = [
            "ballCount": ballCount,
            "sessionDuration": sessionDuration,
            "currentScore": currentScore,
            "heartRate": heartRate,
            "calories": calories,
            "rallyCount": rallyCount,
            "isSessionActive": isSessionActive
        ]
        
        session.sendMessage(message, replyHandler: nil, errorHandler: { error in
            print("Phone->Watch send error: \(error.localizedDescription)")
        })
    }
    
    // MARK: - Handle Commands from Watch
    
    var onStartSession: (() -> Void)?
    var onStopSession: (() -> Void)?
}

// MARK: - WCSessionDelegate

extension PhoneWatchConnector: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isWatchConnected = activationState == .activated
            self.isWatchReachable = session.isReachable
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchReachable = session.isReachable
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async {
            if let command = message["command"] as? String {
                switch command {
                case "startSession":
                    self.onStartSession?()
                case "stopSession":
                    self.onStopSession?()
                case "requestUpdate":
                    break // Will be handled by the app
                default:
                    break
                }
            }
        }
    }
}
