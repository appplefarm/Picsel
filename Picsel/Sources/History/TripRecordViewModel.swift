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

    /// 제목을 자동으로 채운 적이 있는지 기억한다.
    /// 화면이 다시 나타날 때마다 사용자가 지운 제목을 되살리면 안 되기 때문이다.
    private var hasPrefilledTitle = false

    // MARK: - 파생 상태
    /// "인증하고 픽셀 채우기" 버튼 활성화 조건
    var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// 사진을 더 추가할 수 있는지 (+ 버튼 노출 여부)
    var canAddMorePhotos: Bool {
        pickedPhotos.count < maxPhotoCount
    }

    // MARK: - 제목 자동 채우기
    /// 화면에 처음 들어왔을 때 제목을 "지역명 + 여행"으로 채운다.
    /// 그대로 두고 저장해도 되고, 지우고 다시 써도 되는 기본값일 뿐이다.
    func prefillTitleIfNeeded(for trip: Trip) {
        guard !hasPrefilledTitle else { return }
        hasPrefilledTitle = true

        guard title.isEmpty else { return }
        title = trip.suggestedRecordTitle
    }

    // MARK: - 사진 조작
    func addPhotos(_ photos: [PickedPhoto]) {
        // 남은 자리만큼만 받는다 (최대 10장)
        let remainingCount = maxPhotoCount - pickedPhotos.count
        guard remainingCount > 0 else { return }

        pickedPhotos.append(contentsOf: photos.prefix(remainingCount))
    }

    func removePhoto(_ photo: PickedPhoto) {
        pickedPhotos.removeAll { $0.id == photo.id }
    }

    func movePhoto(from source: IndexSet, to destination: Int) {
        // TODO: Step 3 - 배열 순서가 곧 orderIndex
    }

    // MARK: - 다음 화면으로 넘기기
    /// 작성한 내용을 결과/상세 화면으로 넘길 형태로 변환한다.
    /// 지역명·장소 수·날짜는 전부 Trip에서 가져온다.
    func makeSnapshot(for trip: Trip) -> TripRecordSnapshot {
        TripRecordSnapshot(
            regionName: trip.recordRegionName,
            title: title,
            memo: memo,
            travelDate: trip.recordDate,
            photoDataList: pickedPhotos.map(\.imageData),
            placeCount: trip.recordedStops.count
        )
    }

    // MARK: - 저장 (지금은 비워둠)
    func save(to trip: Trip) {
        // TODO: Step 7 - trip.title / trip.memo 채우고
        //       pickedPhotos를 TripPhoto로 변환해 trip.photos에 연결
        //       modelContext.insert / save는 이 단계에서 붙인다
    }
}
