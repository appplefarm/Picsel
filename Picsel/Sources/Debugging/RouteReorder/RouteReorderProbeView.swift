//
//  RouteReorderProbeView.swift
//  Picsel
//
//  Created by kosoobin on 9/6/26.
//

import SwiftUI

/// 경로 편집의 순서 변경이 되지 않는 원인을 가르기 위한 최소 재현 화면입니다.
///
/// 실제 화면에서 빼낸 것은 RouteStop 배열과 List·ForEach·onMove 뿐이고,
/// 헤더·커스텀 행·EditMode 커스텀 관리는 모두 제거했습니다.
/// 여기서 순서 변경이 되면 데이터(모델 식별자) 문제가 아니라 화면 구성 문제입니다.
struct RouteReorderProbeView: View {

    /// A: 가장 단순한 형태 — 기본 EditButton, 기본 행
    struct Minimal: View {
        @State private var stops: [RouteStop]

        init(stops: [RouteStop]) {
            _stops = State(initialValue: stops)
        }

        var body: some View {
            NavigationStack {
                List {
                    ForEach(stops) { stop in
                        Text(stop.name)
                    }
                    .onMove { offsets, destination in
                        print("[probe-A] onMove \(Array(offsets)) -> \(destination)")
                        stops.move(fromOffsets: offsets, toOffset: destination)
                    }
                    .onDelete { offsets in
                        stops.remove(atOffsets: offsets)
                    }
                }
                .navigationTitle("A. 기본")
                .toolbar { EditButton() }
            }
        }
    }

    /// B: 실제 화면과 같은 조건 — id를 UUID로 명시
    struct ExplicitID: View {
        @State private var stops: [RouteStop]

        init(stops: [RouteStop]) {
            _stops = State(initialValue: stops)
        }

        var body: some View {
            NavigationStack {
                List {
                    ForEach(stops, id: \.id) { stop in
                        Text(stop.name)
                    }
                    .onMove { offsets, destination in
                        print("[probe-B] onMove \(Array(offsets)) -> \(destination)")
                        stops.move(fromOffsets: offsets, toOffset: destination)
                    }
                }
                .navigationTitle("B. id 명시")
                .toolbar { EditButton() }
            }
        }
    }

    var body: some View {
        EmptyView()
    }
}

#if DEBUG
private func makeProbeStops() -> [RouteStop] {
    [
        ("호미곶 해맞이광장", 36.076_2, 129.567_3),
        ("구룡포 일본인가옥거리", 35.989_6, 129.554_9),
        ("월포해수욕장", 36.157_8, 129.396_1),
        ("이가리 닻 전망대", 36.187_992, 129.379_005)
    ].enumerated().map { index, place in
        RouteStop(
            name: place.0,
            latitude: place.1,
            longitude: place.2,
            stopType: index == 3 ? "destination" : "waypoint",
            orderIndex: index
        )
    }
}

#Preview("A. 기본 List") {
    RouteReorderProbeView.Minimal(stops: makeProbeStops())
}

#Preview("B. id 명시") {
    RouteReorderProbeView.ExplicitID(stops: makeProbeStops())
}
#endif
