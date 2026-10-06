import ActivityKit
import Foundation

@available(iOS 16.2, *)
struct MedCasesTimerAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var end: Date
        var status: String
        var remaining: Int
        var isEs: Bool
    }
    var timerId: String
}

@available(iOS 16.2, *)
struct MedCasesRecordingAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var startedAt: Date
        var elapsedSeconds: Int
        var status: String
        var isEs: Bool
    }
    var recordingId: String
}
