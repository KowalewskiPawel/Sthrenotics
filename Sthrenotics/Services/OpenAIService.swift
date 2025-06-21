//
//  OpenAIService.swift
//  Sthrenotics
//
//  Created by Pawel Kowalewski on 19/06/2025.
//


import Foundation

class OpenAIService {
    // Use GPT-3.5-turbo for best cost/performance ratio
    //ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ??
    private let apiKey = ""
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    
    // Cache for exercise-specific prompts to reduce token usage
    private var exercisePrompts: [String: String] = [:]
    
    init() {
        setupExercisePrompts()
    }
    
    // Pre-defined efficient prompts for common exercises
    private func setupExercisePrompts() {
        exercisePrompts = [
            "push-ups": """
            PUSH-UP ANALYSIS:
            Key patterns: shoulders-wrists aligned, straight body line, 90° elbow bend at bottom
            Count: full up-down cycles only
            Form errors: sagging hips, flared elbows, partial range
            """,
            
            "squats": """
            SQUAT ANALYSIS:
            Key patterns: knees track over toes, hip hinge, thighs parallel at bottom
            Count: full up-down cycles only
            Form errors: knee valgus, forward lean, partial depth
            """,
            
            "burpees": """
            BURPEE ANALYSIS:
            Key patterns: squat→plank→push-up→jump sequence
            Count: complete 4-phase cycles only
            Form errors: missing phases, poor plank position, weak jump
            """,
            
            "lunges": """
            LUNGE ANALYSIS:
            Key patterns: 90° angles both knees, vertical torso, controlled descent
            Count: complete down-up cycles per leg
            Form errors: knee drift, torso lean, short range
            """,
            
            "plank": """
            PLANK ANALYSIS:
            Key patterns: straight line head-to-heels, shoulders over wrists
            Count: hold duration in seconds
            Form errors: sagging hips, raised hips, head drop
            """,
            
            "jumping-jacks": """
            JUMPING JACK ANALYSIS:
            Key patterns: arms overhead, feet wide, coordinated movement
            Count: complete open-close cycles
            Form errors: partial arm raise, narrow stance, poor timing
            """
        ]
    }
    
    // Main analysis function for complete sessions
    func analyzeExercise(exercise: String, coordinateData: String) async -> ExerciseAnalysisResult {
        let exerciseKey = exercise.lowercased().replacingOccurrences(of: " ", with: "-")
        let exercisePrompt = exercisePrompts[exerciseKey] ?? generateGenericPrompt(for: exercise)
        
        let prompt = """
        \(exercisePrompt)
        
        COORDINATES (t:time|joint:x,y format, 0-1 normalized):
        \(coordinateData)
        
        JSON RESPONSE ONLY:
        {"repCount":0,"formScore":0.0,"feedback":"brief","issues":["specific"]}
        """
        
        return await performAnalysis(prompt: prompt, maxTokens: 200)
    }
    
    // Lightweight live analysis for real-time feedback
    func analyzeLiveExercise(coordinateData: String) async -> ExerciseAnalysisResult {
        let prompt = """
        LIVE FORM CHECK (last 2 seconds):
        \(coordinateData)
        
        Rate form 1-10, give brief feedback. JSON only:
        {"formScore":0.0,"feedback":"brief tip"}
        """
        
        return await performAnalysis(prompt: prompt, maxTokens: 50)
    }
    
    // Flexible analysis for any exercise type
    func analyzeCustomExercise(exerciseName: String, exerciseDescription: String, coordinateData: String) async -> ExerciseAnalysisResult {
        let prompt = """
        CUSTOM EXERCISE: \(exerciseName)
        Description: \(exerciseDescription)
        
        COORDINATES:
        \(coordinateData)
        
        Analyze movement patterns, count reps, assess form. JSON only:
        {"repCount":0,"formScore":0.0,"feedback":"assessment","issues":["specifics"]}
        """
        
        return await performAnalysis(prompt: prompt, maxTokens: 150)
    }
    
    private func performAnalysis(prompt: String, maxTokens: Int) async -> ExerciseAnalysisResult {
        let messages = [
            [
                "role": "system",
                "content": "You are Sthrenotics AI, an expert exercise form analyst. Always respond with valid JSON only."
            ],
            [
                "role": "user",
                "content": prompt
            ]
        ]
        
        do {
            let result = try await generateChatCompletion(messages: messages, maxTokens: maxTokens)
            return parseAnalysisResult(from: result)
        } catch {
            print("Sthrenotics OpenAI Error: \(error)")
            return ExerciseAnalysisResult(
                repCount: 0,
                formScore: 5.0,
                feedback: "Analysis temporarily unavailable",
                issues: ["Connection Error"]
            )
        }
    }
    
    private func generateChatCompletion(messages: [[String: String]], maxTokens: Int) async throws -> String {
        guard let url = URL(string: baseURL) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15.0 // Faster timeout for live analysis
        
        let requestBody: [String: Any] = [
            "model": "gpt-3.5-turbo", // Cheapest and fastest option
            "messages": messages,
            "max_tokens": maxTokens,
            "temperature": 0.1, // Low temperature for consistent analysis
            "top_p": 0.9,
            "frequency_penalty": 0.1,
            "presence_penalty": 0.1
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            guard 200...299 ~= httpResponse.statusCode else {
                print("HTTP Error: \(httpResponse.statusCode)")
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
        let cleanJson = jsonString
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let data = cleanJson.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ExerciseAnalysisResult(
                repCount: 0,
                formScore: 5.0,
                feedback: "Unable to parse AI response",
                issues: ["Response Format Error"]
            )
        }
        
        let repCount = json["repCount"] as? Int ?? 0
        let formScore = json["formScore"] as? Double ?? 5.0
        let feedback = json["feedback"] as? String ?? "No feedback available"
        let issues = json["issues"] as? [String] ?? []
        
        return ExerciseAnalysisResult(
            repCount: repCount,
            formScore: formScore,
            feedback: feedback,
            issues: issues
        )
    }
    
    private func generateGenericPrompt(for exercise: String) -> String {
        return """
        \(exercise.uppercased()) ANALYSIS:
        Analyze movement patterns for this exercise
        Count complete repetitions only
        Assess form quality and provide feedback
        """
    }
}

// Extended result struct for live analysis
extension ExerciseAnalysisResult {
    static let placeholder = ExerciseAnalysisResult(
        repCount: 0,
        formScore: 10.0,
        feedback: "Starting analysis...",
        issues: []
    )
}
