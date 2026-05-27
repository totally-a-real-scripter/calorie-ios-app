
import Foundation

// MARK: - Model Output Structure
struct FoodItem: Codable {
    let name: String
    let calories: Int
}

struct MealAnalysis: Codable {
    let foods: [FoodItem]
    let totalCalories: Int
    let summary: String

    enum CodingKeys: String, CodingKey {
        case foods
        case totalCalories = "total_calories"
        case summary
    }
}

// MARK: - JSON Parser
enum JSONParserError: Error, LocalizedError {
    case invalidJSON
    case decodingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "The provided string is not valid JSON."
        case .decodingFailed(let error):
            return "Failed to decode JSON: \(error.localizedDescription)"
        }
    }
}

struct JSONParser {
    static func parse(jsonString: String) throws -> MealAnalysis {
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw JSONParserError.invalidJSON
        }

        let decoder = JSONDecoder()
        do {
            let mealAnalysis = try decoder.decode(MealAnalysis.self, from: jsonData)
            return mealAnalysis
        } catch {
            throw JSONParserError.decodingFailed(error)
        }
    }
}
