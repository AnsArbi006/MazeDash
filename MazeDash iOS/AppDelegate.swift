//
//  AppDelegate.swift
//  MazeDash iOS
//
//  Created by Ans Alarbi on 13.01.26.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    private var screenshotObserver: NSObjectProtocol?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        screenshotObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.userDidTakeScreenshotNotification,
            object: nil,
            queue: .main
        ) { _ in
            SoundFX.applicationDidTakeScreenshot()
        }
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        SoundFX.applicationWillResignActive()
        NotificationCenter.default.post(name: .mazeDashApplicationWillResignActive, object: nil)
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        SoundFX.applicationDidEnterBackground()
        NotificationCenter.default.post(name: .mazeDashApplicationDidEnterBackground, object: nil)
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        SoundFX.applicationDidBecomeActive()
        NotificationCenter.default.post(name: .mazeDashApplicationDidBecomeActive, object: nil)
    }

    func applicationWillTerminate(_ application: UIApplication) {
        if let screenshotObserver {
            NotificationCenter.default.removeObserver(screenshotObserver)
            self.screenshotObserver = nil
        }
    }


}

extension Notification.Name {
    static let mazeDashApplicationWillResignActive = Notification.Name("MazeDashApplicationWillResignActive")
    static let mazeDashApplicationDidEnterBackground = Notification.Name("MazeDashApplicationDidEnterBackground")
    static let mazeDashApplicationDidBecomeActive = Notification.Name("MazeDashApplicationDidBecomeActive")
}
