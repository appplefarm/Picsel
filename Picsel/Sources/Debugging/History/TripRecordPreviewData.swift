//
//  TripRecordPreviewData.swift
//  Picsel
//
//  Created by kosoobin on 9/15/26.
//

#if DEBUG
import UIKit

/// 프리뷰에서 비율이 제각각인 사진 묶음을 만들어 줍니다.
///
/// 실제 사진 없이도 사진 개수에 따른 배치를 눈으로 확인하려고 둡니다.
enum TripRecordPreviewData {

    /// 가로가 긴 것, 세로가 긴 것, 정사각을 섞어서 `count`장을 만듭니다.
    static func photoDataList(count: Int) -> [Data] {
        let sizes: [CGSize] = [
            CGSize(width: 400, height: 300),
            CGSize(width: 300, height: 500),
            CGSize(width: 500, height: 500),
            CGSize(width: 600, height: 340),
            CGSize(width: 320, height: 460)
        ]

        return (0..<max(count, 0)).compactMap { index in
            let size = sizes[index % sizes.count]

            let renderer = UIGraphicsImageRenderer(size: size)
            let image = renderer.image { context in
                UIColor(
                    hue: CGFloat(index) / CGFloat(max(count, 1)),
                    saturation: 0.35,
                    brightness: 0.85,
                    alpha: 1
                ).setFill()
                context.fill(CGRect(origin: .zero, size: size))

                // 몇 번째 사진인지 눈으로 구분되도록 번호를 찍습니다.
                let number = "\(index + 1)" as NSString
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: size.height * 0.3, weight: .bold),
                    .foregroundColor: UIColor.white.withAlphaComponent(0.7)
                ]
                let textSize = number.size(withAttributes: attributes)
                number.draw(
                    at: CGPoint(
                        x: (size.width - textSize.width) / 2,
                        y: (size.height - textSize.height) / 2
                    ),
                    withAttributes: attributes
                )
            }

            return image.pngData()
        }
    }

    /// 사진 개수만 바꿔 가며 기록 상세를 확인할 때 씁니다.
    static func snapshot(photoCount: Int) -> TripRecordSnapshot {
        TripRecordSnapshot(
            regionName: "포항",
            title: "니야와 바다 여행",
            memo: """
            아침 일찍 니야와 바닷가를 걸었다. 모래 위에 남은 작은 발자국을 따라 천천히 걷다가, \
            사람이 적은 방파제 끝에서 한참 파도소리를 들었다. 특별한 계획은 없었지만 바람이 좋았고, \
            들어오는 길에 우연히 발견한 작은 카페의 레몬에이드까지 오래 기억하고 싶은 하루였다.
            """,
            travelDate: .now,
            photoDataList: photoDataList(count: photoCount),
            placeCount: 3,
            destinationPhotoURL: URL(string: "https://picsum.photos/seed/picsel-hero/800/900")
        )
    }
}
#endif
