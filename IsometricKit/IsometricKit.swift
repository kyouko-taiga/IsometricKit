//
//  IsometricKit.swift
//  IsometricKit
//
//  Created by Dimitri Racordon on 25.11.16.
//
//

import SpriteKit


/**
    A protocol defining types that can be represented as and initialized with an `NSDictionary`.
 */
public protocol DictionaryRepresentable {

    var repr: NSDictionary { get }

    init?(repr: NSDictionary?)

}


public enum IKSpaceType: Int {
    case diamond
}


public struct IKVector3: DictionaryRepresentable {

    public var x: CGFloat = 0
    public var y: CGFloat = 0
    public var z: CGFloat = 0

    public init(x: CGFloat, y: CGFloat, z: CGFloat) {
        self.x = x
        self.y = y
        self.z = z
    }

    public static let zero = IKVector3(x: 0, y: 0, z: 0)

    // MARK: NSCoding

    public init?(repr: NSDictionary?) {
        if let x = repr?["x"] as? CGFloat,
           let y = repr?["y"] as? CGFloat,
           let z = repr?["z"] as? CGFloat {

            self.x = x
            self.y = y
            self.z = z
        } else {
            return nil
        }
    }

    public var repr: NSDictionary {
        return ["x": self.x, "y": self.y, "z": self.z]
    }

}


// MARK: Predefined isometric nodes.

public protocol IKObject {

    var space: IKSpace? { get set }
    var coordinates: IKVector3 { get set }

}


open class IKSpriteNode: SKSpriteNode, IKObject {

    open var space: IKSpace? {
        get {
            return self._space
        }

        set(newSpace) {
            self._space = newSpace
            if let space = newSpace {
                self.position = space.computePosition(from: self._coordinates)
                self.zPosition = space.computeZOrder(from: self._coordinates)

                // Set the vertical anchor of the texture at half the height of the space tiles
                // from the bottom. Base tiles will fit exactly and addition height will be pushed
                // to the top.
                self.anchorPoint.y = (space.tileSize.height / 2) / self.size.height
            }
        }
    }

    private weak var _space: IKSpace? = nil

    open var coordinates: IKVector3 {
        get {
            return self._coordinates
        }

        set(newCoordinates) {
            self._coordinates = newCoordinates
            if let space = self.space {
                self.position = space.computePosition(from: newCoordinates)
                self.zPosition = space.computeZOrder(from: newCoordinates)
            }
        }
    }

    private var _coordinates: IKVector3 = IKVector3.zero

    public override init(texture: SKTexture?, color: NSColor, size: CGSize) {
        super.init(texture: texture, color: color, size: size)
    }

    // MARK: NSCoding

    required public init?(coder aDecoder: NSCoder) {
        guard let coordinates = IKVector3(
            repr: aDecoder.decodeObject(forKey: "IKSpriteNode.coordinates") as? NSDictionary)
            else {
                return nil
        }

        self._coordinates = coordinates

        super.init(coder: aDecoder)
    }

    open override func encode(with aCoder: NSCoder) {
        aCoder.encode(self.coordinates.repr, forKey: "IKSpriteNode.worldSize")

        super.encode(with: aCoder)
    }

}


// MARK: IKSpace

open class IKSpace: SKNode {

    open let type: IKSpaceType
    open let tileSize: CGSize
    open let worldSize: IKVector3

    open override var frame: CGRect {
        return CGRect(
            origin: self.position,
            size: CGSize(
                width: self.worldSize.x * self.tileSize.width,
                height: self.worldSize.y * self.tileSize.height))
    }

    public init(tileSize: CGSize, worldSize: IKVector3, type: IKSpaceType = .diamond) {
        self.type = type
        self.tileSize = tileSize
        self.worldSize = worldSize

        super.init()
    }

    open override func addChild(_ node: SKNode) {
        if var isometricObject = node as? IKObject {
            isometricObject.space = self
        }

        super.addChild(node)
    }

    open func computePosition(from coordinates: IKVector3) -> CGPoint {
        // Compute the position on the <x, y> plane.
        let halfWidth = self.tileSize.width / 2
        let halfHeight = self.tileSize.height / 2

        var position: CGPoint! = nil

        switch self.type {
        case .diamond:
            position = CGPoint(
                x: CGFloat(coordinates.x - coordinates.y) * halfWidth + halfWidth,
                y: -CGFloat(coordinates.x + coordinates.y) * halfHeight
            )
        }

        // Shift the computed point on the y axis to emulate the z axis.
        position.y += coordinates.z * self.tileSize.height

        return position
    }

    open func computeZOrder(from coordinates: IKVector3) -> CGFloat {
        // Map any point of the isometric space onto a float such that if p and q are two points
        // respectively mapped onto x and y, p should be rendered before q if x < y.
        let positionIndex =
            coordinates.x +
            coordinates.y * self.worldSize.x +
            coordinates.z * self.worldSize.x * self.worldSize.y

        return positionIndex / (self.worldSize.x * self.worldSize.y + self.worldSize.z)
    }

    // MARK: NSCoding

    required public init?(coder aDecoder: NSCoder) {
        guard let type = IKSpaceType(rawValue: aDecoder.decodeInteger(forKey: "IKSpace.type")),
              let tileSize = aDecoder.decodeObject(forKey: "IKSpace.tileSize") as? CGSize,
              let worldSize = IKVector3(
                repr: aDecoder.decodeObject(forKey: "IKSpace.worldSize") as? NSDictionary)
            else {
                return nil
        }

        self.type = type
        self.tileSize = tileSize
        self.worldSize = worldSize

        super.init(coder: aDecoder)
    }

    open override func encode(with aCoder: NSCoder) {
        aCoder.encode(self.type.rawValue, forKey: "IKSpace.type")
        aCoder.encode(self.tileSize, forKey: "IKSpace.tileSize")
        aCoder.encode(self.worldSize.repr, forKey: "IKSpace.worldSize")

        super.encode(with: aCoder)
    }

}
