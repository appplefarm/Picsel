import SwiftUI

struct VisitedPlaceRow: View {
    let stop: RouteStop
    let photoURL: URL?
    let isSelected: Bool
    let toggleSelection: () -> Void
    
    var body: some View {
        Button(action: toggleSelection) {
            HStack(spacing: 16) {
                // 썸네일
                AsyncImage(url: photoURL) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .overlay(ProgressView())
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                    @unknown default:
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                    }
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                // 체크 여부에 따라 흑백 처리 (옵션)
                .saturation(isSelected ? 1.0 : 0.0)
                .opacity(isSelected ? 1.0 : 0.5)
                
                // 정보 텍스트
                VStack(alignment: .leading, spacing: 6) {
                    Text(stop.name)
                        .font(PicselFont.label01)
                        .foregroundStyle(isSelected ? .black : Color(white: 0.6))
                        .lineLimit(1)
                    
                    Text(stop.address ?? "주소 미상")
                        .font(PicselFont.caption01)
                        .foregroundStyle(Color(white: 0.6))
                        .lineLimit(1)
                }
                
                Spacer()
                
                // 체크 아이콘
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .resizable()
                    .frame(width: 26, height: 26)
                    // TODO: 실제 피그마의 메인 컬러로 교체 가능 (현재 기본 green)
                    .foregroundStyle(isSelected ? Color.green : Color(white: 0.8))
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(Color.white)
        }
        .buttonStyle(.plain)
    }
}
