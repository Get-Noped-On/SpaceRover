//
//  GameScene.swift
//  SpaceRover
//
//  Created by Hazen O'Malley on 5/28/17.
//  Copyright (c) 2017 Hazen O'Malley. All rights reserved.
//

import SpriteKit

class Player {
  let ship: SpaceShip
  let info: PlayerInfo
  var visited: Set<Planet> = Set()

  init(_ description: PlayerInfo, on: Planet) {
    info = description
    ship = SpaceShip(name: info.shipName, on: on, tiles: on.parent as! SKTileMapNode,
                     color: info.color)
  }
}

class GameScene: SKScene, SKPhysicsContactDelegate {

  let planetLocations = [
    "Sol": (SlantPoint(x:39, y:23), 55),
    "Mercury": (SlantPoint(x:40, y:20), 15),
    "Venus": (SlantPoint(x:31, y:19), 25),
    "Earth": (SlantPoint(x:51, y:29), 25),
    "Luna": (SlantPoint(x:54, y:30), 10),
    "Mars": (SlantPoint(x:40, y:43), 20),
    "Jupiter": (SlantPoint(x:59, y:59), 45),
    "Callisto": (SlantPoint(x:54, y:59), 10),
  ]

  let asteroids = [
    SlantPoint(x: 47, y:41),
    SlantPoint(x: 49, y:41),
    SlantPoint(x: 46, y:42),
    SlantPoint(x: 50, y:42),
    SlantPoint(x: 53, y:42),
    SlantPoint(x: 55, y:42),
    SlantPoint(x: 56, y:42),
    SlantPoint(x: 48, y:43),
    SlantPoint(x: 50, y:43),
    SlantPoint(x: 53, y:43),
    SlantPoint(x: 56, y:43),
    SlantPoint(x: 59, y:43),
    SlantPoint(x: 65, y:43),
    SlantPoint(x: 46, y:44),
    SlantPoint(x: 50, y:44),
    SlantPoint(x: 51, y:44),
    SlantPoint(x: 54, y:44),
    SlantPoint(x: 57, y:44),
    SlantPoint(x: 59, y:44),
    SlantPoint(x: 61, y:44),
    SlantPoint(x: 65, y:44),
    SlantPoint(x: 66, y:44),
    SlantPoint(x: 37, y:45),
    SlantPoint(x: 48, y:45),
    SlantPoint(x: 51, y:45),
    SlantPoint(x: 52, y:45),
    SlantPoint(x: 53, y:45),
    SlantPoint(x: 55, y:45),
    SlantPoint(x: 65, y:45),
    SlantPoint(x: 68, y:45),
    SlantPoint(x: 69, y:45),
    SlantPoint(x: 36, y:46),
    SlantPoint(x: 37, y:46),
    SlantPoint(x: 38, y:46),
    SlantPoint(x: 47, y:46),
    SlantPoint(x: 49, y:46),
    SlantPoint(x: 59, y:46),
    SlantPoint(x: 62, y:46),
    SlantPoint(x: 67, y:46),
    SlantPoint(x: 38, y:47),
    SlantPoint(x: 52, y:47),
    SlantPoint(x: 55, y:47),
    SlantPoint(x: 57, y:47),
    SlantPoint(x: 59, y:47),
    SlantPoint(x: 60, y:47),
    SlantPoint(x: 62, y:47),
    SlantPoint(x: 63, y:47),
    SlantPoint(x: 65, y:47),
    SlantPoint(x: 39, y:48),
    SlantPoint(x: 41, y:48),
    SlantPoint(x: 42, y:48),
    SlantPoint(x: 57, y:48),
    SlantPoint(x: 62, y:48),
    SlantPoint(x: 64, y:48),
    SlantPoint(x: 65, y:48),
    SlantPoint(x: 68, y:48),
    SlantPoint(x: 68, y:48),
    SlantPoint(x: 69, y:48),
    SlantPoint(x: 70, y:48),
    SlantPoint(x: 43, y:49),
    SlantPoint(x: 45, y:49),
    SlantPoint(x: 48, y:49),
    SlantPoint(x: 60, y:49),
    SlantPoint(x: 63, y:49),
    SlantPoint(x: 64, y:49),
    SlantPoint(x: 67, y:49),
    SlantPoint(x: 38, y:50),
    SlantPoint(x: 39, y:50),
    SlantPoint(x: 41, y:50),
    SlantPoint(x: 59, y:50),
    SlantPoint(x: 40, y:51),
    SlantPoint(x: 39, y:52),
    SlantPoint(x: 40, y:52),
  ]

  var players: [Player] = []
  var nextPlayer = 0
  var tileMap:SKTileMapNode?
  var watcher: ShipInformationWatcher?
  var planets = [String: Planet]()

  override func didMove(to view: SKView) {
    /* Setup your scene here */
    for child in children {
      if child.name == "Tile Map" {
        tileMap = (child as! SKTileMapNode)
      }
    }
    tileMap?.isUserInteractionEnabled = true

    //Adding Planets
    for (name, (location, radius)) in planetLocations {
      let planet = Planet(name: name, slant: location, tiles: tileMap!, radius: radius)
      tileMap?.addChild(planet)
      planets[name] = planet
    }

    // Adding asteroids
    for location in asteroids {
      tileMap?.addChild(Asteroid(slant: location, tiles: tileMap!))
    }

    physicsWorld.contactDelegate = self
  }

  func startGame(watcher: ShipInformationWatcher?, names: [PlayerInfo]) {
    self.watcher = watcher
    let earth = planets["Earth"]
    for name in names {
      let player = Player(name, on: earth!)
      player.ship.setWatcher(watcher)
      players.append(player)
    }
    players[nextPlayer].ship.startTurn()
    watcher?.startTurn(player: players[nextPlayer].info.playerName)
  }
  
  let PAN_SLOWDOWN: CGFloat = 20.0
  let MIN_SCALE: CGFloat = 1.5
  let MAX_SCALE: CGFloat = 6.0

  //Pans around the screen
  func doPan(_ velocity: CGPoint) {
    camera?.run(SKAction.moveBy(x: -velocity.x/PAN_SLOWDOWN, y: velocity.y/PAN_SLOWDOWN, duration: 0.5))
  }

  //Moves in and out with the pinch gesture
  func doPinch(_ velocity: CGFloat) {
    let newScale = camera!.xScale - velocity
    if (newScale > MIN_SCALE && newScale < MAX_SCALE) {
      camera?.run(SKAction.scale(to: newScale, duration: 0.5))
    }
  }

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    /* Called when a touch begins */
    for _ in touches {
      print("outside touch")
    }
  }

  func getNextPlayer() -> Bool {
    for i in 1 ... players.count {
      let candidate = (nextPlayer + i) % players.count
      if !players[candidate].ship.isDead {
        nextPlayer = candidate
        camera?.run(SKAction.move(to: convert(players[nextPlayer].ship.position , from: tileMap!) , duration: 0.5))
        return true
      }
    }
    return false
  }

  override func update(_ currentTime: TimeInterval) {
    if nextPlayer < players.count {
      let ship = players[nextPlayer].ship
      if ship.inMotion && !ship.arrows!.hasActions() && !ship.hasActions() {
        ship.endTurn()
        if getNextPlayer() {
          watcher?.startTurn(player: players[nextPlayer].info.playerName)
          players[nextPlayer].ship.startTurn()
        } else {
          watcher?.endGame("Everyone died")
        }
      }
    }
  }

  func shipCollision(ship: SpaceShip, other: SKNode) {
    if let planet = other as? Planet {
      let reason = ("Ship \(ship.name!) crashed in to \(planet.name!)")
      ship.crash(reason: reason)
    } else if let gravity = other as? GravityArrow {
      ship.enterGravity(gravity)
    } else if let asteroid = other as? Asteroid {
      ship.enterAsteroids(asteroid)
    } else {
      print("contact between ship and ufo \(other.name!)")
    }
  }

  func directionArrowCollision(arrow: DirectionArrow, other: SKNode) {
    // We catch this later in DirectionArrow.detectOverlap
  }

  func didBegin(_ contact: SKPhysicsContact) {
    if let ship = contact.bodyA.node as? SpaceShip {
      shipCollision(ship: ship, other: contact.bodyB.node!)
    } else if let ship = contact.bodyB.node as? SpaceShip {
      shipCollision(ship: ship, other: contact.bodyA.node!)
    } else if let acceleration = contact.bodyA.node as? DirectionArrow {
      directionArrowCollision(arrow: acceleration, other: contact.bodyB.node!)
    } else if let acceleration = contact.bodyB.node as? DirectionArrow {
      directionArrowCollision(arrow: acceleration, other: contact.bodyA.node!)
    } else {
      print("contact between \(String(describing: contact.bodyA.node)) and \(String(describing: contact.bodyB.node))")
    }
  }
}
