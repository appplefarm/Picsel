//
//  TripRecordViewModel.swift
//  Picsel
//
//  Created by kosoobin on 8/31/26.
//

import Foundation
import SwiftData
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
            placeCount: trip.recordedStops.count,
            destinationPhotoURL: trip.representativePhotoURL
        )
    }

    // MARK: - 저장
    /// 작성한 내용을 Trip에 반영하고 SwiftData에 저장한다.
    ///
    /// Trip은 여행을 시작할 때 이미 컨텍스트에 등록되어 있으므로
    /// 여기서는 insert가 아니라 값을 채우고 save만 한다.
    ///
    /// - Returns: 저장에 성공했는지. 실패하면 다음 화면으로 넘어가지 않는다.
    @discardableResult
    func save(to trip: Trip, in context: ModelContext) -> Bool {
        trip.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        trip.memo = memo.trimmingCharacters(in: .whitespacesAndNewlines)
        trip.endTime = Date()
        trip.isDone = true

        // 픽셀맵이 이 코드로 칠할 칸을 찾는다. 좌표가 경계 밖이면 nil이 될 수 있다.
        let tile = trip.pixelTile
        trip.targetPixelCode = tile?.code

        // 픽셀을 못 찾아도 기록 자체는 남긴다. 지도에만 안 뜰 뿐이다.
        if let tile {
            UserPixelStore.link(trip, to: tile, in: context)
        }

        replacePhotos(of: trip, in: context)

        do {
            try context.save()
            return true
        } catch {
            // 저장에 실패했는데 완료 표시만 남으면 픽셀맵에 빈 기록이 뜨므로 되돌린다.
            trip.isDone = false
            trip.endTime = nil
            // TODO: 사용자에게 보여줄 실패 안내는 별도로 정한다.
            print("여행 기록 저장에 실패했습니다: \(error.localizedDescription)")
            return false
        }
    }

    /// 고른 사진을 TripPhoto로 바꿔 붙인다. 배열 순서가 곧 orderIndex다.
    ///
    /// 저장을 두 번 타더라도 사진이 겹쳐 쌓이지 않도록 기존 사진을 먼저 지운다.
    /// 관계만 끊으면 주인 없는 TripPhoto가 DB에 남기 때문에 컨텍스트에서도 삭제한다.
    private func replacePhotos(of trip: Trip, in context: ModelContext) {
        for photo in trip.photos {
            photo.trip = nil
            context.delete(photo)
        }
        trip.photos.removeAll()

        for (index, picked) in pickedPhotos.enumerated() {
            let photo = TripPhoto(imageData: picked.imageData, orderIndex: index)
            photo.trip = trip
            trip.photos.append(photo)
        }
    }
}
