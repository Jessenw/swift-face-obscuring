//
//  ViewController.swift
//  face-detect-spike-2
//
//  Created by Jesse Williams on 3/06/20.
//  Copyright © 2020 Jesse Williams. All rights reserved.
//

import UIKit
import Vision

class ViewController: UIViewController {
    
    let context = { CIContext() }()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Load image
        guard let sourceImage = UIImage(named: "base_image")?.resized(toWidth: view.frame.width)
            else { return }
        guard let sourceCGImage = sourceImage.cgImage
            else { return }
        let sourceCIImage = CIImage(cgImage: sourceCGImage)
        
        let sourceImageView = UIImageView(image: sourceImage)
        sourceImageView.contentMode = .scaleAspectFit
        
        // Create blur filter
//        guard let blurFilter = CIFilter(name: "CIGaussianBlur")
//            else { return }
//        blurFilter.setValue(sourceCIImage, forKey: kCIInputImageKey)
//        blurFilter.setValue(2, forKey: kCIInputRadiusKey)
        
        guard let pixelateFilter = CIFilter(name: "CIPixellate")
            else { return }
        pixelateFilter.setValue(sourceCIImage, forKey: kCIInputImageKey)
        pixelateFilter.setValue(max(sourceCIImage.extent.width, sourceCIImage.extent.height) / 60.0, forKey: kCIInputScaleKey)
        
        // Create face detection request
        let request = VNDetectFaceRectanglesRequest { [weak self] (req, err) in
            guard let sself = self
                else { return }
            
            if let err = err {
                print("Failed to detect faces: " , err)
                return
            }
            
            var boxViews = [UIView]()
            var maskImage: CIImage?
            
            req.results?.forEach({ (res) in
                guard let faceObservation = res as? VNFaceObservation
                    else { return }
                
                // A face observations bounding box is a percentage of the screen
                let x = sself.view.frame.width * faceObservation.boundingBox.origin.x
                let height = sourceImage.size.height * faceObservation.boundingBox.height
                let y = sourceImage.size.height * (1 - faceObservation.boundingBox.origin.y) - height
                let width = sself.view.frame.width * faceObservation.boundingBox.width
                
                let boxView = UIView()
                boxView.backgroundColor = .red
                boxView.alpha = 0.2
                boxView.frame = CGRect(
                    origin: CGPoint(x: x, y: y),
                    size: CGSize(width: width, height: height))
                
                let radialMask = sself.generateRadialMask(bounds: CGRect(
                    origin: CGPoint(x: x, y: y),
                    size: CGSize(width: width, height: height)))
                
                let radialMaskImage = radialMask?.outputImage
                
                if maskImage == nil {
                    maskImage = radialMaskImage
                } else {
                    guard let compositeFilter = CIFilter(name: "CISourceOverCompositing")
                        else { return }
                    compositeFilter.setValue(radialMaskImage, forKey: kCIInputImageKey)
                    compositeFilter.setValue(maskImage, forKey: kCIInputBackgroundImageKey)
                    
                    maskImage = compositeFilter.outputImage
                }
                
                boxViews.append(boxView)
            })
            
            guard let composite = CIFilter(name: "CIBlendWithMask")
                else { return }
            composite.setValue(pixelateFilter.outputImage, forKey: kCIInputImageKey)
            composite.setValue(sourceCIImage, forKey: kCIInputBackgroundImageKey)
            composite.setValue(maskImage, forKey: kCIInputMaskImageKey)
            
            guard let outputCIImage = composite.outputImage
                else { return }
            guard let outputCGImage = sself.context.createCGImage(outputCIImage, from: outputCIImage.extent)
                else { return }
            let outputImage = UIImage(cgImage: outputCGImage)
            let outputImageView = UIImageView(image: outputImage)
            
            sself.view.addSubview(outputImageView)
            
            // Display mask image
            guard let ciMaskImage = maskImage
                else { return }
            guard let cgMaskImage = sself.context.createCGImage(ciMaskImage, from: outputCIImage.extent)
                else { return }
            let outputMaskImage = UIImage(cgImage: cgMaskImage)
            let outputMaskImageView = UIImageView(image: outputMaskImage)
            
            sself.view.addSubview(outputMaskImageView)
            
            // Show boxes for detected faces
            boxViews.forEach({ view in
                sself.view.addSubview(view)
            })
        }
        
        // Perform request
        let handler = VNImageRequestHandler(
            cgImage: sourceCGImage,
            options: [:])
        
        do {
            try handler.perform([request])
        } catch let err {
            print("Failed to perform request:", err)
        }
    }
    
    func generateRadialMask(bounds: CGRect) -> CIFilter? {
        let radius = bounds.size.width / 2
        
        guard let mask = CIFilter(name: "CIRadialGradient")
            else { return nil }
        
        mask.setValue(radius, forKey: "inputRadius0")
        mask.setValue(radius + 1, forKey: "inputRadius1")
        mask.setValue(CIColor(red: 0, green: 1, blue: 0, alpha: 1), forKey: "inputColor0") // Inner colour
        mask.setValue(CIColor(red: 0, green: 0, blue: 0, alpha: 0), forKey: "inputColor1") // Outer colour
        mask.setValue(CIVector(x: (bounds.origin.x + bounds.size.width) / 2,
                               y: (bounds.origin.y + bounds.size.height) / 2),
                      forKey: kCIInputCenterKey)
        
        return mask
    }
}

extension UIImage {
    // Resize an image so that it fits within a given width while maintaining ratio
    func resized(toWidth width: CGFloat) -> UIImage? {
        let canvasSize = CGSize(
            width: width,
            height: CGFloat(ceil(width / size.width * size.height)))
        
        UIGraphicsBeginImageContextWithOptions(canvasSize, false, scale)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: canvasSize))
        
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
