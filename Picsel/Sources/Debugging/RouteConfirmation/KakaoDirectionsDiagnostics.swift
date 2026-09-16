//
//  KakaoDirectionsDiagnostics.swift
//  Picsel
//
//  Created by kosoobin on 9/16/26.
//

#if DEBUG
import CoreLocation
import Foundation

/// 카카오 길찾기 요청과 응답을 콘솔에 남깁니다.
///
/// 화면에 보이는 문구는 실패의 "종류"만 알려 주고, 업체가 실제로 무엇을 거절했는지는
/// RequestFailure로 바뀌는 과정에서 사라집니다. 원인을 좁히려면 응답 원문이 한 번은 필요합니다.
/// 같은 요청이 매번 실패하는지, 경유지 수에 따라 달라지는지도 여기서 드러납니다.
///
/// DEBUG 빌드에서만 컴파일되므로 배포본에는 들어가지 않습니다.
nonisolated enum KakaoDirectionsDiagnostics {

    /// 응답 본문을 남길 최대 길이입니다. 경로 좌표가 수천 개라 전문을 찍으면 콘솔이 묻힙니다.
    private static let bodyPreviewLimit = 400

    // MARK: - 요청

    /// 보낸 좌표를 남깁니다.
    ///
    /// 같은 API가 깨끗한 좌표로는 성공하는데 앱에서만 실패한다면 차이는 보낸 값뿐입니다.
    /// 경유지 하나에 이상한 좌표가 섞여도 요청 전체가 거절되므로 전부 찍습니다.
    static func record(
        origin: CLLocationCoordinate2D,
        waypoints: [CLLocationCoordinate2D],
        destination: CLLocationCoordinate2D
    ) {
        let waypointText = waypoints.isEmpty
            ? "-"
            : waypoints.map(format).joined(separator: " / ")

        print(
            """
            [Kakao →] 경유지 \(waypoints.count)개
              origin     : \(format(origin))
              waypoints  : \(waypointText)
              destination: \(format(destination))
            """
        )
    }

    /// 좌표를 눈으로 바로 검사할 수 있게, 한국 범위를 벗어나면 표시를 답니다.
    private static func format(_ coordinate: CLLocationCoordinate2D) -> String {
        let text = String(format: "%.6f, %.6f", coordinate.latitude, coordinate.longitude)

        guard CLLocationCoordinate2DIsValid(coordinate) else { return text + "  ⚠️ 잘못된 좌표" }

        let isInKorea = (33.0...39.0).contains(coordinate.latitude)
            && (124.0...132.0).contains(coordinate.longitude)
        return isInKorea ? text : text + "  ⚠️ 한국 밖"
    }

    /// 골라낸 "갈 수 없는 경유지"를 남깁니다.
    ///
    /// 전부 걸러졌다면 경유지가 아니라 출발지 쪽이 문제일 수 있다는 신호이기도 합니다.
    static func recordUnreachable(indices: Set<Int>, of waypoints: [CLLocationCoordinate2D]) {
        guard !indices.isEmpty else {
            print("[Kakao ?] 갈 수 없는 경유지를 찾지 못했습니다 · 경유지 \(waypoints.count)개")
            return
        }

        let listed = indices.sorted().map { index in
            "  \(index + 1)번째: \(format(waypoints[index]))"
        }

        print(
            """
            [Kakao ✂︎] 갈 수 없는 경유지 \(indices.count)/\(waypoints.count)개
            \(listed.joined(separator: "\n"))
            """
        )
    }

    // MARK: - 응답

    static func record(
        status: Int,
        waypointCount: Int,
        elapsed: TimeInterval,
        data: Data
    ) {
        let outcome = Outcome(status: status, data: data)

        // 성공한 요청까지 본문을 찍으면 실패가 묻힙니다. 한 줄만 남깁니다.
        guard !outcome.isSuccess else {
            print("[Kakao ✓] HTTP \(status) · 경유지 \(waypointCount)개 · \(seconds(elapsed))")
            return
        }

        print(
            """
            [Kakao ✗] HTTP \(status) · 경유지 \(waypointCount)개 · \(seconds(elapsed))
              result_code: \(outcome.resultCodeText)
              result_msg : \(outcome.resultMessage ?? "-")
              body       : \(outcome.bodyPreview)
            """
        )
    }

    /// 응답이 오기 전에 끊긴 경우입니다. 시간 초과가 여기에 들어옵니다.
    static func record(
        networkError: Error,
        waypointCount: Int,
        elapsed: TimeInterval
    ) {
        let error = networkError as NSError
        print(
            """
            [Kakao ✗] 응답 없음 · 경유지 \(waypointCount)개 · \(seconds(elapsed))
              domain: \(error.domain)  code: \(error.code)
              \(error.localizedDescription)
            """
        )
    }

    // MARK: - 응답 읽기

    private struct Outcome {
        let isSuccess: Bool
        let resultCodeText: String
        let resultMessage: String?
        let bodyPreview: String

        init(status: Int, data: Data) {
            let parsed = Self.parse(data)
            resultCodeText = parsed.code.map(String.init) ?? "-"
            resultMessage = parsed.message
            isSuccess = (200..<300).contains(status) && parsed.code == 0

            let text = String(data: data, encoding: .utf8) ?? "<문자로 읽을 수 없는 응답>"
            bodyPreview = text.count > KakaoDirectionsDiagnostics.bodyPreviewLimit
                ? String(text.prefix(KakaoDirectionsDiagnostics.bodyPreviewLimit)) + "…(생략)"
                : text
        }

        /// 성공 응답은 routes[0]에, 게이트웨이 오류는 최상위에 코드와 문구가 있습니다.
        /// 형태가 다르므로 둘 다 살펴봅니다.
        private static func parse(_ data: Data) -> (code: Int?, message: String?) {
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return (nil, nil)
            }

            if let route = (json["routes"] as? [[String: Any]])?.first {
                return (route["result_code"] as? Int, route["result_msg"] as? String)
            }

            let message = json["message"] as? String
                ?? json["msg"] as? String
                ?? json["errorType"] as? String
            return (json["code"] as? Int, message)
        }
    }

    private static func seconds(_ elapsed: TimeInterval) -> String {
        String(format: "%.1f초", elapsed)
    }
}
#endif
