//
//  SpaceShip.swift
//  SpaceRover
//
//  Created by Hazen O'Malley on 6/4/17.
//  Copyright © 2017 Hazen O'Malley. All rights reserved.
//

import SpriteKit

struct SlantPoint: Equatable {
  var x: Int
  var y: Int

  static func ==(lhs: SlantPoint, rhs: SlantPoint) -> Bool {
    return lhs.x == rhs.x && lhs.y == rhs.y
  }

  static func +(lhs: SlantPoint, rhs: SlantPoint) -> SlantPoint {
    return SlantPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
  }
}

enum SpaceshipColor {
  case blue,red,green;
}

extension SpaceshipColor {
  func image() -> SKTexture {
    switch (self) {
    case .blue:
      return SKTexture(imageNamed: "SpaceshipUpRight")
    case .red:
      return SKTexture(imageNamed: "SpaceshipRed")
    case .green:
      return SKTexture(imageNamed: "SpaceshipGreen")
    }
  }
}

enum HexDirection: Int {
  case NoAcc, West, NorthWest, NorthEast, East, SouthEast, SouthWest;
}

extension HexDirection {
  static func all() -> AnySequence<HexDirection> {
    return AnySequence {
      return HexDirectionGenerator()
    }
  }
  


  struct HexDirectionGenerator: IteratorProtocol {
    var currentSection = 0

    mutating func next() -> HexDirection? {
      guard let item = HexDirection(rawValue:currentSection) else {
        return nil
      }
      currentSection += 1
      return item
    }
  }

  func invert() -> HexDirection {
    switch (self) {
    case .NoAcc:
      return .NoAcc
    case .NorthEast:
      return .SouthWest
    case .NorthWest:
      return .SouthEast
    case .West:
      return .East
    case .East:
      return .West
    case .SouthWest:
      return .NorthEast
    case .SouthEast:
      return .NorthWest
    }
  }

  func clockwise(turns: Int) -> HexDirection {
    if (self == .NoAcc) {
      return .NoAcc
    } else {
      var newValue = ((self.rawValue - 1) + turns) % 6
      if (newValue < 0) {
        newValue += 6
      }
      return HexDirection(rawValue: newValue + 1)!
    }
  }

  func rotateAngle() -> Double {
    switch (self) {
    case .NoAcc:
      return 0
    case .NorthEast:
      return 0
    case .East:
      return 5*Double.pi/3
    case .SouthEast:
      return 4*Double.pi/3
    case .SouthWest:
      return 3*Double.pi/3
    case .West:
      return 2*Double.pi/3
    case .NorthWest:
      return 1*Double.pi/3
    }
  }

  /**
   * Get the SlantPoint vector going in this direction
   */
  func toSlant() -> SlantPoint {
    switch (self) {
    case .NoAcc:
      return SlantPoint(x: 0, y: 0)
    case .NorthEast:
      return SlantPoint(x: 1, y: 1)
    case .East:
      return SlantPoint(x: 1, y: 0)
    case .SouthEast:
      return SlantPoint(x: 0, y: -1)
    case .SouthWest:
      return SlantPoint(x: -1, y: -1)
    case .West:
      return SlantPoint(x: -1, y: 0)
    case .NorthWest:
      return SlantPoint(x: 0, y: 1)
    }
  }
}

func slantToView(_ pos: SlantPoint, tiles: SKTileMapNode) -> CGPoint {
  return tiles.centerOfTile(atColumn: pos.x - ((pos.y+1) / 2), row: pos.y)
}

/**
 * Compute the relative position of a direction in the view's coordinates.
 */
func findRelativePosition(_ direction: HexDirection, tiles: SKTileMapNode) -> CGPoint {
  // pick a point that won't cause the relative points to go out of bounds
  let originSlant = SlantPoint(x: 2, y: 2)
  // get the relative slant point
  let slant = originSlant + direction.toSlant()
  let posn = slantToView(slant, tiles: tiles)
  // subtract off the origin
  let origin = slantToView(originSlant, tiles: tiles)
  return CGPoint(x: posn.x - origin.x, y: posn.y - origin.y)
}

/**
 * Compute the distance from the origin measured in hex widths.
 */
func computeDistance(_ point: SlantPoint) -> Double {
  let y = Double(point.y) * sqrt(3.0) / 2.0
  let x = Double(point.x) - Double(point.y) / 2.0
  return hypot(x, y)
}

let shipContactMask: UInt32 = 1
let planetContactMask: UInt32 = 2
let gravityContactMask: UInt32 = 4
let accelerationContactMask: UInt32 = 8
let asteroidsContactMask: UInt32 = 16

protocol ShipInformationWatcher {
  func updateShipInformation(_ msg: String)
  func crash(reason:String, ship:SpaceShip)
  func startTurn(player: String)
  func endGame(_ : String)
}

let UiFontName = "Copperplate"

class SpaceShip: SKSpriteNode {

  let tileMap: SKTileMapNode
  let fuelCapacity = 20
  var arrows : DirectionKeypad?

  var slant: SlantPoint
  var velocity: SlantPoint
  var direction = HexDirection.NorthEast
  var fuel: Int
  var watcher: ShipInformationWatcher?
  var inMotion = false
  var orbitAround: Planet?
  var hasLanded = false
  var isDead = false
  var turnsDisabled = 0

  convenience init(name: String, on: Planet, tiles: SKTileMapNode, color: SpaceshipColor) {
    self.init(name: name, slant: on.slant, tiles: tiles, color: color)
    orbitAround = on
    hasLanded = true
    arrows?.setLaunchButtons(planet: on)
  }

  init (name: String, slant: SlantPoint, tiles: SKTileMapNode, color: SpaceshipColor) {
    tileMap = tiles
    self.slant = slant
    velocity = SlantPoint(x: 0, y: 0)
    let texture = color.image()
    fuel = fuelCapacity
    super.init(texture: texture, color: UIColor.clear, size: texture.size())
    self.name = name
    position = slantToView(slant, tiles: tileMap)
    tileMap.addChild(self)
    arrows = DirectionKeypad(ship: self)
    arrows!.position = self.position
    arrows!.isHidden = true
    tileMap.addChild(arrows!)
    zPosition = 20
    physicsBody = SKPhysicsBody(circleOfRadius: 5)
    physicsBody?.categoryBitMask = shipContactMask
    physicsBody?.contactTestBitMask = planetContactMask | gravityContactMask | asteroidsContactMask
    physicsBody?.collisionBitMask = 0
    arrows?.detectOverlap()
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func setWatcher(_ newWatcher: ShipInformationWatcher?) {
    watcher = newWatcher
    watcher?.updateShipInformation(getInformation())
  }

  func getAccellerationPosition(direction: HexDirection) -> CGPoint {
    let newVelocity = velocity + direction.toSlant()
    let newPosition = slant + newVelocity
    return slantToView(newPosition, tiles: tileMap)
  }

  func enterGravity(_ gravity: GravityArrow) {
    if (!hasLanded) {
      print("\(self.name!) hit \(gravity.name!)")
      accelerateShip(direction: gravity.direction)
    }
  }

  func accelerateShip(direction: HexDirection) {
    velocity = velocity + direction.toSlant()
    moveAccArrows()
  }

  func calculateOrbit() {
    for body in physicsBody!.allContactedBodies() {
      if let gravity = body.node as? GravityArrow {
        // Is the velocity 60 degrees from the gravity?
        let clockwise = gravity.direction.clockwise(turns: 1).toSlant()
        let counterClockwise = gravity.direction.clockwise(turns: -1).toSlant()
        if velocity == clockwise || velocity == counterClockwise {
          orbitAround = gravity.planet
          return
        }
      }
    }
    orbitAround = nil
  }

  func rotateShip (_ newDirection : HexDirection) {
    if newDirection != direction && newDirection != HexDirection.NoAcc {
      var rotateBy = (newDirection.rotateAngle() - direction.rotateAngle())
      if (rotateBy >= 0) {
        while (rotateBy > Double.pi) {
          rotateBy -= 2*Double.pi
        }
      } else {
        while (rotateBy < -Double.pi) {
          rotateBy += 2*Double.pi
        }
      }
      direction = newDirection
      self.run(SKAction.rotate(byAngle: CGFloat(rotateBy), duration: 0.5))
    }
  }

  func getInformation() -> String {
    if let planet = orbitAround {
      if (hasLanded) {
        return "\(name!)\nFuel: \(fuel)\nOn \(planet.name!)"
      } else {
        return "\(name!)\nFuel: \(fuel)\n\(planet.name!) orbit"
      }
    } else {
      return "\(name!)\nFuel: \(fuel)\nSpeed: \(computeDistance(velocity))"
    }
  }

  func useFuel(_ units: Int) {
    fuel -= units
    calculateOrbit()
    if (fuel == 0) {
      arrows?.outOfFuel()
      //"We're outta rockets sir."
    }
  }

  func moveAccArrows(){
    arrows?.removeAllActions()
    arrows?.run(
        SKAction.move(to: getAccellerationPosition(direction: HexDirection.NoAcc), duration: 1))
  }

  func move() {
    print("moving \(name!) by \(velocity)")
    if !hasLanded {
      arrows?.removeLandingButtons()
      inMotion = true
      slant = slant + velocity
      run(SKAction.move(to: slantToView(slant, tiles: tileMap), duration: 1))
      // if the player tries to hover over a planet, the gravity needs to pull them again
      if velocity.x == 0 && velocity.y == 0 {
        for body in physicsBody!.allContactedBodies() {
          if let gravity = body.node as? GravityArrow {
            velocity = gravity.direction.toSlant()
          }
        }
      }
      self.moveAccArrows()
      //vroom vroom
    }
  }

  func startTurn() {
    print("start turn for \(name!)")
    arrows?.isHidden = false
    watcher?.updateShipInformation(getInformation())
  }

  func endTurn() {
    inMotion = false
    arrows?.detectOverlap()
    arrows?.isHidden = true
    if(turnsDisabled > 0) {
      turnsDisabled -= 1
    }
    else if(turnsDisabled == 0) {
      arrows?.reenable()
    }
    print("end turn for \(name!)")
  }
  
  func landOn(planet: Planet) {
    print("Land \(name!) on \(planet.name!)")
    hasLanded = true
    fuel = fuelCapacity
    slant = planet.slant
    position = planet.position
    velocity = SlantPoint(x: 0, y: 0)
    arrows?.removeLandingButtons()
    watcher?.updateShipInformation(getInformation())
    moveAccArrows()
    arrows?.setLaunchButtons(planet: planet)
    inMotion = true
  }

  func launch(planet: Planet, direction: HexDirection) {
    print("Launching \(name!) from \(planet.name!)")
    hasLanded = false
    orbitAround = nil
    slant = slant + direction.toSlant()
    velocity = direction.invert().toSlant()
    position = slantToView(slant, tiles: tileMap)
    arrows?.removeLandingButtons()
    arrows?.position = slantToView(slant + velocity, tiles: tileMap)
    arrows?.detectOverlap()
    inMotion = true
  }
  
  func crash(reason:String) {
    if (!hasLanded) {
      print(reason)
      isDead = true
      isHidden = true
      arrows?.isHidden = true
      watcher?.crash(reason: reason, ship: self)
    }
  }

  func disable(turns: Int) {
    print("Disabled for \(turns) turns")
    arrows?.outOfFuel()
    turnsDisabled += turns
    
    if(turnsDisabled >= 6)
    {
      self.crash(reason: " Your ship,  \(name!), burned up in the Asteroid Fields!")
    }
  }

  func enterAsteroids(_ asteroid: Asteroid) {
    if computeDistance(velocity) > 1 {
      print("\(name!) entered \(asteroid.name!)")
      let die = arc4random_uniform(6)
      switch die {
      case 4:
        disable(turns: 1)
      case 5:
        disable(turns: 2)
      default:
        break
      }
    }
  }
}

class Planet: SKSpriteNode {
  var slant: SlantPoint

  convenience init(name: String, slant: SlantPoint, tiles: SKTileMapNode, radius: Int) {
    self.init(name:name, image:name, slant:slant, tiles:tiles, radius:radius)
  }

  init(name: String, image: String, slant: SlantPoint, tiles: SKTileMapNode, radius: Int) {
    let texture = SKTexture(imageNamed: image)
    self.slant = slant
    super.init(texture: texture, color: UIColor.clear, size: (texture.size()))
    let nameLabel = SKLabelNode(text: name)
    nameLabel.zPosition = 1
    nameLabel.position = CGPoint(x: 0, y: 25)
    nameLabel.fontSize = 20
    nameLabel.fontName = UiFontName
    addChild(nameLabel)
    self.name = name
    position = slantToView(slant, tiles: tiles)
    zPosition = 10
    for direction in HexDirection.all() {
      if direction != HexDirection.NoAcc {
        let posn = findRelativePosition(direction.invert(), tiles: tiles)
        addChild(GravityArrow(direction: direction, planet: self, position: posn))
      }
    }
    physicsBody = SKPhysicsBody(circleOfRadius: CGFloat(radius))
    physicsBody?.categoryBitMask = planetContactMask
    physicsBody?.contactTestBitMask = shipContactMask | accelerationContactMask
    physicsBody?.collisionBitMask = 0
    physicsBody?.isDynamic = false
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

class Asteroid: SKSpriteNode {

  static let textures = [SKTexture(imageNamed: "Asteroids1"), SKTexture(imageNamed: "Asteroids2")]

  init(slant: SlantPoint, tiles: SKTileMapNode) {
    let texture = Asteroid.textures[Int(arc4random_uniform(2))]
    super.init(texture: texture, color: UIColor.clear, size: texture.size())
    name = "asteroid at \(slant.x), \(slant.y)"
    position = slantToView(slant, tiles: tiles)
    zPosition = 10
    physicsBody = SKPhysicsBody(circleOfRadius: 55)
    physicsBody?.categoryBitMask = asteroidsContactMask
    physicsBody?.contactTestBitMask = shipContactMask
    physicsBody?.collisionBitMask = 0
    physicsBody?.isDynamic = false
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

class GravityArrow: SKSpriteNode {
  let direction: HexDirection
  let planet: Planet

  init(direction: HexDirection, planet: Planet, position: CGPoint) {
    self.direction = direction
    self.planet = planet
    let texture = SKTexture(imageNamed: "GravityArrow")
    // Create the hexagon with the additional wedge toward the planet
    let bodyShape = CGMutablePath()
    bodyShape.addLines(between: [CGPoint(x:111, y:0),
                                 CGPoint(x:0, y:-64),
                                 CGPoint(x:-55, y:-32),
                                 CGPoint(x:-55, y:32),
                                 CGPoint(x:0, y:64),
                                 CGPoint(x:111, y:0)])
    super.init(texture: texture, color: UIColor.clear, size: (texture.size()))
    self.name = "Gravity \(direction) toward \(planet.name!)"
    zPosition = 10
    alpha = 0.6
    self.position = position
    physicsBody = SKPhysicsBody(polygonFrom: bodyShape)
    physicsBody?.categoryBitMask = gravityContactMask
    physicsBody?.contactTestBitMask = shipContactMask
    physicsBody?.collisionBitMask = 0
    physicsBody?.isDynamic = false
    let sixtyDegree = Double.pi / 3
    run(SKAction.rotate(byAngle: CGFloat(sixtyDegree + direction.rotateAngle()), duration: 0))
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

class DirectionKeypad: SKNode {
  var isOutOfFuel = false

  init(ship: SpaceShip) {
    super.init()
    name = "DirectionKeypad for \(ship.name!)"
    alpha = 1
    zPosition = 50
    isUserInteractionEnabled = true
    for childDir in HexDirection.all() {
      addChild(DirectionArrow(ship: ship, direction: childDir))
    }
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func outOfFuel() {
    isOutOfFuel = true
    for child in children {
      if let arrow = child as? DirectionArrow {
        if arrow.direction != .NoAcc {
          arrow.isHidden = true
        }
      }
    }
  }

  func refuelled() {
    isOutOfFuel = false
    for child in children {
      if let arrow = child as? DirectionArrow {
        if arrow.direction != .NoAcc {
          arrow.isHidden = false
        }
      }
    }
  }
  
  func reenable() {
    for child in children {
      if let arrow = child as? DirectionArrow {
        if arrow.direction != .NoAcc {
          arrow.isHidden = false
        }
      }
    }
  }

  func detectOverlap() {
    if !isOutOfFuel {
      for child in children {
        if let arrow = child as? DirectionArrow {
          arrow.detectOverlap()
        }
      }
    }
  }

  func removeLandingButtons() {
    for child in children {
      if let button = child as? MovementButton {
        button.removeSelf()
      }
    }
  }

  func setLaunchButtons(planet: Planet) {
    for child in children {
      if let arrow = child as? DirectionArrow {
        if arrow.direction != .NoAcc {
          addChild(LaunchButton(arrow: arrow, planet: planet))
        }
      }
    }
  }
}

/**
 * The arrows that let the user pick the direction.
 */
class DirectionArrow: SKSpriteNode{
  let direction: HexDirection
  let ship: SpaceShip

  /**
   * Constructor for the children arrows
   */
  init(ship: SpaceShip, direction: HexDirection) {
    self.ship = ship
    self.direction = direction
    if (direction == HexDirection.NoAcc) {
      let texture = SKTexture(imageNamed: "NoAccelerationSymbol")
      super.init(texture: texture, color: UIColor.clear, size: (texture.size()))
    } else {
      let texture = SKTexture(imageNamed: "MovementArrow")
      super.init(texture: texture, color: UIColor.clear, size: (texture.size()))
    }
    name = "\(direction) arrow for \(ship.name!)"
    alpha = 0.4

    self.run(SKAction.rotate(toAngle: CGFloat(direction.rotateAngle()), duration: 0))
    isUserInteractionEnabled = true
    position = findRelativePosition(direction, tiles: ship.tileMap)
    physicsBody = createPhysics()
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func createPhysics() -> SKPhysicsBody {
    let newPhysicsBody = SKPhysicsBody(circleOfRadius: 10)
    newPhysicsBody.categoryBitMask = accelerationContactMask
    newPhysicsBody.contactTestBitMask = planetContactMask
    newPhysicsBody.collisionBitMask = 0
    newPhysicsBody.isDynamic = true
    return newPhysicsBody
  }

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    /* Called when a touch begins */
    for _ in touches {
      if (!ship.inMotion) {
        if (direction != HexDirection.NoAcc) {
          ship.accelerateShip(direction: direction)
          ship.useFuel(1)
          ship.rotateShip(direction)
        }
        ship.move()
      }
    }
  }

  func detectOverlap() {
    if let dirKeypad = parent as? DirectionKeypad {
      for body in physicsBody!.allContactedBodies() {
        if let planet = body.node as? Planet {
          if ship.orbitAround == planet {
            dirKeypad.addChild(LandButton(arrow: self, planet: planet))
          } else {
            dirKeypad.addChild(CrashButton(arrow: self, planet: planet))
          }
        }
      }
    }
  }
}

class MovementButton: SKLabelNode {
  let arrow: DirectionArrow
  let planet: Planet
  
  init(msg: String, color: UIColor, arrow: DirectionArrow, planet: Planet) {
    self.arrow = arrow
    self.planet = planet
    super.init()
    text = msg
    fontName = UiFontName
    fontSize = 20
    fontColor = color
    position = arrow.position
    isUserInteractionEnabled = true
    arrow.isHidden = true
    // Put a shape under the button so that it is easier to push
    let shape = SKShapeNode(circleOfRadius: 50)
    shape.alpha = 0.0000001
    addChild(shape)
  }
  
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  func removeSelf() {
    if let pad = parent as? DirectionKeypad {
      removeFromParent()
      if !pad.isOutOfFuel {
        arrow.isHidden = false
      }
    }
  }
}

class CrashButton: MovementButton {
  init(arrow: DirectionArrow, planet: Planet) {
    super.init(msg: "Crash", color: UIColor.red, arrow: arrow, planet: planet)
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    arrow.touchesBegan(touches, with: event)
  }
}

class LandButton: MovementButton {
  init(arrow: DirectionArrow, planet: Planet) {
    super.init(msg: "Land", color: UIColor.green, arrow: arrow, planet: planet)
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    arrow.ship.landOn(planet: planet)
  }
}

class LaunchButton: MovementButton {
  init(arrow: DirectionArrow, planet: Planet) {
    super.init(msg: "Launch", color: UIColor.green, arrow: arrow, planet: planet)
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    arrow.ship.launch(planet: planet, direction: arrow.direction)
  }
}
