import SwiftUI
import MLXLLM
import MLXLMCommon

struct LocalLLMStoreView: View {
    @StateObject private var viewModel = LocalLLMStoreViewModel()
    @State private var searchText = ""
    
    let columns = [
        GridItem(.flexible(), spacing: 20),
        GridItem(.flexible(), spacing: 20)    ]
    
    var filteredModels: [LocalLLMModelManager] {
        if searchText.isEmpty {
            return viewModel.models
        }
        return viewModel.models.filter { model in
            String(describing: model.configuration.id)
                .lowercased()
                .contains(searchText.lowercased())
        }
    }
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Add Local AI Models")
                    .font(.system(size: 28, weight: .bold))
                Text("Depending on your device specifications you can download and use one of the local LLM models. However our recommendation for using WritingTools is llama3.2 3b because it performs good on writing tasks and works on most devices.")
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            
            HStack(spacing: 16) {

                HStack{
                    TextField("Search models", text: $searchText)
                        .textFieldStyle(.plain)
                        .appleStyleTextField(text: searchText, icon: "magnifyingglass"){
                        
                    }
                    
                }
                
                HStack{
                    Button("Add Custom Model") {
                        // TODO
                    }
                }

            }
            .padding(.horizontal)
            
            ScrollView {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(filteredModels) { modelManager in
                        ModelCardView(modelManager: modelManager)
                    }
                }
                .padding()
            }
            
            HStack {
                Button("Skip for now") {
                    // Handle skip action
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button("Save changes") {
                    // Handle save action
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}
