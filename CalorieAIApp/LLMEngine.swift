
import Foundation
import LlamaSwift

enum LLMEngineError: Error, LocalizedError {
    case modelNotFound
    case modelLoadFailed(String)
    case contextCreateFailed
    case tokenizeFailed
    case decodeFailed(Int32)
    case getLogitsFailed
    case invalidToken
    case batchFull

    var errorDescription: String? {
        switch self {
        case .modelNotFound:
            return "The AI model file was not found."
        case .modelLoadFailed(let message):
            return "Failed to load the AI model: \(message)"
        case .contextCreateFailed:
            return "Failed to create LLM context."
        case .tokenizeFailed:
            return "Failed to tokenize the input prompt."
        case .decodeFailed(let code):
            return "LLM decode operation failed with code: \(code)."
        case .getLogitsFailed:
            return "Failed to get logits from the LLM."
        case .invalidToken:
            return "Generated an invalid token."
        case .batchFull:
            return "Llama batch is full, cannot add more tokens."
        }
    }
}

class LLMEngine {
    private var model: OpaquePointer?
    private var context: OpaquePointer?
    private let modelPath: String
    private var n_vocab: Int32 = 0

    init(modelPath: String) {
        self.modelPath = modelPath
    }

    deinit {
        freeContext()
        freeModel()
    }

    func loadModel() throws {
        guard FileManager.default.fileExists(atPath: modelPath) else {
            throw LLMEngineError.modelNotFound
        }

        var modelParams = llama_model_default_params()
        // TODO: Configure modelParams if needed, e.g., for GPU offloading or specific memory settings.

        self.model = llama_load_model_from_file(modelPath, modelParams)
        guard let loadedModel = self.model else {
            throw LLMEngineError.modelLoadFailed("Unknown reason") // llama_load_model_from_file doesn't provide detailed error
        }
        
        var contextParams = llama_context_default_params()
        contextParams.n_ctx = 2048 // Context window size
        contextParams.n_batch = 512 // Batch size for processing
        // TODO: Configure contextParams based on device capabilities and model requirements.
        
        self.context = llam-new_context_with_model(loadedModel, contextParams) // CORRECTED
        guard let loadedContext = self.context else {
            throw LLMEngineError.contextCreateFailed
        }
        
        self.n_vocab = llam-n_vocab(loadedModel) // CORRECTED
    }

    func generate(prompt: String, maxTokens: Int = 500) async throws -> String {
        guard let model = self.model, let context = self.context else {
            throw LLMEngineError.modelLoadFailed("Model not loaded.")
        }

        // Tokenization
        var tokens: [llama_token] = Array(repeating: 0, count: Int(llam-n_ctx(context))) // CORRECTED

        let tokenCount = llama_tokenize(
            model,
            prompt,
            Int32(prompt.utf8.count),
            &tokens,
            Int32(tokens.count),
            true, // add BOS
            false // no special tokens for user input
        )

        guard tokenCount > 0 else {
            throw LLMEngineError.tokenizeFailed
        }
        
        let promptTokens = Array(tokens.prefix(Int(tokenCount)))

        var result = ""
        var n_cur = 0

        // Create a llama_batch
        var batch = llama_batch_init(llam-n_ctx(context), 0, 1) // CORRECTED
        defer { llama_batch_free(batch) }

        // Add prompt tokens to batch
        for i in 0..<promptTokens.count {
            // Manually populate the batch.token, batch.pos, batch.n_seq_id
            if i >= Int(batch.n_batch) { // Check if batch is full (CORRECTED)
                throw LLMEngineError.batchFull
            }
            batch.token[i] = promptTokens[i]
            batch.pos[i] = Int32(i)
            batch.n_seq_id[i] = 1 // Single sequence
            if let seq_id_ptr = batch.seq_id {
                seq_id_ptr[i]?[0] = 0 // Assign sequence ID 0
            }
            batch.logits[i] = 0 // No logits for prompt tokens initially
        }
        batch.n_tokens = Int32(promptTokens.count)

        // Set logits for the last prompt token
        if batch.n_tokens > 0 {
            batch.logits[Int(batch.n_tokens) - 1] = 1
        }

        // Evaluate the prompt
        let decodeResult = llama_decode(context, batch)
        guard decodeResult == 0 else {
            throw LLMEngineError.decodeFailed(decodeResult)
        }
        n_cur += Int(batch.n_tokens)

        // Generation loop
        for _ in 0..<maxTokens {
            // Get logits for the last token
            guard let logits = llama_get_logits_ith(context, batch.n_tokens - 1) else {
                throw LLMEngineError.getLogitsFailed
            }

            // Simple greedy sampling
            var maxLogit: Float = -Float.infinity // Initialize with negative infinity
            var nextToken: llama_token = 0

            for i in 0..<Int(n_vocab) { // Use n_vocab for iteration
                if logits[i] > maxLogit {
                    maxLogit = logits[i]
                    nextToken = llama_token(i)
                }
            }

            // Check for end of sequence
            if nextToken == llama_token_eos(model) {
                break
            }

            // Convert token to text
            var buffer = [CChar](repeating: 0, count: 16)
            let length = llama_token_to_piece(model, nextToken, &buffer, Int32(buffer.count))

            if length > 0 {
                let tokenText = String(cString: buffer)
                result += tokenText
            } else if length < 0 {
                throw LLMEngineError.invalidToken
            }

            // Prepare batch for the next token
            llama_batch_clear(&batch) // Clear the previous batch
            
            // Add the new token to the batch
            if batch.n_tokens >= batch.n_batch { // Check if batch is full (CORRECTED)
                throw LLMEngineError.batchFull
            }
            batch.token[0] = nextToken
            batch.pos[0] = Int32(n_cur) // Position for the new token
            batch.n_seq_id[0] = 1
            if let seq_ids_ptr = batch.seq_id {
                seq_ids_ptr[0]?[0] = 0 // Assign sequence ID 0
            }
            batch.logits[0] = 1 // Request logits for this token
            batch.n_tokens = 1
            
            n_cur += 1

            // Decode the new token
            let nextDecodeResult = llama_decode(context, batch)
            guard nextDecodeResult == 0 else {
                throw LLMEngineError.decodeFailed(nextDecodeResult)
            }
        }
        return result
    }

    private func freeContext() {
        if let context = self.context {
            llama_free(context)
            self.context = nil
        }
    }

    private func freeModel() {
        if let model = self.model {
            llama_free_model(model)
            self.model = nil
        }
    }
}
