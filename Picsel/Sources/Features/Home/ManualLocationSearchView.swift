import SwiftUI
import CoreLocation
import MapKit

struct ManualLocationSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = ManualLocationSearchViewModel()
    
    var onLocationSelected: (CLLocation, String) -> Void
    
    var body: some View {
        NavigationStack {
            List {
                if viewModel.isSearching {
                    HStack {
                        Spacer()
                        ProgressView("위치 정보 가져오는 중...")
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                } else if viewModel.searchResults.isEmpty && !viewModel.searchQuery.isEmpty {
                    Text("검색 결과가 없습니다.")
                        .foregroundColor(.gray)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(viewModel.searchResults, id: \.self) { completion in
                        Button {
                            Task {
                                if let (location, name) = await viewModel.selectLocation(completion: completion) {
                                    onLocationSelected(location, name)
                                    dismiss()
                                }
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(completion.title)
                                    .font(PicselFont.label01)
                                    .foregroundStyle(.primary)
                                
                                if !completion.subtitle.isEmpty {
                                    Text(completion.subtitle)
                                        .font(PicselFont.body01)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .searchable(text: Binding(
                get: { viewModel.searchQuery },
                set: { viewModel.searchQuery = $0 }
            ), prompt: "원하시는 장소나 주소를 검색해 보세요")
            .navigationTitle("위치 직접 입력")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("닫기") {
                        dismiss()
                    }
                }
            }
            .alert("오류", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("확인", role: .cancel) {}
            } message: {
                if let message = viewModel.errorMessage {
                    Text(message)
                }
            }
        }
    }
}
