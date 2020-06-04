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
    
    private let blurRadius = 4
    
    private let context = { CIContext() }()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Load image
        guard
            let sourceImage = UIImage(named: "base_image")?.resized(toWidth: view.frame.width),
            let cgSourceImage = sourceImage.cgImage
            else { return }
        
        let ciSourceImage = CIImage(cgImage: cgSourceImage)
        
        // Display source image
        view.addSubview(UIImageView(image: sourceImage))
        
        // Create filter
        guard let filter = CIFilter(name: "CIGaussianBlur")
            else { return }
        filter.setValue(ciSourceImage, forKey: kCIInputImageKey)
        filter.setValue(blurRadius, forKey: kCIInputRadiusKey)
        
        // Create face detection request
        let request = VNDetectFaceRectanglesRequest { [weak self, ciSourceImage] (req, err) in
            guard let sself = self
                else { return }
            
            if let err = err {
                print("Failed to detect faces: " , err)
                return
            }
            
            var boxViewBounds = [CGRect]()
            var maskImage: CIImage?
            
            req.results?.forEach({ (res) in
                guard let faceObservation = res as? VNFaceObservation
                    else { return }

                /*
                 A face observations bounding box coordinates are normalized to dimensions of the processed image.
                 E.g. an origin's X value could be 0.13 where 0 is the min X and 1 is the max X.
                 */
                let x = sself.view.frame.width * faceObservation.boundingBox.origin.x
                let y = sourceImage.size.height * faceObservation.boundingBox.origin.y
                let width = sself.view.frame.width * faceObservation.boundingBox.width
                let height = sourceImage.size.height * faceObservation.boundingBox.height
                
                boxViewBounds.append(CGRect(
                    origin: CGPoint(x: x, y: y),
                    size: CGSize(width: width, height: height)))
                
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
            })
            
            // Blend the filtered image with the source image using the mask
            guard let composite = CIFilter(name: "CIBlendWithMask")
                else { return }
            composite.setValue(filter.outputImage, forKey: kCIInputImageKey)
            composite.setValue(ciSourceImage, forKey: kCIInputBackgroundImageKey)
            composite.setValue(maskImage, forKey: kCIInputMaskImageKey)
            
            guard let processedImageView = sself.createImageView(from: composite.outputImage, extent: ciSourceImage.extent, context: sself.context)
                else { return }
            
            // Create face bounding box views which contain the filtered image according to their frame
            boxViewBounds.forEach({ frame in
                guard let compositeImage = composite.outputImage
                    else { return }
                
                let croppedImage = compositeImage.cropped(to: frame)
                guard let croppedImageView = sself.createImageView(from: croppedImage, extent: croppedImage.extent, context: sself.context)
                    else { return }
                
                let button = FaceBoundingBoxButton(croppedImageView: croppedImageView)
                button.frame = CGRect(
                    origin: CGPoint(
                        x: frame.origin.x,
                        y: (processedImageView.frame.size.height - frame.origin.y) - frame.size.height),
                    size: frame.size)
                
                sself.view.addSubview(button)
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
    
    func createCIImage(from image: UIImage) -> CIImage? {
        guard
            let sourceImage = image.resized(toWidth: view.frame.width),
            let cgSourceImage = sourceImage.cgImage
            else { return nil }
        
        return CIImage(cgImage: cgSourceImage)
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
