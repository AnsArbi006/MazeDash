import Foundation
import CoreGraphics

enum FlowRating {
    case perfect
    case good
    case ok
    case penalty
}

struct FlowEvent {
    let value: CGFloat
    let delta: CGFloat
    let triggered: Bool
    let pointsGained: Int
}

final class FlowProgress {
    static let shared = FlowProgress()
    private let storageKey = "neonFlowPoints"
    private(set) var totalPoints: Int

    private init() {
        totalPoints = UserDefaults.standard.integer(forKey: storageKey)
    }

    func addPoints(_ points: Int) {
        guard points != 0 else { return }
        totalPoints = max(0, totalPoints + points)
        UserDefaults.standard.set(totalPoints, forKey: storageKey)
    }
}

final class FlowSystem {
    private(set) var value: CGFloat = 0
    private(set) var pointsThisRun: Int = 0
    private var lastEventTime: TimeInterval?

    private let perfectGain: CGFloat = 0.32
    private let goodGain: CGFloat = 0.2
    private let okGain: CGFloat = 0.08
    private let penaltyLoss: CGFloat = 0.18
    private let decayPerSecond: CGFloat = 0.05

    func resetRun() {
        value = 0
        pointsThisRun = 0
        lastEventTime = nil
    }

    func apply(rating: FlowRating, now: TimeInterval) -> FlowEvent {
        let previous = value
        lastEventTime = now

        switch rating {
        case .perfect:
            value += perfectGain
        case .good:
            value += goodGain
        case .ok:
            value += okGain
        case .penalty:
            value = max(0, value - penaltyLoss)
        }

        var triggered = false
        var pointsGained = 0
        while value >= 1.0 {
            value -= 1.0
            pointsGained += 1
            triggered = true
        }

        if pointsGained > 0 {
            pointsThisRun += pointsGained
            FlowProgress.shared.addPoints(pointsGained)
        }

        return FlowEvent(value: value, delta: value - previous, triggered: triggered, pointsGained: pointsGained)
    }

    func tick(now: TimeInterval) -> FlowEvent? {
        guard let last = lastEventTime else { return nil }
        let dt = now - last
        guard dt > 0 else { return nil }
        let previous = value
        value = max(0, value - CGFloat(dt) * decayPerSecond)
        lastEventTime = now
        guard abs(value - previous) > 0.0001 else { return nil }
        return FlowEvent(value: value, delta: value - previous, triggered: false, pointsGained: 0)
    }

    var totalPoints: Int {
        FlowProgress.shared.totalPoints
    }
}
