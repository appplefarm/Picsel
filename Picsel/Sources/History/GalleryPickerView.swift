//
//  GalleryPickerView.swift
//  Picsel
//
//  Created by kosoobin on 8/31/26.
//

import SwiftUI
import Photos

struct GalleryPickerView: View {

    /// 이미 선택된 개수를 알아야 남은 장수를 계산할 수 있다
    let selectedCount: Int
    let maxCount: Int
    /// 선택 완료 시 부모(TripRecordView)로 돌려주는 클로저
    let onConfirm: ([PickedPhoto]) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var assets: [PHAsset] = []
    @State private var selectedAssetIDs: [String] = []   // 배열 = 선택 순서(번호 뱃지)

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

    var body: some View {
        VStack(spacing: 0) {
            // TODO: Step 4 - 상단 바 (X 닫기 / "갤러리" / 다음 버튼)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 2) {
                    // TODO: Step 4 - assets를 썸네일로 그리고, 탭하면 selectedAssetIDs에 토글
                    //       선택된 셀에는 파란 테두리 + 선택 순번 뱃지
                }
            }
        }
        .task {
            // TODO: Step 4 - 권한 요청 후 사진 목록 로드
        }
    }
}
