//
//  AnalysisResultView.swift
//  Sthrenotics
//
//  Created by Pawel Kowalewski on 19/06/2025.
//

import SwiftUI

struct AnalysisResultView: View {
    let result: ExerciseAnalysisResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with score visualization
            HStack {
                VStack(alignment: .leading) {
                    Text("Analysis Complete")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Powered by Sthrenotics AI")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    HStack {
                        Text("\(result.repCount)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Text("reps")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    // Form score with color coding
                    HStack {
                        Text("\(result.formScore, specifier: "%.1f")")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(scoreColor)
                        Text("/10")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
            
            // Score bar visualization
            HStack {
                Text("Form Score")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                
                Spacer()
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 4)
                            .cornerRadius(2)
                        
                        Rectangle()
                            .fill(scoreColor)
                            .frame(width: geometry.size.width * CGFloat(result.formScore / 10.0), height: 4)
                            .cornerRadius(2)
                    }
                }
                .frame(height: 4)
            }
            
            // Feedback
            if !result.feedback.isEmpty {
                Text(result.feedback)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
            }
            
            // Issues
            if !result.issues.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Areas for Improvement:")
                        .font(.caption)
                        .foregroundColor(.orange.opacity(0.8))
                        .fontWeight(.medium)
                    
                    ForEach(result.issues, id: \.self) { issue in
                        HStack(alignment: .top) {
                            Text("•")
                                .foregroundColor(.orange)
                            Text(issue)
                                .font(.caption)
                                .foregroundColor(.orange)
                                .multilineTextAlignment(.leading)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.85))
                .shadow(radius: 8)
        )
    }
    
    private var scoreColor: Color {
        switch result.formScore {
        case 8...10: return .green
        case 6..<8: return .yellow
        case 4..<6: return .orange
        default: return .red
        }
    }
}
