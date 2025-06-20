//
//  CoordinateFrame.swift
//  Sthrenotics
//
//  Created by Pawel Kowalewski on 19/06/2025.
//

import Foundation

struct CoordinateFrame {
    let timestamp: TimeInterval
    let bodyParts: [String: CoordinateData]
}

struct CoordinateData {
    let x: Float
    let y: Float
    let confidence: Float
}

struct ExerciseAnalysisResult {
    let repCount: Int
    let formScore: Double
    let feedback: String
    let issues: [String]
}
