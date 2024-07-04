//
//  ContentView.swift
//  browse_recipes
//
//  Created by Rukhsar Khan on 7/3/24.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = MealListViewModel()
    
    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                } else if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                } else {
                    List(viewModel.meals) { meal in
                        NavigationLink(destination: MealDetailView(mealId: meal.idMeal)) {
                            HStack {
                                AsyncImage(url: URL(string: meal.strMealThumb)) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                } placeholder: {
                                    ProgressView()
                                }
                                .frame(width: 50, height: 50)
                                .cornerRadius(8)
                                
                                Text(meal.strMeal)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Dessert Recipes")
        }
        .onAppear {
            viewModel.fetchMeals()
        }
    }
}

#Preview {
    ContentView()
}
