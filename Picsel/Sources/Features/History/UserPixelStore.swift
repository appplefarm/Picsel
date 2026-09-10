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
/// UserPixel은 여행 기록과 별개로 "이 지역을 밟았다"는 사실만 들고 있습니다.
/// 그래서 나중에 여행 기록을 지워도 획득한 픽셀은 지도에 남습니다.
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

    // MARK: - 조회 / 생성

    /// regionCode는 @Attribute(.unique)라 같은 코드로 두 번 만들 수 없습니다.
    /// 그래서 먼저 찾아보고 없을 때만 새로 만듭니다.
    private static func existingPixel(
        withCode regionCode: Int,
        in context: ModelContext
    ) -> UserPixel? {
        let descriptor = FetchDescriptor<UserPixel>(
            predicate: #Predicate { $0.regionCode == regionCode }
        )

        guard let found = try? context.fetch(descriptor).first else { return nil }

        found.totalVisits += 1
        return found
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
