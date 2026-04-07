import Foundation

enum ComboRating {
    case perfect
    case good
    case ok
}

enum ComboSound {
    case perfect
    case good

    var sfx: SFX {
        switch self {
        case .perfect:
            return .cursor1
        case .good:
            return .select2
        }
    }
}

enum ComboMilestone {
    case hot
    case fire
    case flow

    var text: String {
        switch self {
        case .hot:
            return "HOT!"
        case .fire:
            return "FIRE!"
        case .flow:
            return "FLOW!"
        }
    }
}

struct ComboEvent {
    let combo: Int
    let delta: Int
    let rating: ComboRating?
    let milestone: ComboMilestone?
    let showRatingLabel: Bool
    let showMilestoneLabel: Bool
    let sound: ComboSound?
    let haptic: Bool
    let expired: Bool
    let penalty: Bool
}

final class ComboSystem {
    private(set) var combo: Int = 0
    private(set) var perfectStreak: Int = 0

    private var lastScoreTime: TimeInterval?
    private var lastSoundTime: TimeInterval = -10
    private var lastLabelTime: TimeInterval = -10
    private var lastHapticTime: TimeInterval = -10

    private let baseWindow: TimeInterval = 2.0
    private let minWindow: TimeInterval = 1.4
    private let decayPerCombo: TimeInterval = 0.03

    private let soundCooldown: TimeInterval = 0.06
    private let labelCooldown: TimeInterval = 0.08
    private let hapticCooldown: TimeInterval = 0.15

    func reset() {
        combo = 0
        perfectStreak = 0
        lastScoreTime = nil
        lastSoundTime = -10
        lastLabelTime = -10
        lastHapticTime = -10
    }

    func applyRating(_ rating: ComboRating, now: TimeInterval) -> ComboEvent {
        let previousCombo = combo

        switch rating {
        case .perfect:
            combo += 2
            perfectStreak += 1
        case .good:
            combo += 1
            perfectStreak = 0
        case .ok:
            perfectStreak = 0
        }

        lastScoreTime = now

        let milestone = milestoneForStreak(perfectStreak)
        let sound = soundForRating(rating, now: now)
        let haptic = rating == .perfect && shouldHaptic(now)

        let showRatingLabel = rating != .ok && shouldLabel(now)
        let showMilestoneLabel = milestone != nil

        return ComboEvent(
            combo: combo,
            delta: combo - previousCombo,
            rating: rating,
            milestone: milestone,
            showRatingLabel: showRatingLabel,
            showMilestoneLabel: showMilestoneLabel,
            sound: sound,
            haptic: haptic,
            expired: false,
            penalty: false
        )
    }

    func applyPenalty(now: TimeInterval) -> ComboEvent {
        let previousCombo = combo
        combo = max(0, combo - 2)
        perfectStreak = 0
        lastScoreTime = now
        return ComboEvent(
            combo: combo,
            delta: combo - previousCombo,
            rating: nil,
            milestone: nil,
            showRatingLabel: false,
            showMilestoneLabel: false,
            sound: nil,
            haptic: false,
            expired: false,
            penalty: true
        )
    }

    func applyBonus(amount: Int, now: TimeInterval) -> ComboEvent {
        guard amount > 0 else {
            return ComboEvent(
                combo: combo,
                delta: 0,
                rating: nil,
                milestone: nil,
                showRatingLabel: false,
                showMilestoneLabel: false,
                sound: nil,
                haptic: false,
                expired: false,
                penalty: false
            )
        }
        let previousCombo = combo
        combo += amount
        lastScoreTime = now
        return ComboEvent(
            combo: combo,
            delta: combo - previousCombo,
            rating: nil,
            milestone: nil,
            showRatingLabel: false,
            showMilestoneLabel: false,
            sound: nil,
            haptic: false,
            expired: false,
            penalty: false
        )
    }

    func tick(now: TimeInterval) -> ComboEvent? {
        guard let last = lastScoreTime else { return nil }
        if now - last > currentWindow() {
            let previousCombo = combo
            combo = 0
            perfectStreak = 0
            lastScoreTime = nil
            return ComboEvent(
                combo: 0,
                delta: 0 - previousCombo,
                rating: nil,
                milestone: nil,
                showRatingLabel: false,
                showMilestoneLabel: false,
                sound: nil,
                haptic: false,
                expired: true,
                penalty: false
            )
        }
        return nil
    }

    private func currentWindow() -> TimeInterval {
        let decay = min(TimeInterval(combo) * decayPerCombo, baseWindow - minWindow)
        return max(minWindow, baseWindow - decay)
    }

    private func soundForRating(_ rating: ComboRating, now: TimeInterval) -> ComboSound? {
        guard now - lastSoundTime >= soundCooldown else { return nil }
        switch rating {
        case .perfect:
            lastSoundTime = now
            return .perfect
        case .good:
            lastSoundTime = now
            return .good
        case .ok:
            return nil
        }
    }

    private func shouldLabel(_ now: TimeInterval) -> Bool {
        guard now - lastLabelTime >= labelCooldown else { return false }
        lastLabelTime = now
        return true
    }

    private func shouldHaptic(_ now: TimeInterval) -> Bool {
        guard now - lastHapticTime >= hapticCooldown else { return false }
        lastHapticTime = now
        return true
    }

    private func milestoneForStreak(_ streak: Int) -> ComboMilestone? {
        switch streak {
        case 3:
            return .hot
        case 5:
            return .fire
        case 8:
            return .flow
        default:
            return nil
        }
    }
}
