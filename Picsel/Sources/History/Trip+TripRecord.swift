//
//  Trip+TripRecord.swift
//  Picsel
//
//  Created by kosoobin on 9/10/26.
//

import Foundation

extension Trip {

    /// 기록에 남길 방문 장소입니다.
    ///
    /// 진행 화면에 방문 체크 UI가 없어서 `RouteStop.isVisited`를 true로 바꾸는 코드가 아직 없습니다.
    /// 그 사이에는 계획한 장소를 모두 다녀온 것으로 봅니다.
    /// TODO: 방문 체크가 붙으면 `orderedStops.filter(\.isVisited)`만 남깁니다.
    var recordedStops: [RouteStop] {
        let visited = orderedStops.filter(\.isVisited)
        return visited.isEmpty ? orderedStops : visited
    }

    /// 기록 화면에 표시할 지역 이름입니다.
    ///
    /// 픽셀이 이미 연결돼 있으면 그 이름을 그대로 쓰고,
    /// 아직 저장 전이면 목적지 주소에서 뽑아냅니다.
    var recordRegionName: String {
        if let regionName = pixel?.regionName, !regionName.isEmpty {
            return regionName
        }
        return TripRegionName.make(from: destinationStop?.address)
    }

    /// 픽셀 판정까지 끝난 뒤 쓸 지역 이름입니다.
    /// 경계 데이터에서 찾은 이름("포항시")을 우선하고, 못 찾으면 주소에서 뽑은 이름("포항")을 씁니다.
    func resolvedRegionName(using tile: PixelTile?) -> String {
        tile?.name ?? recordRegionName
    }

    /// 기록에 남길 여행 날짜입니다. PicselMapRecord와 같은 우선순위를 씁니다.
    var recordDate: Date {
        endTime ?? startTime ?? createdAt
    }

    /// 이 여행이 채울 픽셀입니다. 최종 목적지 좌표로 판정합니다.
    ///
    /// 경유지가 아니라 목적지를 기준으로 삼는 이유는,
    /// 여행의 대표 지역이 곧 최종 목적지가 있는 시군구이기 때문입니다.
    var pixelTile: PixelTile? {
        guard let destination = destinationStop else { return nil }
        return PixelRegionLocator.tile(
            latitude: destination.latitude,
            longitude: destination.longitude
        )
    }

    /// 기록 화면 제목의 기본값입니다. "포항 여행"
    ///
    /// 지역을 못 읽었을 때는 "여행 지역 여행"처럼 어색해지므로 빈 값을 돌려주고,
    /// 화면에는 placeholder가 그대로 보이게 둡니다.
    var suggestedRecordTitle: String {
        let regionName = recordRegionName
        guard regionName != TripRegionName.fallback else { return "" }
        return "\(regionName) 여행"
    }
}

extension Trip {
    /// Preview / 목업용 더미 여행입니다.
    /// 이 파일의 다른 확장과 달리 실제 로직에서는 쓰지 않습니다.
    static var previewSample: Trip {
        let trip = Trip(title: "포항 여행")

        let destination = RouteStop(
            placeId: "preview-destination",
            name: "이가리 닻 전망대",
            latitude: 36.187_992,
            longitude: 129.379_004,
            stopType: "destination",
            orderIndex: 0
        )
        destination.address = "경상북도 포항시 북구 청하면 이가리"

        let waypoint = RouteStop(
            placeId: "preview-waypoint",
            name: "구룡포 일본인가옥거리",
            latitude: 35.989_2,
            longitude: 129.552_9,
            stopType: "waypoint",
            orderIndex: 1
        )
        waypoint.address = "경상북도 포항시 남구 구룡포읍"

        for stop in [waypoint, destination] {
            stop.trip = trip
            trip.stops.append(stop)
        }

        return trip
    }
}
