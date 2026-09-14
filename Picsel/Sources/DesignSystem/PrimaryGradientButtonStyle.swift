import SwiftUI

/// 앱 전반에서 공통으로 사용되는 초록색 하단 CTA 버튼 스타일입니다.
/// 이미지 에셋을 사용하지 않고 코드로 LinearGradient를 구현하여 모든 해상도에서 선명하게 렌더링됩니다.
struct PrimaryGradientButtonStyle: ButtonStyle {
    
    // Figma 시안에 맞는 그라데이션 색상을 조절합니다.
    private let gradientColors = [
        Color(red: 17/255, green: 112/255, blue: 82/255), // 조금 더 짙은 초록 (왼쪽)
        Color(red: 40/255, green: 152/255, blue: 94/255)  // PicselColor.primaryGreen과 유사한 밝은 초록 (오른쪽)
    ]
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 60) // 기존 공통 버튼 높이
            .background(
                LinearGradient(
                    colors: gradientColors,
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            // 눌렸을 때 아주 살짝 줄어들고 투명해지는 애니메이션 적용
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PrimaryGradientButtonStyle {
    /// .buttonStyle(.primaryGradient) 형태로 쉽게 호출할 수 있게 해주는 편의 프로퍼티입니다.
    static var primaryGradient: PrimaryGradientButtonStyle {
        PrimaryGradientButtonStyle()
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 30) {
        // 1번 타입 (글자만 있는 기본형)
        Button {
            print("Tapped")
        } label: {
            Text("최종 목적지로 선택하기")
                .font(.system(size: 16, weight: .bold))
        }
        .buttonStyle(.primaryGradient)
        
        // 2번 타입 (아이콘 + 서브 텍스트가 있는 확장형)
        Button {
            print("Tapped")
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "photo")
                    .font(.system(size: 24))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("사진으로 목적지 고르기")
                        .font(.system(size: 16, weight: .bold))
                    Text("반경 안의 사진들을 둘러보세요")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
            // 확장형의 경우 왼쪽 정렬이 필요하면 내부에서 padding과 레이아웃을 조절할 수 있습니다.
            // .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.primaryGradient)
    }
    .padding()
}
