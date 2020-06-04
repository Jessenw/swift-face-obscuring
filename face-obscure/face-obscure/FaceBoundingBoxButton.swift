//
//  FaceBoundingBoxButton.swift
//  face-obscure
//
//  Created by Jesse Williams on 4/06/20.
//  Copyright © 2020 Jesse Williams. All rights reserved.
//

import UIKit
import Foundation

class FaceBoundingBoxButton: UIButton {
    
    let croppedImageView: UIImageView
    
    required init(croppedImageView: UIImageView) {
        self.croppedImageView = croppedImageView
                
        super.init(frame: .zero)
        
        self.croppedImageView.isHidden = true
        layer.borderWidth = 2
        layer.borderColor = UIColor.red.cgColor
        
        addTarget(self, action: #selector(tapped), for: .touchUpInside)
        addSubview(croppedImageView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        croppedImageView.frame = CGRect(
            origin: .zero,
            size: CGSize(
                width: frame.width,
                height: frame.height))
    }
    
    @objc func tapped() {
        croppedImageView.isHidden = !croppedImageView.isHidden
    }
}
