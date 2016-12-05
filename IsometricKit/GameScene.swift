//
//  GameScene.swift
//  IsometricKit
//
//  Created by Dimitri Racordon on 25.11.16.
//
//

import SpriteKit


class GameScene: SKScene {
    
    override func sceneDidLoad() {
//        let space = IKSpace(
//            tileSize: CGSize(width: 112, height: 64),
//            worldSize: IKVector3(x: 3, y: 3, z: 2))
//
//        for x in 0 ..< 3 {
//            for y in 0 ..< 3 {
//                let sprite = IKHandle(on: SKSpriteNode(imageNamed: "grass"))
//                sprite.coordinates = IKVector3(x: CGFloat(x), y: CGFloat(y), z: 0)
//                space.addChild(sprite)
//            }
//        }
//
//        let sprite3 = IKHandle(on: SKSpriteNode(imageNamed: "snow"))
//        sprite3.coordinates = IKVector3(x: 1, y: 0, z: 1)
//        space.addChild(sprite3)

        let parser = IKTMXParser()
        guard let space = parser.load(fileNamed: "example") else {
            return
        }

        space.target.position.x = self.frame.width / 2
        // space.target.position.y = self.frame.height / 2
        self.addChild(space.target)
    }
    
    override func update(_ currentTime: TimeInterval) {
        // Called before each frame is rendered
    }
}
