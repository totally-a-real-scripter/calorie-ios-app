
import Foundation

struct PromptManager {
    static let systemPrompt = "You are a nutrition analysis AI running on-device. Return ONLY valid JSON. No markdown. No explanation. Follow schema exactly."

    static func createFullPrompt(from userInput: String) -> String {
        // The user input is appended below the system prompt.
        return "\(systemPrompt)\nUser input: \(userInput)"
    }
}
