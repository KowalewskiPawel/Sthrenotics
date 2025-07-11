

import Foundation
import SwiftUI

struct Stick: Shape {
    var points: [CGPoint]
    var size: CGSize
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: points[0])
        for point in points {
            path.addLine(to: point)
        }
        return path
                    .applying(CGAffineTransform.identity.scaledBy(x: size.width, y: size.height))
                    // Apply vertical flip and translate up by the height of the view
                    .applying(CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -size.height))
    }
}

