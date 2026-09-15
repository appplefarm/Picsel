//
//  UserPixelStore.swift
//  Picsel
//
//  Created by kosoobin on 9/11/26.
//

import Foundation
import SwiftData

/// 여행이 끝났을 때 획득한 픽셀(UserPixel)을 만들거나 갱신합니다.
///
/// UserPixel은 여행 기록과 별개로 "이 지역을 밟았다"는 사실을 들고 있습니다.
/// 다만 그 지역의 기록이 하나도 남지 않으면 픽셀도 함께 내립니다.
/// 지도에는 칠해져 있는데 눌러 보면 아무 기록도 없는 상태를 만들지 않기 위해서입니다.
enum UserPixelStore {

    /// 여행을 해당 지역의 픽셀에 연결하고 방문 횟수를 올립니다.
    ///
    /// 같은 여행을 두 번 저장해도 횟수가 부풀지 않도록,
    /// 이미 픽셀이 연결된 여행은 그대로 둡니다.
    ///
    /// - Returns: 연결된 픽셀. 코드를 숫자로 바꾸지 못하면 nil입니다.
    @discardableResult
    static func link(
        _ trip: Trip,
        to tile: PixelTile,
        in context: ModelContext
    ) -> UserPixel? {
        // 이 여행은 이미 픽셀을 받았습니다. 다시 세지 않습니다.
        if let alreadyLinked = trip.pixel {
            return alreadyLinked
        }

        guard let regionCode = tile.numericCode else {
            print("픽셀 코드를 숫자로 바꾸지 못했습니다: \(tile.code)")
            return nil
        }

        let pixel = existingPixel(withCode: regionCode, in: context)
            ?? makePixel(code: regionCode, name: tile.name, in: context)

        trip.pixel = pixel
        return pixel
    }

    // MARK: - 삭제

    /// 여행 기록을 지웁니다. 경로와 사진도 함께 사라집니다.
    ///
    /// 그 지역의 마지막 기록이었다면 픽셀도 지도에서 내립니다.
    /// 기록이 더 남아 있으면 방문 횟수만 하나 줄입니다.
    ///
    /// - Returns: 삭제에 성공했는지.
    @discardableResult
    static func delete(_ trip: Trip, in context: ModelContext) -> Bool {
        if let pixel = trip.pixel {
            pixel.totalVisits = max(pixel.totalVisits - 1, 0)

            // 관계를 먼저 끊어야 남은 기록 수를 제대로 셀 수 있습니다.
            trip.pixel = nil

            // UserPixel.trips의 삭제 규칙이 cascade라서, 기록이 남아 있는데 픽셀을 지우면
            // 그 기록까지 통째로 사라집니다. 비어 있을 때만 지웁니다.
            if pixel.trips.isEmpty {
                context.delete(pixel)
            }
        }

        // Trip은 stops와 photos에 cascade가 걸려 있어 함께 지워집니다.
        context.delete(trip)

        do {
            try context.save()
            return true
        } catch {
            // TODO: 사용자에게 보여줄 실패 안내는 별도로 정한다.
            print("여행 기록 삭제에 실패했습니다: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - 조회 / 생성

    /// 같은 지역의 픽셀을 찾아 방문 횟수를 올립니다.
    ///
    /// CloudKit이 유니크 제약을 지원하지 않아 regionCode의 @Attribute(.unique)를 뺐습니다.
    /// 그래서 같은 코드의 픽셀이 둘 이상 존재할 수 있고(두 기기에서 같은 지역을 각각 저장한 경우),
    /// 발견하면 하나로 합칩니다.
    private static func existingPixel(
        withCode regionCode: Int,
        in context: ModelContext
    ) -> UserPixel? {
        let descriptor = FetchDescriptor<UserPixel>(
            predicate: #Predicate { $0.regionCode == regionCode }
        )

        guard let matches = try? context.fetch(descriptor),
              let survivor = matches.first
        else { return nil }

        mergeDuplicates(Array(matches.dropFirst()), into: survivor, in: context)

        survivor.totalVisits += 1
        return survivor
    }

    /// 중복된 픽셀을 하나로 합칩니다.
    ///
    /// UserPixel.trips에 걸린 삭제 규칙이 cascade라서,
    /// 여행을 먼저 옮겨 두지 않고 픽셀을 지우면 그 여행 기록까지 함께 사라집니다.
    private static func mergeDuplicates(
        _ duplicates: [UserPixel],
        into survivor: UserPixel,
        in context: ModelContext
    ) {
        guard !duplicates.isEmpty else { return }

        for duplicate in duplicates {
            for trip in duplicate.trips {
                trip.pixel = survivor
            }
            duplicate.trips.removeAll()

            survivor.totalVisits += duplicate.totalVisits
            context.delete(duplicate)
        }

        print("중복된 픽셀 \(duplicates.count)개를 \(survivor.regionName)에 합쳤습니다.")
    }

    private static func makePixel(
        code: Int,
        name: String,
        in context: ModelContext
    ) -> UserPixel {
        // UserPixel의 init이 totalVisits를 1로 시작하므로 여기서 더하지 않습니다.
        let pixel = UserPixel(regionCode: code, regionName: name)
        context.insert(pixel)
        return pixel
    }
}
