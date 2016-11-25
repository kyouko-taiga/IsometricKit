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
        let space = IKSpace(
            tileSize: CGSize(width: 112, height: 64),
            worldSize: IKVector3(x: 2, y: 2, z: 2))

        let sprite = IKSpriteNode(imageNamed: "grass")
        space.addChild(sprite)
        print(sprite.zPosition)

        let sprite2 = IKSpriteNode(imageNamed: "sand")
        sprite2.coordinates = IKVector3(x: 1, y: 0, z: 0)
        space.addChild(sprite2)
        print(sprite2.zPosition)

        let sprite3 = IKSpriteNode(imageNamed: "snow")
        sprite3.coordinates = IKVector3(x: 1, y: 0, z: 1)
        space.addChild(sprite3)
        print(sprite3.zPosition)

        space.position.x = self.frame.width / 2
        space.position.y = self.frame.height / 2

        self.addChild(space)
    }
    
    override func update(_ currentTime: TimeInterval) {
        // Called before each frame is rendered
    }
}
