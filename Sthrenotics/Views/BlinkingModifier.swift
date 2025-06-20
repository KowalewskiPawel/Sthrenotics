//
//  BlinkingModifier.swift
//  Sthrenotics
//
//  Created by Pawel Kowalewski on 19/06/2025.
//

import SwiftUI

extension View {
    func blinking(duration: Double = 1.0) -> some View {
        modifier(BlinkingModifier(duration: duration))
    }
}

struct BlinkingModifier: ViewModifier {
    let duration: Double
    @State private var isVisible = true
    
    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .onAppear {
                withAnimation(Animation.easeInOut(duration: duration).repeatForever()) {
                    isVisible.toggle()
                }
            }
    }
}
