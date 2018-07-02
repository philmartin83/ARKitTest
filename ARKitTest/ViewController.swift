//
//  ViewController.swift
//  ARKitTest
//
//  Created by Phil Martin on 02/07/2018.
//  Copyright © 2018 Phil Martin. All rights reserved.
//

import UIKit
import ARKit
import Vision

class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet weak var arView: ARSCNView!
    var prediction : String = "_"
    let textDepth : Float = 0.04
    
    @IBOutlet weak var predictionTV: UITextView!
    var coreMLRequest = [VNRequest]()
    let queueCoreML = DispatchQueue(label: "com.pm.dispatchquque")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically fro    m a nib.
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
        arView.delegate = self
        
        // display the FPS
        arView.showsStatistics = true
        
        let sceneV = SCNScene()
        arView.scene = sceneV
        
        // apply the tap gesture
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.handleTheTap(gesture:)))
        view.addGestureRecognizer(tapGesture)
        
        
        // get the model
        guard let model = try? VNCoreMLModel(for: Resnet50().model)else {return}
        
        
        let visionRequest = VNCoreMLRequest(model: model) { (request, error) in
            if error != nil {
                print("Error: " + (error?.localizedDescription)!)
                return
            }
            guard let observations = request.results else {
                print("No results")
                return
            }
            
            // Get Classifications
            let classifications = observations[0...1] // top 2 results
                .compactMap({ $0 as? VNClassificationObservation })
                .map({ "\($0.identifier) \(String(format:"- %.2f", $0.confidence))" })
                .joined(separator: "\n")
            
            
            DispatchQueue.main.async {
                // Print Classifications
                print(classifications)
                print("--")
                
                // Store the latest prediction
                var objectName:String = "…"
                objectName = classifications.components(separatedBy: "-")[0]
                objectName = objectName.components(separatedBy: ",")[0]
                self.predictionTV.text = objectName
                
            }
        }
        coreMLRequest = [visionRequest]
        updateML()
    }

    override func didReceiveMemoryWarning() {
       super.didReceiveMemoryWarning()
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = .horizontal
        arView.session.run(config)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillAppear(animated)
        arView.session.pause()
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        DispatchQueue.main.async {
            // TODO
        }
    }

    @objc func handleTheTap (gesture : UITapGestureRecognizer){
        let screenCenter : CGPoint = CGPoint(x: self.arView.bounds.midX, y: self.arView.bounds.midY)
        let arHitTestResults : [ARHitTestResult] = arView.hitTest(screenCenter, types: [.featurePoint])
        
        if let getTheClosestResult = arHitTestResults.first{
            let transform : matrix_float4x4 = getTheClosestResult.worldTransform
            
            let coord : SCNVector3 = SCNVector3Make(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
            
            // generate some text for the object detected
            let node : SCNNode = displayTextForObject(prediction)
            node.position = coord
        }
        
    }
    
    fileprivate func updateML(){
        queueCoreML.async {
            // 1. Run Update.
            self.coreMLUpdate()
            
            // 2. Loop this function.
            self.updateML()
        }
    }
    
    
    fileprivate func displayTextForObject(_ text : String) -> SCNNode{
        let textConstraints = SCNBillboardConstraint()
        textConstraints.freeAxes = SCNBillboardAxis.Y
        
        let text3D = SCNText(string: text, extrusionDepth: CGFloat(textDepth))
        var fontForText = UIFont(name: "TimeBurner", size: 0.16)
        fontForText = fontForText?.withTraits(traits: .traitBold)
        text3D.font = fontForText
        text3D.alignmentMode = kCAAlignmentCenter
        text3D.firstMaterial?.diffuse.contents = UIColor.blue
        text3D.firstMaterial?.specular.contents = UIColor.yellow
        text3D.firstMaterial?.isDoubleSided = true
        text3D.chamferRadius = CGFloat(textDepth)
        
        
        let (min, max) = text3D.boundingBox
        let textNode = SCNNode(geometry : text3D)
        textNode.pivot = SCNMatrix4MakeTranslation( (max.x - min.x)/2, min.y, textDepth/2)
        
        // shrink text size
        textNode.scale = SCNVector3Make(0.2, 0.2, 0.2)
        
        // set the center of the node
        let shape = SCNSphere(radius: 0.006)
        shape.firstMaterial?.diffuse.contents = UIColor.black
        
        let shapeNode = SCNNode(geometry : shape)
        
        let parentNode = SCNNode()
        parentNode.addChildNode(textNode)
        parentNode.addChildNode(shapeNode)
        parentNode.constraints = [textConstraints]
        
        return parentNode
    }
    
    func coreMLUpdate(){
        let buffer : CVPixelBuffer? = (arView.session.currentFrame?.capturedImage)

        guard let upwrapBuffer = buffer else {return}
        
        let ciImg = CIImage(cvImageBuffer: upwrapBuffer)
        let imageRequestHandler = VNImageRequestHandler(ciImage: ciImg, options: [:])
        
        do{
            try
                imageRequestHandler.perform(self.coreMLRequest)
        }catch{
            let alert = UIAlertController(title: "Error", message: "Error with request", preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction.init(title: "OK", style: UIAlertActionStyle.default, handler: { (action) in
                
            }))
            self.present(alert, animated: true, completion: nil)
        }
    }

}

extension UIFont {
    // Based on: https://stackoverflow.com/questions/4713236/how-do-i-set-bold-and-italic-on-uilabel-of-iphone-ipad
    func withTraits(traits:UIFontDescriptorSymbolicTraits...) -> UIFont {
        let descriptor = self.fontDescriptor.withSymbolicTraits(UIFontDescriptorSymbolicTraits(traits))
        return UIFont(descriptor: descriptor!, size: 0)
    }
}

