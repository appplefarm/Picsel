//
//  TripRecordViewModel.swift
//  Picsel
//
//  Created by kosoobin on 8/31/26.
//

import Foundation
import SwiftUI

/// 갤러리에서 고른, 아직 저장 전인 사진 한 장.
/// 저장 시 TripPhoto(imageData:orderIndex:)로 변환된다.
struct PickedPhoto: Identifiable, Hashable {
    let id = UUID()
    let imageData: Data
}

@Observable
final class TripRecordViewModel {

    // MARK: - 입력 값
    var title: String = ""
    var memo: String = ""
    var pickedPhotos: [PickedPhoto] = []

    // MARK: - 상수
    let maxPhotoCount = 10
    let maxMemoCount = 150

    // MARK: - 파생 상태
    /// "인증하고 픽셀 채우기" 버튼 활성화 조건
    var canSave: Bool {
        // TODO: Step 5 - 제목이 비어있지 않고, 사진이 1장 이상일 때 true
        false
    }

    /// 사진을 더 추가할 수 있는지 (+ 버튼 노출 여부)
    var canAddMorePhotos: Bool {
        pickedPhotos.count < maxPhotoCount
    }

    // MARK: - 사진 조작
    func addPhotos(_ photos: [PickedPhoto]) {
        // 남은 자리만큼만 받는다 (최대 10장)
        let remainingCount = maxPhotoCount - pickedPhotos.count
        guard remainingCount > 0 else { return }

        pickedPhotos.append(contentsOf: photos.prefix(remainingCount))
    }

    func removePhoto(_ photo: PickedPhoto) {
        // TODO: Step 3
        pickedPhotos.removeAll { $0.id == photo.id }
    }

    func movePhoto(from source: IndexSet, to destination: Int) {
        // TODO: Step 3 - 배열 순서가 곧 orderIndex
    }

    // MARK: - 저장 (지금은 비워둠)
    func save(to trip: Trip) {
        // TODO: Step 7 - trip.title / trip.memo 채우고
        //       pickedPhotos를 TripPhoto로 변환해 trip.photos에 연결
        //       modelContext.insert / save는 이 단계에서 붙인다
    }
}
