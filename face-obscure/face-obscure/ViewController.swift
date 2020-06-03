//
//  ViewController.swift
//  face-obscure
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
        guard
            let sourceImage = UIImage(named: "base_image")?
                .resized(toWidth: view.frame.width),
            let cgSourceImage = sourceImage.cgImage
            else { return }
        
        let ciSourceImage = CIImage(cgImage: cgSourceImage)
        
        guard let pixelateFilter = CIFilter(name: "CIPixellate")
            else { return }
        pixelateFilter.setValue(ciSourceImage, forKey: kCIInputImageKey)
        pixelateFilter.setValue(max(ciSourceImage.extent.width, ciSourceImage.extent.height) / 100, forKey: kCIInputScaleKey)
        
        // Create face detection request
        let request = VNDetectFaceRectanglesRequest { [weak self, ciSourceImage] (req, err) in
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
                boxView.layer.borderWidth = 2
                boxView.layer.borderColor = UIColor.red.cgColor
                boxView.frame = CGRect(
                    origin: CGPoint(x: x, y: y),
                    size: CGSize(width: width, height: height))
                
                let radialMask = sself.generateRadialMask(bounds: CGRect(
                    origin: CGPoint(x: x * 2, y: (sourceImage.size.height * faceObservation.boundingBox.origin.y) * 2), // Not sure why scaling is required here
                    size: CGSize(width: width, height: height)))
                
                let radialMaskImage = radialMask?.outputImage
                
                // If no imageMask is set - set this as the initial imageMask, otherwise - create a composite of this radialMaskImage and the maskImage
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
            
            // Blend the filtered image with the source image using the mask
            guard let composite = CIFilter(name: "CIBlendWithMask")
                else { return }
            composite.setValue(pixelateFilter.outputImage, forKey: kCIInputImageKey)
            composite.setValue(ciSourceImage, forKey: kCIInputBackgroundImageKey)
            composite.setValue(maskImage, forKey: kCIInputMaskImageKey)
            
            if let processedImageView = sself.createImageView(from: composite.outputImage, extent: ciSourceImage.extent, context: sself.context) {
                sself.view.addSubview(processedImageView)
            }
            
//            // Display raw mask image
//            if let maskImageView = sself.createImageView(from: maskImage, extent: sourceCIImage.extent, context: sself.context) {
//                sself.view.addSubview(maskImageView)
//            }
            
            // Show boxes for detected faces
            boxViews.forEach({ view in
                sself.view.addSubview(view)
            })
        }
        
        // Perform request
        let handler = VNImageRequestHandler(
            cgImage: cgSourceImage,
            options: [:])
        do {
            try handler.perform([request])
        } catch let err {
            print("Failed to perform request:", err)
        }
    }
    
    // Takes a CIImage and converts it into a UIImageView
    func createImageView(from image: CIImage?, extent: CGRect, context: CIContext) -> UIImageView? {
        guard
            let ciImage = image,
            let cgImage = context.createCGImage(ciImage, from: extent)
            else { return nil }

        let outputImage = UIImage(cgImage: cgImage)
        return UIImageView(image: outputImage)
    }
    
    func generateRadialMask(bounds: CGRect) -> CIFilter? {
        let radius = bounds.size.width / 2
        
        guard let mask = CIFilter(name: "CIRadialGradient")
            else { return nil }
        
        mask.setValue(radius, forKey: "inputRadius0")
        mask.setValue(radius + 5, forKey: "inputRadius1")
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
