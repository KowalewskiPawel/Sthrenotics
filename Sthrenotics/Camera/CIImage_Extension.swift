//
//  CIImage_Extension.swift
//  FormForgeV2
//
//  Created by Pawel Kowalewski on 09/05/2025.
//


//
//  CIImage+Extension.swift
//  FormForgeV2
//
//  Created by Pawel Kowalewski on 09/05/2025.
//

import CoreImage

extension CIImage {
    var cgImage: CGImage? {
        let ciContext = CIContext()
        
        guard let cgImage = ciContext.createCGImage(self, from: self.extent) else {
            return nil
        }
        
        return cgImage
    }
}