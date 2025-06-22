//
//  OpenAIService.swift
//  Sthrenotics
//
//  Enhanced with comprehensive debugging and error handling
//

import Foundation

// String extension for repeated characters (for debug formatting)
extension String {
    static func * (left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}

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
            print("📝 DEBUG: Coordinate data preview (first 500 chars):")
            print(String(coordinateData.prefix(500)))
            if coordinateData.count > 500 {
                print("... (truncated, total length: \(coordinateData.count))")
            }
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
            print("📤 DEBUG: Full prompt being sent to OpenAI:")
            print("=" * 30)
            print(prompt)
            print("=" * 30)
            print("📤 DEBUG: Prompt length: \(prompt.count) characters")
        }
        
        return await performAnalysis(prompt: prompt, maxTokens: 200, isLiveAnalysis: false)
    }
    
    func analyzeLiveExercise(coordinateData: String) async -> ExerciseAnalysisResult {
        if debugMode {
            print("🔴 DEBUG: Live analysis - data length: \(coordinateData.count)")
            print("🔴 DEBUG: Live coordinate data:")
            print(coordinateData)
        }
        
        if coordinateData.isEmpty {
            if debugMode {
                print("🔴 DEBUG: Empty coordinate data for live analysis")
            }
            return ExerciseAnalysisResult(
                repCount: 0,
                formScore: 5.0,
                feedback: "Waiting for movement...",
                issues: []
            )
        }
        
        let prompt = """
        LIVE POSTURE CHECK (current position):
        \(coordinateData)
        
        Rate posture 1-10, give brief feedback. JSON only:
        {"formScore":7.0,"feedback":"Quick posture tip"}
        """
        
        if debugMode {
            print("🔴 DEBUG: Live analysis prompt:")
            print("=" * 20)
            print(prompt)
            print("=" * 20)
        }
        
        do {
            let result = await performAnalysis(prompt: prompt, maxTokens: 80, isLiveAnalysis: true)
            print("🔴 DEBUG: Live analysis completed successfully: \(result)")
            return result
        } catch {
            print("🔴 DEBUG: Live analysis failed with error: \(error)")
            return ExerciseAnalysisResult(
                repCount: 0,
                formScore: 5.0,
                feedback: "Connection error - check network",
                issues: ["Network Error"]
            )
        }
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
        
        // 🔍 LOG THE FULL REQUEST
        if debugMode {
            print("=" * 50)
            print("🌐 OPENAI REQUEST DEBUG")
            print("=" * 50)
            print("📤 URL: \(baseURL)")
            print("📤 Method: POST")
            print("📤 Headers: Authorization: Bearer \(String(apiKey.prefix(10)))..., Content-Type: application/json")
            print("📤 Request Body:")
            if let requestData = try? JSONSerialization.data(withJSONObject: requestBody),
               let requestString = String(data: requestData, encoding: .utf8) {
                print(requestString)
            }
            print("=" * 50)
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        if debugMode {
            print("🌐 DEBUG: Making request to OpenAI...")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // 🔍 LOG THE FULL RESPONSE
        if debugMode {
            print("=" * 50)
            print("📥 OPENAI RESPONSE DEBUG")
            print("=" * 50)
        }
        
        if let httpResponse = response as? HTTPURLResponse {
            if debugMode {
                print("📡 HTTP Status: \(httpResponse.statusCode)")
                print("📡 Response Headers: \(httpResponse.allHeaderFields)")
            }
            
            if !(200...299).contains(httpResponse.statusCode) {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                if debugMode {
                    print("❌ HTTP Error Response Body: \(errorMessage)")
                    print("=" * 50)
                }
                throw URLError(.badServerResponse)
            }
        }
        
        // Parse response and log it
        let responseString = String(data: data, encoding: .utf8) ?? "Cannot decode response"
        if debugMode {
            print("📥 Raw Response Body:")
            print(responseString)
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            if debugMode {
                print("❌ Failed to parse JSON from response")
                print("=" * 50)
            }
            throw URLError(.badServerResponse)
        }
        
        if debugMode {
            print("📋 Parsed JSON Response:")
            if let jsonData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
               let prettyJson = String(data: jsonData, encoding: .utf8) {
                print(prettyJson)
            }
        }
        
        // Check for API errors
        if let error = json["error"] as? [String: Any] {
            let errorMessage = error["message"] as? String ?? "Unknown API error"
            let errorType = error["type"] as? String ?? "unknown"
            if debugMode {
                print("🚨 OpenAI API Error:")
                print("   Type: \(errorType)")
                print("   Message: \(errorMessage)")
                print("=" * 50)
            }
            throw NSError(domain: "OpenAIError", code: 1, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }
        
        guard let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            if debugMode {
                print("❌ Could not extract content from response structure")
                print("   Available keys in json: \(Array(json.keys))")
                if let choices = json["choices"] as? [[String: Any]], let firstChoice = choices.first {
                    print("   Available keys in first choice: \(Array(firstChoice.keys))")
                }
                print("=" * 50)
            }
            throw URLError(.badServerResponse)
        }
        
        if debugMode {
            print("✅ Extracted Content:")
            print(content)
            print("=" * 50)
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
