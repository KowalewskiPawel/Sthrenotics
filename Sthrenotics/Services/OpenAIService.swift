//
//  OpenAIService.swift
//  Sthrenotics
//
//  Enhanced with comprehensive debugging and error handling
//

import Foundation

class OpenAIService {
    private let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? "YOUR_OPENAI_API_KEY"
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    
    // Debug mode - set to true to see detailed logs
    private let debugMode = true
    
    private var exercisePrompts: [String: String] = [:]
    
    init() {
        setupExercisePrompts()
        
        // Debug API key status
        if debugMode {
            if apiKey == "YOUR_OPENAI_API_KEY" || apiKey.isEmpty {
                print("🚨 DEBUG: OpenAI API key not set! Add OPENAI_API_KEY to environment variables")
            } else {
                print("✅ DEBUG: OpenAI API key found (length: \(apiKey.count))")
            }
        }
    }
    
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
            
            "sitting": """
            SITTING POSITION ANALYSIS:
            Key patterns: upright torso, shoulders over hips, feet flat
            Count: posture checks (not reps)
            Form feedback: spine alignment, shoulder position, head posture
            """
        ]
    }
    
    func analyzeExercise(exercise: String, coordinateData: String) async -> ExerciseAnalysisResult {
        if debugMode {
            print("🔍 DEBUG: Starting analysis for exercise: \(exercise)")
            print("📊 DEBUG: Coordinate data length: \(coordinateData.count) characters")
            print("📝 DEBUG: First 200 chars of data: \(String(coordinateData.prefix(200)))")
        }
        
        // Check if we have any coordinate data
        if coordinateData.isEmpty {
            if debugMode {
                print("⚠️ DEBUG: No coordinate data provided!")
            }
            return ExerciseAnalysisResult(
                repCount: 0,
                formScore: 0.0,
                feedback: "No movement data detected. Make sure you're visible to the camera.",
                issues: ["No pose data"]
            )
        }
        
        let exerciseKey = exercise.lowercased().replacingOccurrences(of: " ", with: "-")
        let exercisePrompt = exercisePrompts[exerciseKey] ?? exercisePrompts["sitting"] ?? generateGenericPrompt(for: exercise)
        
        let prompt = """
        \(exercisePrompt)
        
        COORDINATES (t:time|joint:x,y format, 0-1 normalized):
        \(coordinateData)
        
        Respond with valid JSON only - no other text:
        {"repCount":0,"formScore":7.5,"feedback":"Clear assessment of what you see","issues":["specific issue"]}
        """
        
        if debugMode {
            print("📤 DEBUG: Sending prompt to OpenAI (length: \(prompt.count))")
        }
        
        return await performAnalysis(prompt: prompt, maxTokens: 200, isLiveAnalysis: false)
    }
    
    func analyzeLiveExercise(coordinateData: String) async -> ExerciseAnalysisResult {
        if debugMode {
            print("🔴 DEBUG: Live analysis - data length: \(coordinateData.count)")
        }
        
        if coordinateData.isEmpty {
            return ExerciseAnalysisResult(
                repCount: 0,
                formScore: 5.0,
                feedback: "Waiting for movement...",
                issues: []
            )
        }
        
        let prompt = """
        LIVE POSTURE CHECK (sitting position):
        \(coordinateData)
        
        Rate posture 1-10, give brief feedback. JSON only:
        {"formScore":7.0,"feedback":"Quick posture tip"}
        """
        
        return await performAnalysis(prompt: prompt, maxTokens: 80, isLiveAnalysis: true)
    }
    
    private func performAnalysis(prompt: String, maxTokens: Int, isLiveAnalysis: Bool) async -> ExerciseAnalysisResult {
        // Check API key first
        if apiKey == "YOUR_OPENAI_API_KEY" || apiKey.isEmpty {
            if debugMode {
                print("🚨 DEBUG: API key not configured!")
            }
            return ExerciseAnalysisResult(
                repCount: 0,
                formScore: 0.0,
                feedback: "OpenAI API key not configured. Add OPENAI_API_KEY to environment variables.",
                issues: ["API Configuration Error"]
            )
        }
        
        let messages = [
            [
                "role": "system",
                "content": "You are Sthrenotics AI. Analyze pose data and respond with valid JSON only. No markdown, no extra text."
            ],
            [
                "role": "user",
                "content": prompt
            ]
        ]
        
        do {
            let result = try await generateChatCompletion(messages: messages, maxTokens: maxTokens)
            
            if debugMode {
                print("📥 DEBUG: OpenAI response: \(result)")
            }
            
            let parsedResult = parseAnalysisResult(from: result)
            
            if debugMode {
                print("✅ DEBUG: Parsed result - Score: \(parsedResult.formScore), Feedback: \(parsedResult.feedback)")
            }
            
            return parsedResult
            
        } catch {
            if debugMode {
                print("❌ DEBUG: OpenAI Error: \(error)")
                if let urlError = error as? URLError {
                    print("🌐 DEBUG: URLError details: \(urlError.localizedDescription)")
                }
            }
            
            return ExerciseAnalysisResult(
                repCount: 0,
                formScore: 5.0,
                feedback: "Analysis temporarily unavailable: \(error.localizedDescription)",
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
        request.timeoutInterval = 30.0
        
        let requestBody: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": messages,
            "max_tokens": maxTokens,
            "temperature": 0.3,
            "top_p": 0.9
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        if debugMode {
            print("🌐 DEBUG: Making request to OpenAI...")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            if debugMode {
                print("📡 DEBUG: HTTP Status: \(httpResponse.statusCode)")
            }
            
            if !(200...299).contains(httpResponse.statusCode) {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                if debugMode {
                    print("❌ DEBUG: HTTP Error Response: \(errorMessage)")
                }
                throw URLError(.badServerResponse)
            }
        }
        
        // Parse response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            if debugMode {
                let responseString = String(data: data, encoding: .utf8) ?? "Cannot decode response"
                print("❌ DEBUG: Invalid JSON response: \(responseString)")
            }
            throw URLError(.badServerResponse)
        }
        
        if debugMode {
            print("📋 DEBUG: Full JSON response: \(json)")
        }
        
        // Check for API errors
        if let error = json["error"] as? [String: Any] {
            let errorMessage = error["message"] as? String ?? "Unknown API error"
            if debugMode {
                print("🚨 DEBUG: OpenAI API Error: \(errorMessage)")
            }
            throw NSError(domain: "OpenAIError", code: 1, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }
        
        guard let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            if debugMode {
                print("❌ DEBUG: Could not extract content from response")
            }
            throw URLError(.badServerResponse)
        }
        
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func parseAnalysisResult(from jsonString: String) -> ExerciseAnalysisResult {
        let cleanJson = jsonString
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        if debugMode {
            print("🔧 DEBUG: Parsing JSON: \(cleanJson)")
        }
        
        guard let data = cleanJson.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            if debugMode {
                print("❌ DEBUG: Failed to parse JSON from: \(cleanJson)")
            }
            return ExerciseAnalysisResult(
                repCount: 0,
                formScore: 5.0,
                feedback: "Could not parse AI response",
                issues: ["Response Format Error"]
            )
        }
        
        let repCount = json["repCount"] as? Int ?? 0
        let formScore = json["formScore"] as? Double ?? 5.0
        let feedback = json["feedback"] as? String ?? "Analysis completed"
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
        Analyze movement patterns and body position
        Provide helpful feedback on posture and form
        Rate overall quality 1-10
        """
    }
}
