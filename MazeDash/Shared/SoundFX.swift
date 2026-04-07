import SpriteKit
#if os(iOS) || os(tvOS)
import AVFAudio
#endif

enum SFX: String, CaseIterable {
    case select1 = "ui_select_1"
    case select2 = "ui_select_2"
    case cancel1 = "ui_cancel_1"
    case popupOpen = "ui_popup_open"
    case popupClose = "ui_popup_close"
    case swipe1 = "ui_swipe_1"
    case swipe2 = "ui_swipe_2"
    case cursor1 = "ui_cursor_1"
    case error1 = "ui_error_1"
}

enum HitFeedbackSound {
    case good
    case perfect
}

struct SoundFX {
    static func play(_ sfx: SFX, on node: SKNode) {
        guard SettingsStore.shared.isEffectsPlaybackEnabled else { return }
        #if os(iOS) || os(tvOS)
        EffectController.shared.play(sfx)
        #else
        guard let action = action(for: sfx) else { return }
        node.run(action)
        #endif
    }

    static func playButtonTap(on node: SKNode) {
        play(.select1, on: node)
    }

    static func playSwipe(on node: SKNode) {
        play(.swipe1, on: node)
    }

    static func playComboBing(on node: SKNode) {
        play(.cursor1, on: node)
    }

    static func playTeleport(on node: SKNode) {
        guard SettingsStore.shared.isEffectsPlaybackEnabled else { return }
        #if os(iOS) || os(tvOS)
        EffectController.shared.playSemantic("teleport", sfx: .swipe2, excerptDuration: 0.08, minimumGap: 0.05)
        #else
        if let action = action(for: .swipe2) {
            node.run(action)
        }
        #endif
    }

    static func playUnlock(on node: SKNode) {
        guard SettingsStore.shared.isEffectsPlaybackEnabled else { return }
        #if os(iOS) || os(tvOS)
        EffectController.shared.playSemantic("unlock", sfx: .select2, excerptDuration: 0.10, minimumGap: 0.08)
        #else
        if let action = action(for: .select2) {
            node.run(action)
        }
        #endif
    }

    static func playReward(on node: SKNode) {
        guard SettingsStore.shared.isEffectsPlaybackEnabled else { return }
        #if os(iOS) || os(tvOS)
        EffectController.shared.playSemantic("reward", sfx: .cursor1, excerptDuration: 0.16, minimumGap: 0.16)
        EffectController.shared.playSemantic("rewardSpark", sfx: .select1, excerptDuration: 0.09, minimumGap: 0.16)
        #else
        if let action = action(for: .cursor1) {
            node.run(action)
        }
        #endif
    }

    static func playFogReveal(on node: SKNode) {
        guard SettingsStore.shared.isEffectsPlaybackEnabled else { return }
        #if os(iOS) || os(tvOS)
        EffectController.shared.playSemantic("fogReveal", sfx: .swipe1, excerptDuration: 0.06, minimumGap: 0.18)
        #else
        if let action = action(for: .swipe1) {
            node.run(action)
        }
        #endif
    }

    static func playBlocked(on node: SKNode) {
        guard SettingsStore.shared.isEffectsPlaybackEnabled else { return }
        #if os(iOS) || os(tvOS)
        EffectController.shared.playSemantic("blocked", sfx: .error1, excerptDuration: 0.08, minimumGap: 0.07)
        #else
        if let action = action(for: .error1) {
            node.run(action)
        }
        #endif
    }

    static func playWin(on node: SKNode) {
        guard SettingsStore.shared.isEffectsPlaybackEnabled else { return }
        #if os(iOS) || os(tvOS)
        EffectController.shared.playSemantic("win", sfx: .cursor1, excerptDuration: 0.12, minimumGap: 0.14)
        EffectController.shared.playSemantic("winAccent", sfx: .select2, excerptDuration: 0.11, minimumGap: 0.14)
        #else
        if let action = action(for: .cursor1) {
            node.run(action)
        }
        #endif
    }

    static func playHitFeedback(_ feedback: HitFeedbackSound, on node: SKNode) {
        guard SettingsStore.shared.isEffectsPlaybackEnabled else { return }
        #if os(iOS) || os(tvOS)
        switch feedback {
        case .good:
            EffectController.shared.playGoodHit()
        case .perfect:
            EffectController.shared.playPerfectHit()
        }
        #else
        switch feedback {
        case .good:
            if let action = action(for: .select2) {
                node.run(action)
            }
        case .perfect:
            let primary = action(for: .cursor1)
            let sparkle = action(for: .select1)
            switch (primary, sparkle) {
            case let (primary?, sparkle?):
                node.run(.sequence([
                    primary,
                    .wait(forDuration: 0.025),
                    sparkle
                ]))
            case let (primary?, nil):
                node.run(primary)
            case let (nil, sparkle?):
                node.run(sparkle)
            case (nil, nil):
                break
            }
        }
        #endif
    }

    static func syncAudioState() {
        #if os(iOS) || os(tvOS)
        let settings = SettingsStore.shared
        EffectController.shared.setMasterVolume(settings.masterVolume)
        MusicController.shared.setMasterVolume(settings.masterVolume)
        EffectController.shared.setEnabled(settings.isEffectsPlaybackEnabled)
        MusicController.shared.setEnabled(settings.isMusicPlaybackEnabled)
        #endif
    }

    static func prewarm() {
        #if os(iOS) || os(tvOS)
        EffectController.shared.prepareIfNeeded()
        #endif
    }

    static func applicationWillResignActive() {
        #if os(iOS) || os(tvOS)
        EffectController.shared.suspendForApplicationBackground()
        MusicController.shared.suspendForApplicationBackground()
        #endif
    }

    static func applicationDidEnterBackground() {
        #if os(iOS) || os(tvOS)
        EffectController.shared.suspendForApplicationBackground()
        MusicController.shared.suspendForApplicationBackground()
        #endif
    }

    static func applicationDidBecomeActive() {
        #if os(iOS) || os(tvOS)
        syncAudioState()
        MusicController.shared.resumeAfterApplicationForeground()
        #endif
    }

    static func applicationDidTakeScreenshot() {
        #if os(iOS) || os(tvOS)
        EffectController.shared.suppressBrieflyForSystemCapture()
        MusicController.shared.duckBrieflyForSystemCapture()
        #endif
    }

    private static func action(for sfx: SFX) -> SKAction? {
        if Bundle.main.url(forResource: sfx.rawValue, withExtension: "m4a") != nil {
            return .playSoundFileNamed("\(sfx.rawValue).m4a", waitForCompletion: false)
        }
        if Bundle.main.url(forResource: sfx.rawValue, withExtension: "m4a", subdirectory: "Audio") != nil {
            return .playSoundFileNamed("Audio/\(sfx.rawValue).m4a", waitForCompletion: false)
        }
        return nil
    }
}

#if os(iOS) || os(tvOS)
final class EffectController {
    static let shared = EffectController()

    private let poolSize = 3
    private let audioQueue = DispatchQueue(label: "com.ans.mazedash.sfx", qos: .userInitiated)
    private var playersByEffect: [SFX: [AVAudioPlayer]] = [:]
    private var nextIndex: [SFX: Int] = [:]
    private var lastPlayTimeByEffect: [SFX: TimeInterval] = [:]
    private var lastSemanticPlayTime: [String: TimeInterval] = [:]
    private var lastHitFeedbackTime: TimeInterval = -10
    private var playbackTokenByPlayer: [ObjectIdentifier: UInt64] = [:]
    private var nextPlaybackToken: UInt64 = 1
    private var isPrepared = false
    private var isEnabled = true
    private var masterVolume: Float = SettingsStore.shared.masterVolume
    private var suppressedUntilTime: TimeInterval = 0

    private init() {}

    func prepareIfNeeded() {
        audioQueue.sync {
            self.prepareIfNeededLocked()
        }
    }

    private func prepareIfNeededLocked() {
        guard !isPrepared else { return }

        var preparedPlayers: [SFX: [AVAudioPlayer]] = [:]
        var preparedIndices: [SFX: Int] = [:]

        for sfx in SFX.allCases {
            guard let url = resourceURL(for: sfx) else { continue }
            var pool: [AVAudioPlayer] = []
            for _ in 0..<poolSize {
                do {
                    let player = try AVAudioPlayer(contentsOf: url)
                    player.volume = effectiveVolume(for: sfx)
                    player.numberOfLoops = 0
                    player.prepareToPlay()
                    pool.append(player)
                } catch {
                    continue
                }
            }
            if !pool.isEmpty {
                preparedPlayers[sfx] = pool
                preparedIndices[sfx] = 0
            }
        }

        playersByEffect = preparedPlayers
        nextIndex = preparedIndices
        isPrepared = true
    }

    func setEnabled(_ enabled: Bool) {
        audioQueue.async {
            self.isEnabled = enabled
            self.prepareIfNeededLocked()
            guard !enabled else { return }
            for players in self.playersByEffect.values {
                for player in players where player.isPlaying {
                    player.stop()
                    player.currentTime = 0
                }
            }
        }
    }

    func setMasterVolume(_ volume: Float) {
        audioQueue.async {
            self.masterVolume = min(1, max(0, volume))
            for (sfx, players) in self.playersByEffect {
                for player in players where player.isPlaying {
                    player.volume = self.effectiveVolume(for: sfx)
                }
            }
        }
    }

    func suspendForApplicationBackground() {
        audioQueue.async {
            for players in self.playersByEffect.values {
                for player in players where player.isPlaying {
                    player.stop()
                    player.currentTime = 0
                }
            }
            self.lastSemanticPlayTime.removeAll(keepingCapacity: true)
            self.playbackTokenByPlayer.removeAll(keepingCapacity: true)
        }
    }

    func suppressBrieflyForSystemCapture() {
        audioQueue.async {
            let now = self.currentTime()
            self.suppressedUntilTime = max(self.suppressedUntilTime, now + 0.45)
            for players in self.playersByEffect.values {
                for player in players where player.isPlaying {
                    player.stop()
                    player.currentTime = 0
                }
            }
        }
    }

    func play(_ sfx: SFX) {
        audioQueue.async {
            guard self.isEnabled else { return }
            self.prepareIfNeededLocked()
            self.playNow(sfx, interruptIfBusy: false, ignoreCooldown: false)
        }
    }

    func playGoodHit() {
        audioQueue.async {
            guard self.isEnabled else { return }
            self.prepareIfNeededLocked()
            guard self.canPlayHitFeedbackNow() else { return }
            self.playNow(.select2, interruptIfBusy: false, ignoreCooldown: true, excerptDuration: 0.12)
        }
    }

    func playPerfectHit() {
        audioQueue.async {
            guard self.isEnabled else { return }
            self.prepareIfNeededLocked()
            guard self.canPlayHitFeedbackNow() else { return }
            self.playNow(.cursor1, interruptIfBusy: false, ignoreCooldown: true, excerptDuration: 0.14)
            self.audioQueue.asyncAfter(deadline: .now() + 0.025) {
                guard self.isEnabled else { return }
                self.playNow(.select1, interruptIfBusy: false, ignoreCooldown: true, excerptDuration: 0.09)
            }
        }
    }

    func playSemantic(_ key: String, sfx: SFX, excerptDuration: TimeInterval, minimumGap: TimeInterval, interruptIfBusy: Bool = false) {
        audioQueue.async {
            guard self.isEnabled else { return }
            self.prepareIfNeededLocked()
            let now = self.currentTime()
            let lastTime = self.lastSemanticPlayTime[key, default: -10]
            guard now - lastTime >= minimumGap else { return }
            self.lastSemanticPlayTime[key] = now
            self.playNow(sfx, interruptIfBusy: interruptIfBusy, ignoreCooldown: true, excerptDuration: excerptDuration)
        }
    }

    private func canPlayHitFeedbackNow() -> Bool {
        let now = currentTime()
        let minimumGap: TimeInterval = 0.05
        guard now - lastHitFeedbackTime >= minimumGap else { return false }
        lastHitFeedbackTime = now
        return true
    }

    private func playNow(_ sfx: SFX, interruptIfBusy: Bool, ignoreCooldown: Bool, excerptDuration: TimeInterval? = nil) {
        guard currentTime() >= suppressedUntilTime else { return }
        guard let pool = playersByEffect[sfx], !pool.isEmpty else { return }
        guard ignoreCooldown || canPlay(sfx) else { return }

        let preferred = nextIndex[sfx, default: 0] % pool.count
        let indexToUse: Int
        if let freeIndex = pool.indices.first(where: { !pool[$0].isPlaying }) {
            indexToUse = freeIndex
        } else if interruptIfBusy {
            indexToUse = preferred
        } else {
            return
        }

        let player = pool[indexToUse]
        if player.isPlaying {
            player.stop()
        }
        player.currentTime = 0
        player.volume = effectiveVolume(for: sfx)
        _ = player.play()
        scheduleExcerptStopIfNeeded(for: player, duration: excerptDuration)

        lastPlayTimeByEffect[sfx] = currentTime()
        nextIndex[sfx] = (indexToUse + 1) % pool.count
    }

    private func scheduleExcerptStopIfNeeded(for player: AVAudioPlayer, duration: TimeInterval?) {
        guard let duration, duration > 0 else { return }

        let playerID = ObjectIdentifier(player)
        let token = nextPlaybackToken
        nextPlaybackToken &+= 1
        playbackTokenByPlayer[playerID] = token

        audioQueue.asyncAfter(deadline: .now() + duration) {
            guard self.playbackTokenByPlayer[playerID] == token else { return }
            guard player.isPlaying else { return }
            player.stop()
            player.currentTime = 0
        }
    }

    private func canPlay(_ sfx: SFX) -> Bool {
        let minimumGap: TimeInterval
        switch sfx {
        case .select1, .select2, .cursor1:
            minimumGap = 0.035
        case .swipe1, .swipe2:
            minimumGap = 0.05
        default:
            minimumGap = 0.025
        }

        let now = currentTime()
        let lastTime = lastPlayTimeByEffect[sfx, default: -10]
        return now - lastTime >= minimumGap
    }

    private func currentTime() -> TimeInterval {
        ProcessInfo.processInfo.systemUptime
    }

    private func resourceURL(for sfx: SFX) -> URL? {
        if let direct = Bundle.main.url(forResource: sfx.rawValue, withExtension: "m4a") {
            return direct
        }
        return Bundle.main.url(forResource: sfx.rawValue, withExtension: "m4a", subdirectory: "Audio")
    }

    private func volume(for sfx: SFX) -> Float {
        switch sfx {
        case .popupOpen, .popupClose:
            return 0.75
        case .cursor1:
            return 0.82
        case .swipe1, .swipe2:
            return 0.62
        default:
            return 0.72
        }
    }

    private func effectiveVolume(for sfx: SFX) -> Float {
        volume(for: sfx) * masterVolume
    }
}

final class MusicController {
    static let shared = MusicController()

    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private var isConfigured = false
    private var isEnabled = false
    private var masterVolume: Float = SettingsStore.shared.masterVolume
    private var sampleRate: Double = 44_100
    private var sampleTime: Double = 0
    private var phaseA: Double = 0
    private var phaseB: Double = 0
    private var phaseC: Double = 0
    private var wasRunningBeforeSuspend = false
    private var restoreCaptureDuckWorkItem: DispatchWorkItem?

    private let bassNotes: [Double] = [55.0, 61.74, 73.42, 82.41]
    private let leadNotes: [Double] = [220.0, 246.94, 293.66, 329.63, 392.0, 329.63, 293.66, 246.94]

    private init() {}

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        enabled ? startIfNeeded() : stop()
    }

    func setMasterVolume(_ volume: Float) {
        masterVolume = min(1, max(0, volume))
        if isConfigured {
            engine.mainMixerNode.outputVolume = 0.65 * masterVolume
        }
    }

    private func startIfNeeded() {
        guard isEnabled else { return }
        configureIfNeeded()
        guard !engine.isRunning else { return }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            return
        }
    }

    private func stop() {
        guard engine.isRunning else { return }
        engine.pause()
    }

    func suspendForApplicationBackground() {
        wasRunningBeforeSuspend = engine.isRunning && isEnabled
        stop()
    }

    func resumeAfterApplicationForeground() {
        guard wasRunningBeforeSuspend else { return }
        wasRunningBeforeSuspend = false
        guard isEnabled else { return }
        startIfNeeded()
    }

    func duckBrieflyForSystemCapture() {
        guard isConfigured, engine.isRunning else { return }
        restoreCaptureDuckWorkItem?.cancel()
        engine.mainMixerNode.outputVolume = 0.18 * masterVolume

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard self.isConfigured else { return }
            let targetVolume: Float = self.isEnabled ? (0.65 * self.masterVolume) : 0
            self.engine.mainMixerNode.outputVolume = targetVolume
        }
        restoreCaptureDuckWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42, execute: workItem)
    }

    private func configureIfNeeded() {
        guard !isConfigured else { return }
        let outputFormat = engine.outputNode.outputFormat(forBus: 0)
        sampleRate = outputFormat.sampleRate > 0 ? outputFormat.sampleRate : 44_100

        let node = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self else { return 0 }
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let frameTotal = Int(frameCount)

            for frame in 0..<frameTotal {
                let t = self.sampleTime / self.sampleRate
                let leadIndex = Int(t * 3.2) % self.leadNotes.count
                let bassIndex = Int(t * 0.8) % self.bassNotes.count

                let leadFreq = self.leadNotes[leadIndex]
                let bassFreq = self.bassNotes[bassIndex]
                let padFreq = leadFreq * 0.5

                self.phaseA += 2.0 * .pi * leadFreq / self.sampleRate
                self.phaseB += 2.0 * .pi * bassFreq / self.sampleRate
                self.phaseC += 2.0 * .pi * padFreq / self.sampleRate

                if self.phaseA > (.pi * 2) { self.phaseA -= (.pi * 2) }
                if self.phaseB > (.pi * 2) { self.phaseB -= (.pi * 2) }
                if self.phaseC > (.pi * 2) { self.phaseC -= (.pi * 2) }

                let gate = 0.72 + 0.18 * sin(t * 1.2)
                let shimmer = 0.5 + 0.5 * sin(t * 8.0)
                let sample =
                    sin(self.phaseA) * 0.035 * gate +
                    sin(self.phaseB) * 0.02 +
                    sin(self.phaseC) * 0.018 * shimmer

                for buffer in buffers {
                    let pointer = buffer.mData?.assumingMemoryBound(to: Float.self)
                    pointer?[frame] = Float(sample)
                }

                self.sampleTime += 1
            }

            return 0
        }

        sourceNode = node
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: outputFormat)
        engine.mainMixerNode.outputVolume = 0.65 * masterVolume
        isConfigured = true
    }
}
#endif
