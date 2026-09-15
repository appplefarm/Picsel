import CoreLocation
import Foundation
import OSLog

/// 좌표 카탈로그와 실시간 수상작 응답에서 반경 기반 추천 후보를 만드는 순수 정책입니다.
nonisolated enum PhotoRecommendationPolicy {
    static let minimumRadiusMeters: CLLocationDistance = 10_000
    static let maximumResultCount = 7

    private static let logger = Logger(
        subsystem: "com.applefarm.picsel",
        category: "PhotoRecommendation"
    )

    static func awardCoordinates(
        in catalog: PhotoCoordinateCatalog,
        from origin: CLLocation,
        radiusMeters: CLLocationDistance
    ) -> [PhotoCoordinate] {
        guard CLLocationCoordinate2DIsValid(origin.coordinate),
              radiusMeters.isFinite else { return [] }

        let effectiveRadius = max(radiusMeters, minimumRadiusMeters)
        var seenPhotoIDs = Set<String>()
        var candidates: [PhotoCoordinate] = []

        for photo in catalog.photos where photo.source == .award {
            let photoID = photo.photoID.trimmingCharacters(in: .whitespacesAndNewlines)
            let placeName = photo.placeName.trimmingCharacters(in: .whitespacesAndNewlines)
            let address = photo.address.trimmingCharacters(in: .whitespacesAndNewlines)
            let coordinate = photo.coordinate

            guard !photoID.isEmpty,
                  !placeName.isEmpty,
                  !address.isEmpty,
                  photo.latitude.isFinite,
                  photo.longitude.isFinite,
                  CLLocationCoordinate2DIsValid(coordinate) else { continue }

            guard seenPhotoIDs.insert(photoID).inserted else {
                logger.warning(
                    "중복 photoID를 제외합니다: \(photoID, privacy: .public)"
                )
                continue
            }

            let location = CLLocation(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
            guard origin.distance(from: location) <= effectiveRadius else { continue }
            candidates.append(photo)
        }

        return candidates
    }

    static func destinations(
        coordinates: [PhotoCoordinate],
        remotePhotos: [RemotePhoto],
        limit: Int
    ) -> [PhotoDestination] {
        let resultLimit = min(max(limit, 0), maximumResultCount)
        guard resultLimit > 0 else { return [] }

        var remoteByPhotoID: [String: RemotePhoto] = [:]
        for photo in remotePhotos where photo.source == .award {
            let photoID = photo.photoID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !photoID.isEmpty,
                  isDisplayableImageURL(photo.displayImageURL),
                  remoteByPhotoID[photoID] == nil else { continue }
            remoteByPhotoID[photoID] = photo
        }

        let destinations = coordinates.compactMap { place -> PhotoDestination? in
            let photoID = place.photoID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let photo = remoteByPhotoID[photoID] else { return nil }

            return PhotoDestination(
                id: photo.id,
                name: place.placeName,
                photoURL: photo.displayImageURL.absoluteString,
                detailDescription: photo.title,
                regionCode: Int(place.regionCode),
                address: place.address,
                latitude: place.latitude,
                longitude: place.longitude
            )
        }

        return Array(destinations.shuffled().prefix(resultLimit))
    }

    private static func isDisplayableImageURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host, !host.isEmpty else { return false }
        return true
    }
}
