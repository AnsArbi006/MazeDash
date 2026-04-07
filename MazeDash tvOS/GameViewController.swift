//
//  GameViewController.swift
//  MazeDash tvOS
//
//  Created by Ans Alarbi on 13.01.26.
//

import UIKit
import SpriteKit

class GameViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let scene = StartScene(size: view.bounds.size)
        scene.scaleMode = .resizeFill
        
        // Present the scene
        let skView = self.view as! SKView
        skView.presentScene(scene)
        
        skView.ignoresSiblingOrder = true
        
        skView.showsFPS = false
        skView.showsNodeCount = false
    }

}
