//
//  OpenAIService.swift
//  Sthrenotics
//
//  Created by Pawel Kowalewski on 19/06/2025.
//


import Foundation

class OpenAIService {
    // Replace with your actual OpenAI API key
    private let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? "YOUR_OPENAI_API_KEY"
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    
    func analyzeExercise(exercise: String, coordinateData: String) async -> ExerciseAnalysisResult {
        // Enhanced prompt with better context and instructions
        let prompt = """
        EXERCISE ANALYSIS - \(exercise.uppercased())
        
        You are analyzing \(exercise) form using body pose coordinates from computer vision.
        
        COORDINATE FORMAT:
        - Each line: t:timestamp|joint:x,y,confidence
        - Coordinates normalized 0-1 (origin top-left)
        - Only joints with confidence > 0.3 included
        - Camera facing user (mirror view)
        
        EXERCISE SEQUENCE:
        \(coordinateData)
        
        ANALYSIS REQUIREMENTS:
        - Count ONLY complete repetitions with acceptable form
        - Rate form 1-10 (7+ = good, 5-6 = needs work, <5 = poor)
        - Focus on key \(exercise) movement patterns
        - Provide specific, actionable feedback
        
        RESPOND WITH VALID JSON ONLY:
        {
          "repCount": 0,
          "formScore": 0.0,
          "feedback": "Concise overall assessment and main suggestion",
          "issues": ["specific issue 1", "specific issue 2"]
        }
        """
        
        let messages = [
            [
                "role": "system", 
                "content": "You are Sthrenotics AI - an expert exercise form analyst. Analyze pose coordinate data and provide precise feedback. Always respond with valid JSON only, no additional text."
            ],
            [
                "role": "user", 
                "content": prompt
            ]
        ]
        
        do {
            let result = try await generateChatCompletion(messages: messages)
            return parseAnalysisResult(from: result)
        } catch {
            print("Sthrenotics OpenAI Error: \(error)")
            return ExerciseAnalysisResult(
                repCount: 0,
                formScore: 0.0,
                feedback: "Analysis unavailable. Check connection and API key.",
                issues: ["Connection Error"]
            )
        }
    }
    
    private func generateChatCompletion(messages: [[String: String]]) async throws -> String {
        guard let url = URL(string: baseURL) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30.0
        
        let requestBody: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": messages,
            "max_tokens": 300,
            "temperature": 0.1, // Low temperature for consistent analysis
            "top_p": 0.9
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Check HTTP response
        if let httpResponse = response as? HTTPURLResponse {
            guard 200...299 ~= httpResponse.statusCode else {
                throw URLError(.badServerResponse)
            }
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw URLError(.badServerResponse)
        }
        
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func parseAnalysisResult(from jsonString: String) -> ExerciseAnalysisResult {
        // Clean up the JSON string (remove any markdown formatting)
        let cleanJson = jsonString
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let data = cleanJson.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ExerciseAnalysisResult(
                repCount: 0,
                formScore: 0.0,
                feedback: "Unable to parse AI response",
                issues: ["Response Format Error"]
            )
        }
        
        let repCount = json["repCount"] as? Int ?? 0
        let formScore = json["formScore"] as? Double ?? 0.0
        let feedback = json["feedback"] as? String ?? "No feedback available"
        let issues = json["issues"] as? [String] ?? []
        
        return ExerciseAnalysisResult(
            repCount: repCount,
            formScore: formScore,
            feedback: feedback,
            issues: issues
        )
    }
}
