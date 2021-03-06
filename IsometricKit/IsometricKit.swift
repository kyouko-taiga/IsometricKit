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


public struct IKVector3: DictionaryRepresentable, Hashable {

    public var x: CGFloat = 0
    public var y: CGFloat = 0
    public var z: CGFloat = 0

    public init(x: CGFloat, y: CGFloat, z: CGFloat) {
        self.x = x
        self.y = y
        self.z = z
    }

    public static let zero = IKVector3(x: 0, y: 0, z: 0)

    // MARK: Equatable, Hashable

    public var hashValue: Int {
        return self.x.hashValue ^ self.y.hashValue ^ self.z.hashValue
    }

    public static func == (lhs: IKVector3, rhs: IKVector3) -> Bool {
        return (lhs.x == rhs.x) && (lhs.y == rhs.y) && (lhs.z == rhs.z)
    }

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


// MARK: Tree objects.

open class IKHandle: NSObject, NSCoding {

    open let target: SKNode

    open weak var space: IKSpace? = nil {
        didSet {
            if let space = self.space {
                self._setPosition(in: space)
                self._setAnchorPoint(in: space)

                // https://bugs.swift.org/browse/SR-419
                self.children.forEach {
                    $0.space = space
                }
            }
        }
    }

    open var coordinates: IKVector3 = IKVector3.zero {
        didSet {
            if let space = self.space {
                self._setPosition(in: space)
            }
        }
    }

    open private(set) weak var parent: IKHandle? = nil
    open private(set) var children = Set<IKHandle>()

    init(on target: SKNode = SKNode(), in space: IKSpace? = nil) {
        self.target = target
        self.space = space
    }

    open func addChild(_ handle: IKHandle) {
        if !self.children.contains(handle) {
            self.children.insert(handle)
            self.target.addChild(handle.target)

            handle.space = self.space
            handle.parent = self
        }
    }

    private func _setPosition(in space: IKSpace) {
        self.target.position = space.computePosition(from: self.coordinates)
        self.target.zPosition = space.computeZOrder(from: self.coordinates)
    }

    private func _setAnchorPoint(in space: IKSpace) {
        if let sprite = self.target as? SKSpriteNode {
            // Set the anchor of textures at half the height of the space tiles from the bottom.
            // Base tiles will fit exactly and addition height will be pushed to the top.
            sprite.anchorPoint.y = (space.tileSize.height / 2) / sprite.size.height
        }
    }

    // MARK: NSCoding

    required public init?(coder aDecoder: NSCoder) {
        guard let target = aDecoder.decodeObject(forKey: "IKHandle.target") as? SKNode,
              let coordinates = IKVector3(
                repr: aDecoder.decodeObject(forKey: "IKHandle.coordinates") as? NSDictionary),
              let children = aDecoder.decodeObject(forKey: "IKHandle.children") as? Set<IKHandle>
            else {
                return nil
        }

        self.target = target
        self.space = aDecoder.decodeObject(forKey: "IKHandle.space") as? IKSpace
        self.coordinates = coordinates
        self.children = children
        self.parent = aDecoder.decodeObject(forKey: "IKHandle.parent") as? IKHandle
    }

    open func encode(with aCoder: NSCoder) {
        aCoder.encode(self.space, forKey: "IKHandle.space")
        aCoder.encode(self.target, forKey: "IKHandle.target")
        aCoder.encode(self.coordinates.repr, forKey: "IKHandle.coordinates")
        aCoder.encode(self.parent, forKey: "IKHandle.parent")
        aCoder.encode(self.children, forKey: "IKHandle.children")
    }

}


// MARK: IKSpace

open class IKSpace: IKHandle {

    open let type: IKSpaceType
    open let tileSize: CGSize
    open let worldSize: IKVector3

    public init(tileSize: CGSize, worldSize: IKVector3, type: IKSpaceType = .diamond) {
        self.type = type
        self.tileSize = tileSize
        self.worldSize = worldSize

        super.init()
        self.space = self
    }

    open func computePosition(from coordinates: IKVector3) -> CGPoint {
        // Compute the position on the <x, y> plane.
        let halfWidth = self.tileSize.width / 2
        let halfHeight = self.tileSize.height / 2

        var position: CGPoint! = nil

        switch self.type {
        case .diamond:
            position = CGPoint(
                x: CGFloat(coordinates.x - coordinates.y) * halfWidth,
                y: -CGFloat(coordinates.x + coordinates.y) * halfHeight - halfHeight
            )
        }

        // Shift the computed point on the y axis to emulate the z axis.
        position.y += coordinates.z * self.tileSize.height

        // Shift the computed point on the y axis to keep the space centered on its anchor point.
        position.y += (self.worldSize.y + self.worldSize.z - 1) * self.tileSize.height / 2

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


// MARK: IKTMXParser

public class IKTMXParser: NSObject, XMLParserDelegate {

    var _parser: XMLParser? = nil

    private class TileDefinition {
        var texture: SKTexture?
        var userData: NSMutableDictionary?
    }

    private var _space: IKSpace?

    private var _tileSize = CGSize.zero
    private var _worldSize = IKVector3.zero
    private var _spaceType = IKSpaceType.diamond

    private var _tileDefinitions = [Int: TileDefinition]()

    private var _isParsingLayer = false
    private var _layers = [IKHandle]()
    private var _currentCoordinates = IKVector3.zero

    private var _currentFirstGID: Int? = nil
    private var _currentTileDefinition: TileDefinition?

    public func load(fileNamed filename: String) -> IKSpace? {
        guard let url = Bundle.main.url(forResource: filename, withExtension: ".tmx") else {
            self._log("TMX file '\(filename)' not found", level: "error")
            return nil
        }

        let data: Data?
        do {
            data = try Data(contentsOf: url)
        } catch let error {
            self._log(error.localizedDescription, level: "error")
            return nil
        }

        self._parser = XMLParser(data: data!)
        self._parser!.delegate = self
        self._parser!.parse()

        return self._space
    }

    public func parser(
        _ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
        qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {

        switch elementName {
        case "map":
            // Parse the <x, y> world dimensions.
            guard
                let columns = readInt("width", from: attributeDict),
                let rows = readInt("height", from: attributeDict) else {
                    self._log("missing or invalid map size", level: "error")
                    parser.abortParsing()
                    return
            }

            // Parse the tile width.
            guard
                let tileWidth = readInt("tilewidth", from: attributeDict),
                let tileHeight = readInt("tileheight", from: attributeDict) else {
                    self._log("missing or invalid tile size", level: "error")
                    parser.abortParsing()
                    return
            }

            // Parse the isometric space type.
            if let orientation = attributeDict["orientation"] {
                // TODO: Support staggered orientations.
                if orientation != "isometric" {
                    self._log("unsupported map orientation '\(orientation)'", level: "error")
                    parser.abortParsing()
                }
            } else {
                self._log("missing map orientation, assumed 'isometric'")
            }

            self._worldSize = IKVector3(x: CGFloat(columns), y: CGFloat(rows), z: 1)
            self._tileSize = CGSize(width: tileWidth, height: tileHeight)

        case "tileset":
            guard let firstGID = readInt("firstgid", from: attributeDict) else {
                self._log(
                    "missing or invalid property 'firstgid', tile set description was ignored")
                return
            }

            self._currentFirstGID = firstGID

        case "tile":
            if self._isParsingLayer {
                defer {
                    // Compute the position of the next tile to place.
                    if self._currentCoordinates.x >= self._worldSize.x - 1 {
                        self._currentCoordinates.x = 0
                        self._currentCoordinates.y += 1
                    } else {
                        self._currentCoordinates.x += 1
                    }
                }

                // Parse the GID of the tile definition.
                guard let gid = readInt("gid", from: attributeDict) else {
                    self._log(
                        "missing or invalid property 'gid', tile at position " +
                        "\(self._currentCoordinates) wasn't placed")
                    return
                }

                // If the parsed gid is 0, there's no tile to place.
                if gid == 0 {
                    return
                }

                // Retrieve the tile definition.
                guard let tileDefinition = self._tileDefinitions[gid] else {
                    self._log(
                        "unassigned gid, tile at position " +
                        "\(self._currentCoordinates) wasn't placed")
                    return
                }

                // Place the new tile at the current poistion.
                let tile = IKHandle(on: SKSpriteNode(texture: tileDefinition.texture))
                tile.coordinates = self._currentCoordinates
                tile.target.userData = tileDefinition.userData

                self._layers.last!.addChild(tile)

            } else if let firstGID = self._currentFirstGID {
                // Parse the ID of a tile definition, within its tileset.
                guard let id = readInt("id", from: attributeDict) else {
                    self._log("missing or invalid property 'id', tile definition was ignored")
                    return
                }

                // Create a tile definition for the computed tile GID.
                self._currentTileDefinition = TileDefinition()
                self._tileDefinitions[firstGID + id] = self._currentTileDefinition
            }

        case "image":
            // Parse the file path of the image.
            guard let source = attributeDict["source"] else {
                self._log("missing property 'source', texture was ignored")
                return
            }

            var path = (source as NSString).pathComponents
            guard let last = path.popLast()?.components(separatedBy: ".").first else {
                self._log("invalid texture name '\(source), texture was ignored'")
                return
            }

            self._currentTileDefinition!.texture = texture(fromPath: path + [last])

        case "property":
            guard
                let name = attributeDict["name"],
                let value = attributeDict["value"] else {
                    self._log("custom property was ignored because it couldn't be parsed")
                    return
            }

            if let tileDefintion = self._currentTileDefinition {
                if tileDefintion.userData == nil {
                    tileDefintion.userData = NSMutableDictionary()
                }

                let propertyType = attributeDict["type"] ?? "string"
                switch propertyType {
                case "int":
                    tileDefintion.userData![name] = Int(value)
                case "float":
                    tileDefintion.userData![name] = Float(value)
                case "bool":
                    tileDefintion.userData![name] = (value == "true")
                default:
                    tileDefintion.userData![name] = value
                }
            } else {
                // TODO: Handle custom properties on maps, layers, objectgroups and objects.
                self._log("custom property was ignored")
            }

        case "layer", "objectgroup":
            let layer = IKHandle()

            // Parse the layer's offset.
            if let offsetX = readInt("offsetx", from: attributeDict) {
                layer.target.position.x = CGFloat(offsetX)
            }
            if let offsetY = readInt("offsety", from: attributeDict) {
                layer.target.position.y = CGFloat(offsetY)
            }

            // If the name of the layer ends with "+n" (where n is any number), we'll interpret n
            // as the z-coordinate of its elements.
            let name = attributeDict["name"]
            if let suffix = name?.range(of: "\\+\\d+", options: .regularExpression) {
                let z = CGFloat(Int(String(name!.substring(with: suffix).characters.dropFirst()))!)

                // Update the maximum z-coordinate of the world size.
                self._worldSize.z = max(self._worldSize.z, z)

                // Correct the layer's y-offset so that the shift due to the z-coordinate is
                // applied correctly.
                layer.target.position.y += z * self._tileSize.height
                layer.coordinates.z = z
            }

            layer.target.name = name
            self._layers.append(layer)
            self._isParsingLayer = true

        case "object":
            var handle: IKHandle? = nil

            // If the object has a property "gid", we'll fetch the corresponding texture to create
            // an SKSpriteNode.
            if let gid = readInt("gid", from: attributeDict) {
                if let width = readInt("width", from: attributeDict),
                   let height = readInt("height", from:attributeDict) {
                    handle = IKHandle(on: SKSpriteNode(
                        texture: self._tileDefinitions[gid]?.texture,
                        size: CGSize(width: width, height: height)))
                } else {
                    handle = IKHandle(on: SKSpriteNode(
                        texture: self._tileDefinitions[gid]?.texture))
                }
            } else {
                handle = IKHandle()
            }

            handle!.target.name = attributeDict["name"]

            // Parse the object position.
            if let x = readInt("x", from: attributeDict),
                let y = readInt("y", from: attributeDict) {
                switch self._spaceType {
                case .diamond:
                    handle!.coordinates.x = CGFloat(x) / self._tileSize.height - 1
                    handle!.coordinates.y = CGFloat(y) / self._tileSize.height - 1
                }
            } else {
                self._log(
                    "object \(attributeDict["id"]!) was ignored because its position couldn't " +
                    "be parsed")
                return
            }

            self._layers.last!.addChild(handle!)

        default:
            break
        }
    }

    public func parser(
        _ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
        qualifiedName qName: String?) {

        switch elementName {
        case "map":
            self._space = IKSpace(
                tileSize: self._tileSize,
                worldSize: self._worldSize,
                type: self._spaceType)

            for layer in self._layers {
                self._space!.addChild(layer)
            }

        case "tileset":
            self._currentFirstGID = nil

        case "tile":
            self._currentTileDefinition = nil

        case "layer", "objectgroup":
            self._isParsingLayer = false
            self._currentCoordinates = IKVector3.zero

        default:
            break
        }
    }

    private func _log(_ message: String, level: String = "warning") {
        if let parser = self._parser {
            print("IKTMXParser: (\(level)) \(message), line \(parser.lineNumber)")
        } else {
            print("IKTMXParser: (\(level)) \(message)")
        }
    }

}


// MARK: Helper functions

func readInt(_ attributeName: String, from attributeDict: [String: String]) -> Int? {
    if let value = attributeDict[attributeName] {
        return Int(value)
    }
    return nil
}


func texture(fromPath path: [String]) -> SKTexture? {
    var filename = ""

    for component in path.reversed() {
        filename = component + filename
        #if os(iOS) || os(watchOS) || os(tvOS)
            if let image = UIImage(named: filename) {
                return SKTexture(image: image)
            }
        #elseif os(OSX)
            if let image = NSImage(named: filename) {
                return SKTexture(image: image)
            }
        #endif

        filename = "/" + filename
    }

    return nil
}
