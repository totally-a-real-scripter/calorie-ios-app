
import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = CalorieAnalysisViewModel()

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Meal Description")) {
                    TextEditor(text: $viewModel.mealDescription)
                        .frame(minHeight: 100)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .padding(.vertical, 5)
                }

                Section {
                    Button("Analyze Meal") {
                        Task {
                            await viewModel.analyzeMeal()
                        }
                    }
                    .disabled(viewModel.isLoading)
                }

                if viewModel.isLoading {
                    HStack {
                        Spacer()
                        ProgressView("Analyzing...")
                        Spacer()
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                }

                if let analysis = viewModel.mealAnalysis {
                    Section(header: Text("Analysis Results")) {
                        VStack(alignment: .leading) {
                            Text("**Total Calories:** \(analysis.totalCalories) kcal")
                                .font(.headline)
                                .padding(.bottom, 5)

                            Text("Food Items:")
                                .font(.subheadline)
                            ForEach(analysis.foods, id: \.name) {
                                Text("- \($0.name): \($0.calories) kcal")
                            }
                            .padding(.leading, 10)

                            Text("Summary:")
                                .font(.subheadline)
                                .padding(.top, 5)
                            Text(analysis.summary)
                                .italic()
                        }
                        .padding(.vertical, 5)
                    }
                }
            }
            .navigationTitle("Calorie AI")
        }
    }
}

#Preview {
    ContentView()
}
