import SwiftUI

// Models

struct Meal: Codable, Identifiable {
    let idMeal: String
    let strMeal: String
    let strMealThumb: String
    
    var id: String { idMeal }
}

struct MealResponse: Codable {
    let meals: [Meal]
}

struct MealDetail: Codable, Identifiable {
    let idMeal: String
    let strMeal: String
    let strInstructions: String
    let strMealThumb: String
    
    var id: String { idMeal }
    
    private let allKeys: [String: String?]
    
    var ingredients: [(ingredient: String, measure: String)] {
        var result: [(String, String)] = []
        
        for i in 1...20 {
            if let ingredient = allKeys["strIngredient\(i)"] as? String,
               let measure = allKeys["strMeasure\(i)"] as? String,
               !ingredient.isEmpty, !measure.isEmpty,
               ingredient != " ", measure != " " {
                result.append((ingredient, measure))
            }
        }
        
        return result
    }
    
    enum CodingKeys: String, CodingKey {
        case idMeal, strMeal, strInstructions, strMealThumb
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        idMeal = try container.decode(String.self, forKey: .idMeal)
        strMeal = try container.decode(String.self, forKey: .strMeal)
        strInstructions = try container.decode(String.self, forKey: .strInstructions)
        strMealThumb = try container.decode(String.self, forKey: .strMealThumb)
        
        let additionalInfo = try decoder.container(keyedBy: AnyCodingKey.self)
        allKeys = Dictionary(uniqueKeysWithValues: additionalInfo.allKeys.compactMap { key in
            guard let value = try? additionalInfo.decodeIfPresent(String.self, forKey: key) else { return nil }
            return (key.stringValue, value)
        })
    }
}

struct AnyCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?
    
    init?(stringValue: String) {
        self.stringValue = stringValue
    }
    
    init?(intValue: Int) {
        self.intValue = intValue
        self.stringValue = String(intValue)
    }
}

struct MealDetailResponse: Codable {
    let meals: [MealDetail]
}

// API Handlers

enum NetworkError: Error {
    case invalidURL
    case invalidResponse
    case decodingError
}

class RecipeAPI {
    static let shared = RecipeAPI()
    private init() {}
    
    private let baseURL = "https://themealdb.com/api/json/v1/1"
    
    func fetchDesserts() async throws -> [Meal] {
        guard let url = URL(string: "\(baseURL)/filter.php?c=Dessert") else {
            throw NetworkError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, 200...299 ~= httpResponse.statusCode else {
            throw NetworkError.invalidResponse
        }
        
        let mealResponse = try JSONDecoder().decode(MealResponse.self, from: data)
        return mealResponse.meals.sorted { $0.strMeal < $1.strMeal }
    }
    
    func fetchMealDetail(id: String) async throws -> MealDetail {
        guard let url = URL(string: "\(baseURL)/lookup.php?i=\(id)") else {
            throw NetworkError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, 200...299 ~= httpResponse.statusCode else {
            throw NetworkError.invalidResponse
        }
        
        let mealDetailResponse = try JSONDecoder().decode(MealDetailResponse.self, from: data)
        guard let mealDetail = mealDetailResponse.meals.first else {
            throw NetworkError.decodingError
        }
        return mealDetail
    }
}

// View Models

class MealListViewModel: ObservableObject {
    @Published var meals: [Meal] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func fetchMeals() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let fetchedMeals = try await RecipeAPI.shared.fetchDesserts()
                DispatchQueue.main.async {
                    self.meals = fetchedMeals
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

class MealDetailViewModel: ObservableObject {
    @Published var mealDetail: MealDetail?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func fetchMealDetail(id: String) {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let fetchedMealDetail = try await RecipeAPI.shared.fetchMealDetail(id: id)
                DispatchQueue.main.async {
                    self.mealDetail = fetchedMealDetail
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

// Views

struct MealDetailView: View {
    @StateObject private var viewModel = MealDetailViewModel()
    let mealId: String
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if viewModel.isLoading {
                    ProgressView()
                } else if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                } else if let mealDetail = viewModel.mealDetail {
                    AsyncImage(url: URL(string: mealDetail.strMealThumb)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(height: 200)
                    .cornerRadius(12)
                    
                    Text(mealDetail.strMeal)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Instructions")
                        .font(.headline)
                    Text(mealDetail.strInstructions)
                    
                    Text("Ingredients")
                        .font(.headline)
                    ForEach(mealDetail.ingredients, id: \.ingredient) { ingredient, measure in
                        Text("• \(measure) \(ingredient)")
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Recipe Details")
        .onAppear {
            viewModel.fetchMealDetail(id: mealId)
        }
    }
}

@main
struct RecipeBrowserApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
