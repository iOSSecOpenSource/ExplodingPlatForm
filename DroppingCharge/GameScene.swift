/*
 * Copyright (c) 2015 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import SpriteKit
import CoreMotion
import GameplayKit

struct PhysicsCategory {
    static let None: UInt32              = 0
    static let Player: UInt32            = 0b1      // 1
    static let PlatformNormal: UInt32    = 0b10     // 2
    static let PlatformBreakable: UInt32 = 0b100    // 4
    static let CoinNormal: UInt32        = 0b1000   // 8
    static let CoinSpecial: UInt32       = 0b10000  // 16
    static let Edges: UInt32             = 0b100000 // 32
}

class GameScene: SKScene, SKPhysicsContactDelegate {
    
    // MARK: - Properties
    let cameraNode = SKCameraNode()
    var bgNode = SKNode()
    var fgNode = SKNode()
    var player: SKSpriteNode!
    var lava: SKSpriteNode!
    var background: SKNode!
    var backHeight: CGFloat = 0.0
    
    var platform5Across: SKSpriteNode!
    var coinArrow: SKSpriteNode!
    var platformArrow: SKSpriteNode!
    var platformDiagonal: SKSpriteNode!
    var breakArrow: SKSpriteNode!
    var break5Across: SKSpriteNode!
    var breakDiagonal: SKSpriteNode!
    var coin5Across: SKSpriteNode!
    var coinDiagonal: SKSpriteNode!
    var coinCross: SKSpriteNode!
    var coinS5Across: SKSpriteNode!
    var coinSDiagonal: SKSpriteNode!
    var coinSCross: SKSpriteNode!
    var coinSArrow: SKSpriteNode!
    
    var lastItemPosition = CGPointZero
    var lastItemHeight: CGFloat = 0.0
    var levelY: CGFloat = 0.0
    let motionManager = CMMotionManager()
    var xAcceleration = CGFloat(0)
    var lastUpdateTimeInterval: NSTimeInterval = 0
    var deltaTime: NSTimeInterval = 0
    var isPlaying: Bool = false
    

    
    lazy var gameState: GKStateMachine = GKStateMachine(states: [
        WaitingForTap(scene: self),
        WaitingForBomb(scene: self),
        Playing(scene: self),
        GameOver(scene: self)
        ])
    
//    lazy var playerState: GKStateMachine = GKStateMachine(states: [
//        Idle(scene: self),
//        Jump(scene: self),
//        Fall(scene: self),
//        Lava(scene: self),
//        Dead(scene: self)
//        ])
    
    var lives = 3
    
    func updateLevel() {
        let cameraPos = getCameraPosition()
        if cameraPos.y > levelY - (size.height * 0.55) {
            createBackgroundNode()
            while lastItemPosition.y < levelY {
                addRandomOverlayNode()
            }
        }
    }
    
    
    override func didMoveToView(view: SKView) {
        setupNodes()
        setupLevel()
        // This code will center the camera. To make sure that the camera is tracking y
        setCameraPosition(CGPoint(x: size.width/2, y: size.height/2))
        updateCamera()
        setupCoreMotion()
        physicsWorld.contactDelegate = self
        gameState.enterState(WaitingForTap)
        setupPlayer()
        //playerState.enterState(Idle)
        
    }
    
    
    func setupPlayer() {
        player.physicsBody = SKPhysicsBody(circleOfRadius:
            player.size.width * 0.3)
        player.physicsBody!.dynamic = false
        player.physicsBody!.allowsRotation = false
        player.physicsBody!.categoryBitMask = 0
        player.physicsBody!.collisionBitMask = 0
    }
    
    
    
    func setupCoreMotion() {
        motionManager.accelerometerUpdateInterval = 0.2
        let queue = NSOperationQueue()
        motionManager.startAccelerometerUpdatesToQueue(queue, withHandler:
            {
                accelerometerData, error in
                guard let accelerometerData = accelerometerData else {
                    return
                }
                let acceleration = accelerometerData.acceleration
                self.xAcceleration = (CGFloat(acceleration.x) * 0.75) +
                    (self.xAcceleration * 0.25)
        })
    }
    
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event:
        UIEvent?) {
        switch gameState.currentState {
        case is WaitingForTap:
            gameState.enterState(WaitingForBomb)
            // Switch to playing state
            self.runAction(SKAction.waitForDuration(2.0),
                           completion:{
                            self.gameState.enterState(Playing)
            })
        default:
            break
        } }
    
    
    func bombDrop() {
        let scaleUp = SKAction.scaleTo(1.25, duration: 0.25)
        let scaleDown = SKAction.scaleTo(1.0, duration: 0.25)
        let sequence = SKAction.sequence([scaleUp, scaleDown])
        let repeatSeq = SKAction.repeatActionForever(sequence)
        fgNode.childNodeWithName("Bomb")!.runAction(SKAction.unhide())
        fgNode.childNodeWithName("Bomb")!.runAction(repeatSeq)
        runAction(SKAction.sequence([
            SKAction.waitForDuration(2.0),
            SKAction.runBlock(startGame)
            ]))
    }
    func startGame() {
        fgNode.childNodeWithName("Title")!.removeFromParent()
        fgNode.childNodeWithName("Bomb")!.removeFromParent()
        isPlaying = true
        player.physicsBody!.dynamic = true
    }
    
    func updatePlayer() {
        // Set velocity based on core motion
        player.physicsBody?.velocity.dx = xAcceleration * 1000.0
        // Wrap player around edges of screen
        var playerPosition = convertPoint(player.position,
                                          fromNode: fgNode)
        if playerPosition.x < -player.size.width/2 {
            playerPosition = convertPoint(CGPoint(x: size.width +
                player.size.width/2, y: 0.0), toNode: fgNode)
            player.position.x = playerPosition.x
        }
        else if playerPosition.x > size.width + player.size.width/2 {
            playerPosition = convertPoint(CGPoint(x:
                -player.size.width/2, y: 0.0), toNode: fgNode)
            player.position.x = playerPosition.x
        }
    }
    func overlapAmount() -> CGFloat {
        guard let view = self.view else {
            return 0 }
        let scale = view.bounds.size.height / self.size.height
        let scaledWidth = self.size.width * scale
        let scaledOverlap = scaledWidth - view.bounds.size.width
        return scaledOverlap / scale
    }
    func getCameraPosition() -> CGPoint {
        return CGPoint(
            x: cameraNode.position.x + overlapAmount()/2,
            y: cameraNode.position.y)
    }
    override func update(currentTime: NSTimeInterval) {
        if lastUpdateTimeInterval > 0 {
            deltaTime = currentTime - lastUpdateTimeInterval
        } else {
            deltaTime = 0
        }
        lastUpdateTimeInterval = currentTime
        if paused { return }
        gameState.updateWithDeltaTime(deltaTime)
    }
    
    func setCameraPosition(position: CGPoint) {
        cameraNode.position = CGPoint(
            x: position.x - overlapAmount()/2,
            y: position.y)
    }
    func updateCamera() {
        // 1
        let cameraTarget = convertPoint(player.position,
                                        fromNode: fgNode)
        // 2
        var targetPosition = CGPoint(x: getCameraPosition().x,
                                     y: cameraTarget.y - (scene!.view!.bounds.height * 0.40))
        // 3
        let diff = targetPosition - getCameraPosition()
        // 4
        let lerpValue = CGFloat(0.05)
        let lerpDiff = diff * lerpValue
        let newPosition = getCameraPosition() + lerpDiff
        // 5
        setCameraPosition(CGPoint(x: size.width/2, y: newPosition.y))
    }
    
//    adOverlayNode() takes the name of a scene file (such as Platform5Across) and looks for a node called "Overlay" inside, and then returns that node. Remember that you created an "Overlay" node in both of your scenes so far, and all the platforms/coins were children of this.
    
    func loadOverlayNode(fileName: String) -> SKSpriteNode {
        let overlayScene = SKScene(fileNamed: fileName)!
        let contentTemplateNode =
            overlayScene.childNodeWithName("Overlay")
        return contentTemplateNode as! SKSpriteNode
    }
    func createOverlayNode(nodeType: SKSpriteNode, flipX: Bool) {
        let platform = nodeType.copy() as! SKSpriteNode
        lastItemPosition.y = lastItemPosition.y +
            (lastItemHeight + (platform.size.height / 2.0))
        lastItemHeight = platform.size.height / 2.0
        platform.position = lastItemPosition
        if flipX == true {
            platform.xScale = -1.0
        }
        fgNode.addChild(platform)
    }
    
    func addRandomOverlayNode() {
        let overlaySprite: SKSpriteNode!
        let platformPercentage = 60
        if Int.random(min: 1, max: 100) <= platformPercentage {
            overlaySprite = platform5Across
        } else {
            overlaySprite = coinArrow
        }
        createOverlayNode(overlaySprite, flipX: false)
    }
    
    func createBackgroundNode() {
        let backNode = background.copy() as! SKNode
        backNode.position = CGPoint(x: 0.0, y: levelY)
        bgNode.addChild(backNode)
        levelY += backHeight
    }
    
    
    func setupNodes() {
        let worldNode = childNodeWithName("World")!
        bgNode = worldNode.childNodeWithName("Background")!
        background = bgNode.childNodeWithName("Overlay")!.copy() as! SKNode
        backHeight = background.calculateAccumulatedFrame().height
        fgNode = worldNode.childNodeWithName("Foreground")!
        player = fgNode.childNodeWithName("Player") as! SKSpriteNode
        //setupLava()
        fgNode.childNodeWithName("Bomb")?.runAction(SKAction.hide())
        addChild(cameraNode)
        camera = cameraNode
        
        coinArrow = loadOverlayNode("CoinArrow")
        platformArrow = loadOverlayNode("PlatformArrow")
        platform5Across = loadOverlayNode("Platform5Across")
        platformDiagonal = loadOverlayNode("PlatformDiagonal")
        breakArrow = loadOverlayNode("BreakArrow")
        break5Across = loadOverlayNode("Break5Across")
        breakDiagonal = loadOverlayNode("BreakDiagonal")
        //coinRef = loadOverlayNode("Coin")
//        coinSpecialRef = loadOverlayNode("CoinSpecial")
//        coin5Across = loadCoinOverlayNode("Coin5Across")
//        coinDiagonal = loadCoinOverlayNode("CoinDiagonal")
//        coinCross = loadCoinOverlayNode("CoinCross")
//        coinArrow = loadCoinOverlayNode("CoinArrow")
//        coinS5Across = loadCoinOverlayNode("CoinS5Across")
//        coinSDiagonal = loadCoinOverlayNode("CoinSDiagonal")
//        coinSCross = loadCoinOverlayNode("CoinSCross")
//        coinSArrow = loadCoinOverlayNode("CoinSArrow")
//        
 }
    
    
    
    
    //falling off the platform like that.
    func setPlayerVelocity(amount:CGFloat) {
        let gain: CGFloat = 1.5
        player.physicsBody!.velocity.dy =
            max(player.physicsBody!.velocity.dy, amount * gain)
    }
    func jumpPlayer() {
        setPlayerVelocity(650)
    }
    func boostPlayer() {
        setPlayerVelocity(1200)
    }
    func superBoostPlayer() {
        setPlayerVelocity(1700)
    }
    
    //This method places the platform right below the player, and updates lastItemPosition and lastItemHeight appropriately
    func setupLevel() {
        // Place initial platform
        let initialPlatform = platform5Across.copy() as! SKSpriteNode
        var itemPosition = player.position
        itemPosition.y = player.position.y -
            ((player.size.height * 0.5) +
                (initialPlatform.size.height * 0.20))
        initialPlatform.position = itemPosition
        fgNode.addChild(initialPlatform)
        lastItemPosition = itemPosition
        lastItemHeight = initialPlatform.size.height / 2.0
        // Create random level
        levelY = bgNode.childNodeWithName("Overlay")!.position.y + backHeight
        while lastItemPosition.y < levelY {
            addRandomOverlayNode()
        }
        
        
    }
    func updateLava(dt: NSTimeInterval) {
        // 1
        let lowerLeft = CGPoint(x: 0, y: cameraNode.position.y -
            (size.height / 2))
        // 2
        let visibleMinYFg = scene!.convertPoint(lowerLeft, toNode:
            fgNode).y
        // 3
        let lavaVelocity = CGPoint(x: 0, y: 120)
        let lavaStep = lavaVelocity * CGFloat(dt)
        var newPosition = lava.position + lavaStep
        // 4
        newPosition.y = max(newPosition.y, (visibleMinYFg - 125.0))
        // 5
        lava.position = newPosition
    }
    
    func updateCollisionLava() {
        if player.position.y < lava.position.y + 90 {
            boostPlayer()
        }
    }
    
    // Contact Collision
    func didBeginContact(contact: SKPhysicsContact) {
        let other = contact.bodyA.categoryBitMask ==
            PhysicsCategory.Player ? contact.bodyB : contact.bodyA
        switch other.categoryBitMask {
        case PhysicsCategory.CoinNormal:
            if let coin = other.node as? SKSpriteNode {
                coin.removeFromParent()
                jumpPlayer()
            }
        case PhysicsCategory.PlatformNormal:
            if let _ = other.node as? SKSpriteNode {
                if player.physicsBody!.velocity.dy < 0 {
                    jumpPlayer()
                }
            } default:
                break; }
    }
}
