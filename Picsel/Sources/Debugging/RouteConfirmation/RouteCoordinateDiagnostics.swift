//
//  RouteCoordinateDiagnostics.swift
//  Picsel
//
//  Created by kosoobin on 9/17/26.
//

#if DEBUG
import CoreLocation
import Foundation

/// 좌표 보정이 무엇을 어디로 옮겼는지 콘솔에 남깁니다.
///
/// 화면만 봐서는 "보정돼서 경로에 남은 장소"와 "애초에 문제가 없던 장소"가 똑같아 보입니다.
/// 보정이 정말 동작했는지, 옮긴 자리가 엉뚱한 동네는 아닌지는 여기서만 확인할 수 있습니다.
///
/// DEBUG 빌드에서만 컴파일되므로 배포본에는 들어가지 않습니다.
nonisolated enum RouteCoordinateDiagnostics {

    /// 이 거리를 넘게 옮겼으면 다른 동네의 같은 도로명을 잡았을 수 있다는 신호입니다.
    private static let suspiciousDistanceMeters: CLLocationDistance = 3_000

    /// 보정 한 건의 결과를 남깁니다.
    static func record(
        name: String,
        address: String?,
        from original: CLLocationCoordinate2D,
        to corrected: CLLocationCoordinate2D?
    ) {
        guard let corrected else {
            print(
                """
                [보정 ✗] \(name)
                  주소: \(address ?? "없음")
                  \(format(original)) → 도로 쪽 좌표를 찾지 못했습니다
                """
            )
            return
        }

        print(
            """
            [보정 ✓] \(name)
              주소: \(address ?? "없음")
              \(format(original)) → \(format(corrected))  \(movedText(from: original, to: corrected))
            """
        )
    }

    private static func movedText(
        from original: CLLocationCoordinate2D,
        to corrected: CLLocationCoordinate2D
    ) -> String {
        let meters = CLLocation(latitude: original.latitude, longitude: original.longitude)
            .distance(
                from: CLLocation(latitude: corrected.latitude, longitude: corrected.longitude)
            )

        let distance = meters < 1_000
            ? String(format: "%.0fm", meters)
            : String(format: "%.1fkm", meters / 1_000)

        return meters > suspiciousDistanceMeters ? "(\(distance) 이동  ⚠️ 너무 멂)" : "(\(distance) 이동)"
    }

    private static func format(_ coordinate: CLLocationCoordinate2D) -> String {
        String(format: "%.6f, %.6f", coordinate.latitude, coordinate.longitude)
    }
}
#endif
