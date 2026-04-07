//
//  GameViewController.swift
//  MazeDash iOS
//
//  Created by Ans Alarbi on 13.01.26.
//

import UIKit
import SpriteKit
import AVFAudio

class GameViewController: UIViewController {
    private var startupLoaderContainer: UIView?
    private var startupLoaderWorkItem: DispatchWorkItem?
    private var didPresentInitialScene = false

    private enum ScreenshotLaunchTarget {
        case startMenu
        case dailyMenu
        case levelSelect
        case gameplay(levelId: Int)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureAudioSession()
        guard let skView = self.view as? SKView else { return }
        skView.contentScaleFactor = view.traitCollection.displayScale
        TextureFactory.shared.displayScale = view.traitCollection.displayScale
        skView.ignoresSiblingOrder = true
        skView.preferredFramesPerSecond = 60
        skView.showsFPS = false
        skView.showsNodeCount = false

        scheduleStartupLoader()
        prepareStartupAndPresentInitialScene()
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            return
        }
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return .allButUpsideDown
        } else {
            return .all
        }
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }

    private func prepareStartupAndPresentInitialScene() {
        DispatchQueue.global(qos: .utility).async {
            SoundFX.prewarm()

            let continueLevelId = ProgressStore.shared.continueLevelId
            _ = MazeCache.shared.cachedMaze(levelIndex: continueLevelId - 1, config: makeLevelConfig(levelIndex: continueLevelId))

            let nextPlayableLevelId = ProgressStore.shared.nextPlayableLevelId
            _ = MazeCache.shared.cachedMaze(levelIndex: nextPlayableLevelId - 1, config: makeLevelConfig(levelIndex: nextPlayableLevelId))

            MazeCache.shared.prewarmNormalLevels()
        }
        DispatchQueue.main.async { [weak self] in
            self?.presentInitialScene()
        }
    }

    private func presentInitialScene() {
        guard !didPresentInitialScene else { return }
        guard let skView = self.view as? SKView else { return }
        didPresentInitialScene = true
        startupLoaderWorkItem?.cancel()
        startupLoaderWorkItem = nil

        SoundFX.syncAudioState()
        let scene: SKScene
        switch screenshotLaunchTarget() {
        case .dailyMenu:
            scene = DailyChallengeScene(size: view.bounds.size)
        case .levelSelect:
            scene = LevelSelectScene(size: view.bounds.size)
        case let .gameplay(levelId):
            let levelIndex = max(0, min(LevelStore.levels.count - 1, levelId - 1))
            scene = GameScene(size: view.bounds.size, levelIndex: levelIndex, runMode: .normal)
        case .startMenu:
            scene = StartScene(size: view.bounds.size)
        }
        scene.scaleMode = .resizeFill
        skView.presentScene(scene)
        dismissStartupLoaderIfNeeded()
    }

    private func screenshotLaunchTarget() -> ScreenshotLaunchTarget {
        guard let raw = ProcessInfo.processInfo.environment["MAZEDASH_SCREENSHOT_TARGET"]?.lowercased() else {
            return .startMenu
        }

        switch raw {
        case "menu":
            return .startMenu
        case "daily":
            return .dailyMenu
        case "levels":
            return .levelSelect
        default:
            if raw.hasPrefix("gameplay:"),
               let levelId = Int(raw.replacingOccurrences(of: "gameplay:", with: "")) {
                return .gameplay(levelId: levelId)
            }
            return .startMenu
        }
    }

    private func scheduleStartupLoader() {
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard !self.didPresentInitialScene else { return }
            self.showStartupLoader()
        }
        startupLoaderWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16, execute: workItem)
    }

    private func showStartupLoader() {
        guard startupLoaderContainer == nil else { return }

        let container = UIView(frame: view.bounds)
        container.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.alpha = 0
        container.isUserInteractionEnabled = false

        let background = UIView(frame: container.bounds)
        background.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        background.backgroundColor = UIColor(red: 0.02, green: 0.03, blue: 0.05, alpha: 1.0)
        container.addSubview(background)

        let gradient = CAGradientLayer()
        gradient.frame = background.bounds
        gradient.colors = [
            UIColor(red: 0.02, green: 0.03, blue: 0.05, alpha: 1.0).cgColor,
            UIColor(red: 0.06, green: 0.04, blue: 0.12, alpha: 1.0).cgColor
        ]
        gradient.startPoint = CGPoint(x: 0.5, y: 0.0)
        gradient.endPoint = CGPoint(x: 0.5, y: 1.0)
        background.layer.addSublayer(gradient)

        let gridLayer = CAShapeLayer()
        gridLayer.frame = background.bounds
        gridLayer.strokeColor = UIColor(red: 0.0, green: 0.83, blue: 1.0, alpha: 0.10).cgColor
        gridLayer.fillColor = UIColor.clear.cgColor
        gridLayer.lineWidth = 1
        let gridPath = UIBezierPath()
        let verticalSpacing: CGFloat = 42
        let horizontalSpacing: CGFloat = 42
        var x: CGFloat = 0
        while x <= background.bounds.width {
            gridPath.move(to: CGPoint(x: x, y: 0))
            gridPath.addLine(to: CGPoint(x: x, y: background.bounds.height))
            x += verticalSpacing
        }
        var y: CGFloat = 0
        while y <= background.bounds.height {
            gridPath.move(to: CGPoint(x: 0, y: y))
            gridPath.addLine(to: CGPoint(x: background.bounds.width, y: y))
            y += horizontalSpacing
        }
        gridLayer.path = gridPath.cgPath
        background.layer.addSublayer(gridLayer)

        let cyanGlow = UIView(frame: CGRect(
            x: -background.bounds.width * 0.14,
            y: background.bounds.height * 0.04,
            width: background.bounds.width * 0.7,
            height: background.bounds.height * 0.34
        ))
        cyanGlow.backgroundColor = UIColor(red: 0.0, green: 0.83, blue: 1.0, alpha: 0.16)
        cyanGlow.layer.cornerRadius = cyanGlow.bounds.height / 2
        cyanGlow.layer.blur(radius: 42)
        background.addSubview(cyanGlow)

        let magentaGlow = UIView(frame: CGRect(
            x: background.bounds.width * 0.48,
            y: background.bounds.height * 0.52,
            width: background.bounds.width * 0.5,
            height: background.bounds.height * 0.24
        ))
        magentaGlow.backgroundColor = UIColor(red: 1.0, green: 0.18, blue: 0.6, alpha: 0.09)
        magentaGlow.layer.cornerRadius = magentaGlow.bounds.height / 2
        magentaGlow.layer.blur(radius: 38)
        background.addSubview(magentaGlow)

        let scanBand = UIView(frame: CGRect(x: -background.bounds.width * 0.4, y: background.bounds.height * 0.32, width: background.bounds.width * 0.55, height: 120))
        scanBand.alpha = 0.24
        let scanGradient = CAGradientLayer()
        scanGradient.frame = scanBand.bounds
        scanGradient.colors = [
            UIColor.clear.cgColor,
            UIColor(red: 0.0, green: 0.83, blue: 1.0, alpha: 0.18).cgColor,
            UIColor.clear.cgColor
        ]
        scanGradient.startPoint = CGPoint(x: 0, y: 0.5)
        scanGradient.endPoint = CGPoint(x: 1, y: 0.5)
        scanBand.layer.addSublayer(scanGradient)
        background.addSubview(scanBand)

        let sweep = CABasicAnimation(keyPath: "position.x")
        sweep.fromValue = -background.bounds.width * 0.2
        sweep.toValue = background.bounds.width * 1.2
        sweep.duration = 5.6
        sweep.repeatCount = .infinity
        sweep.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        scanBand.layer.add(sweep, forKey: "sweep")

        let loaderSize = CGSize(width: 76, height: 76)
        let loaderFrame = CGRect(
            x: (container.bounds.width - loaderSize.width) * 0.5,
            y: (container.bounds.height - loaderSize.height) * 0.5,
            width: loaderSize.width,
            height: loaderSize.height
        )
        let loader = UIView(frame: loaderFrame)
        loader.autoresizingMask = [
            .flexibleTopMargin,
            .flexibleBottomMargin,
            .flexibleLeftMargin,
            .flexibleRightMargin
        ]
        loader.backgroundColor = UIColor(red: 0.02, green: 0.04, blue: 0.09, alpha: 0.28)
        loader.layer.cornerRadius = 24
        loader.layer.borderWidth = 1.5
        loader.layer.borderColor = UIColor(red: 0.0, green: 0.83, blue: 1.0, alpha: 0.26).cgColor
        container.addSubview(loader)

        let ring = UIView(frame: CGRect(x: 8, y: 8, width: 60, height: 60))
        ring.layer.cornerRadius = 30
        ring.layer.borderWidth = 2
        ring.layer.borderColor = UIColor(red: 0.0, green: 0.83, blue: 1.0, alpha: 0.72).cgColor
        ring.backgroundColor = UIColor(red: 0.03, green: 0.05, blue: 0.11, alpha: 0.42)
        ring.layer.shadowColor = UIColor(red: 0.0, green: 0.83, blue: 1.0, alpha: 0.9).cgColor
        ring.layer.shadowOpacity = 0.42
        ring.layer.shadowRadius = 10
        ring.layer.shadowOffset = .zero
        loader.addSubview(ring)

        let orbit = UIView(frame: ring.bounds)
        orbit.backgroundColor = .clear
        ring.addSubview(orbit)

        let dot = UIView(frame: CGRect(x: ring.bounds.maxX - 14, y: ring.bounds.midY - 5, width: 10, height: 10))
        dot.layer.cornerRadius = 5
        dot.backgroundColor = UIColor(red: 1.0, green: 0.18, blue: 0.6, alpha: 0.98)
        dot.layer.shadowColor = dot.backgroundColor?.cgColor
        dot.layer.shadowOpacity = 0.85
        dot.layer.shadowRadius = 8
        dot.layer.shadowOffset = .zero
        orbit.addSubview(dot)

        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue = 0.96
        pulse.toValue = 1.04
        pulse.duration = 0.85
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        ring.layer.add(pulse, forKey: "pulse")

        let spin = CABasicAnimation(keyPath: "transform.rotation.z")
        spin.fromValue = 0
        spin.toValue = Double.pi * 2
        spin.duration = 1.05
        spin.repeatCount = .infinity
        spin.timingFunction = CAMediaTimingFunction(name: .linear)
        orbit.layer.add(spin, forKey: "spin")

        view.addSubview(container)
        startupLoaderContainer = container

        UIView.animate(withDuration: 0.14) {
            container.alpha = 1
        }
    }

    private func dismissStartupLoaderIfNeeded() {
        guard let container = startupLoaderContainer else { return }
        startupLoaderContainer = nil
        UIView.animate(withDuration: 0.14, animations: {
            container.alpha = 0
        }, completion: { _ in
            container.removeFromSuperview()
        })
    }
}

private extension CALayer {
    func blur(radius: CGFloat) {
        shadowColor = backgroundColor
        shadowOpacity = 1
        shadowRadius = radius
        shadowOffset = .zero
    }
}
