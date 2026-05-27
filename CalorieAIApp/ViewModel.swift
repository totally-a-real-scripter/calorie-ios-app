
import Foundation
import Combine // For ObservableObject and @Published

class CalorieAnalysisViewModel: ObservableObject {
    @Published var mealDescription: String = ""
    @Published var isLoading: Bool = false
    @Published var mealAnalysis: MealAnalysis?
    @Published var errorMessage: String?

    private var llmEngine: LLMEngine? // Will be initialized with the model path
    private var modelPath: String = "" // Placeholder for model path

    // TODO: Initialize LLMEngine with the correct model path once available
    // and handle model loading.
    init() {
        // Placeholder for model path. In a real app, this would be determined
        // from the app bundle or user defaults.
        if let modelURL = Bundle.main.url(forResource: "your_model_name", withExtension: "gguf") { // REMINDER: Replace with actual model name
            self.modelPath = modelURL.path
            // Attempt to load the model asynchronously to not block the UI
            Task {
                await loadModel()
            }
        } else {
            errorMessage = "LLM model file not found in app bundle. Please ensure 'your_model_name.gguf' is added to the project."
        }
    }

    @MainActor
    func loadModel() async {
        isLoading = true
        errorMessage = nil
        do {
            self.llmEngine = LLMEngine(modelPath: modelPath)
            try self.llmEngine?.loadModel()
            print("LLM Model loaded successfully!")
        } catch {
            errorMessage = "Failed to load LLM model: \(error.localizedDescription)"
            print("Error loading model: \(error.localizedDescription)")
        }
        isLoading = false
    }

    @MainActor
    func analyzeMeal() async {
        isLoading = true
        errorMessage = nil
        mealAnalysis = nil

        guard !mealDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please enter a meal description."
            isLoading = false
            return
        }

        // Construct the full prompt
        let fullPrompt = PromptManager.createFullPrompt(from: mealDescription)
        print("Full Prompt: \(fullPrompt)")

        do {
            // Perform LLM inference
            // This is where the fixed LLMEngine would be called
            guard let engine = llmEngine else {
                throw LLMEngineError.modelLoadFailed("LLM Engine not initialized.")
            }
            
            let llmOutput = try await engine.generate(prompt: fullPrompt)
            print("LLM Raw Output: \(llmOutput)")

            // Parse the JSON output
            let parsedAnalysis = try JSONParser.parse(jsonString: llmOutput)
            mealAnalysis = parsedAnalysis
        } catch let error as LLMEngineError {
            errorMessage = "AI Inference Error: \(error.localizedDescription)"
            print("LLMEngine Error: \(error.localizedDescription)")
        } catch let error as JSONParserError {
            errorMessage = "JSON Parsing Error: \(error.localizedDescription)"
            print("JSONParser Error: \(error.localizedDescription)")
        } catch {
            errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
            print("Unexpected Error: \(error.localizedDescription)")
        }
        isLoading = false
    }
    
    // Function to cancel ongoing inference (optional, for performance req)
    func cancelAnalysis() {
        // TODO: Implement cancellation logic in LLMEngine
        print("Analysis cancelled (cancellation not yet implemented in LLMEngine).")
        isLoading = false
    }
}
