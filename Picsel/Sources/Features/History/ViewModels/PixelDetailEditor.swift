//
//  PixelDetailEditor.swift
//  Picsel
//
//  Created by kosoobin on 9/15/26.
//

import Foundation
import SwiftData

/// 기록 상세에서 제목·내용·사진만 고치는 편집 상태입니다.
///
/// 기록을 처음 쓸 때 쓰는 `TripRecordViewModel`과 일부러 분리했습니다.
/// 그쪽은 여행을 끝내고 픽셀을 해금하는 일까지 하는데,
/// 편집은 이미 끝난 기록의 내용만 손봐야 하므로 완료 시각이나 픽셀을 건드리면 안 됩니다.
///
/// 경로(RouteStop)는 여행 중에 실제로 다닌 기록이라 편집 대상이 아닙니다.
@Observable
final class PixelDetailEditor {

    var title: String = ""
    var memo: String = ""
    var pickedPhotos: [PickedPhoto] = []

    let maxPhotoCount = 10
    let maxMemoCount = 150

    /// 제목이 비면 저장할 수 없습니다. 목록에서 이름 없는 기록이 되기 때문입니다.
    var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var canAddMorePhotos: Bool {
        pickedPhotos.count < maxPhotoCount
    }

    // MARK: - 불러오기

    /// 저장된 값을 편집 칸에 채웁니다. 편집을 시작할 때와 취소할 때 모두 이걸 씁니다.
    func load(from trip: Trip) {
        title = trip.title
        memo = trip.memo
        pickedPhotos = trip.photos
            .sorted { $0.orderIndex < $1.orderIndex }
            .map { PickedPhoto(imageData: $0.imageData) }
    }

    // MARK: - 사진 조작

    func addPhotos(_ photos: [PickedPhoto]) {
        let remainingCount = maxPhotoCount - pickedPhotos.count
        guard remainingCount > 0 else { return }

        pickedPhotos.append(contentsOf: photos.prefix(remainingCount))
    }

    func removePhoto(_ photo: PickedPhoto) {
        pickedPhotos.removeAll { $0.id == photo.id }
    }

    // MARK: - 저장

    /// 고친 내용을 Trip에 반영합니다.
    ///
    /// 완료 시각·픽셀 연결은 기록을 처음 저장할 때 이미 정해진 값이라 손대지 않습니다.
    ///
    /// - Returns: 저장에 성공했는지. 실패하면 편집 모드를 유지해 입력이 날아가지 않게 합니다.
    @discardableResult
    func save(to trip: Trip, in context: ModelContext) -> Bool {
        let previousTitle = trip.title
        let previousMemo = trip.memo

        trip.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        trip.memo = memo.trimmingCharacters(in: .whitespacesAndNewlines)

        replacePhotos(of: trip, in: context)

        do {
            try context.save()
            return true
        } catch {
            trip.title = previousTitle
            trip.memo = previousMemo
            // TODO: 사용자에게 보여줄 실패 안내는 별도로 정한다.
            print("기록 수정 저장에 실패했습니다: \(error.localizedDescription)")
            return false
        }
    }

    /// 사진을 통째로 갈아 끼웁니다. 배열 순서가 곧 orderIndex입니다.
    ///
    /// 관계만 끊으면 주인 없는 TripPhoto가 DB에 남으므로 컨텍스트에서도 지웁니다.
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

    /// 편집 결과를 화면에 바로 반영할 스냅샷을 만듭니다.
    func makeSnapshot(basedOn snapshot: TripRecordSnapshot) -> TripRecordSnapshot {
        TripRecordSnapshot(
            regionName: snapshot.regionName,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            memo: memo.trimmingCharacters(in: .whitespacesAndNewlines),
            travelDate: snapshot.travelDate,
            photoDataList: pickedPhotos.map(\.imageData),
            placeCount: snapshot.placeCount,
            destinationPhotoURL: snapshot.destinationPhotoURL
        )
    }
}
