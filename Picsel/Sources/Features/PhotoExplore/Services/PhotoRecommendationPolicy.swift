import CoreLocation
import Foundation
import OSLog

/// 좌표 카탈로그와 실시간 수상작 응답에서 반경 기반 추천 후보를 만드는 순수 정책입니다.
nonisolated enum PhotoRecommendationPolicy {
    static let minimumRadiusMeters: CLLocationDistance = 10_000
    static let maximumResultCount = 7
    static let maximumGalleryResultCount = 10

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
        return validUniqueCoordinates(in: catalog, source: .award).filter { photo in
            let location = CLLocation(
                latitude: photo.latitude,
                longitude: photo.longitude
            )
            return origin.distance(from: location) <= effectiveRadius
        }
    }

    /// TransitSwipe에서 동일 시·군·구로 좁힌 gallery 좌표를 검증하고 중복 제거합니다.
    static func galleryCoordinates(in catalog: PhotoCoordinateCatalog) -> [PhotoCoordinate] {
        validUniqueCoordinates(in: catalog, source: .gallery)
    }

    static func destinations(
        coordinates: [PhotoCoordinate],
        remotePhotos: [RemotePhoto],
        limit: Int
    ) -> [PhotoDestination] {
        makeDestinations(
            coordinates: coordinates,
            remotePhotos: remotePhotos,
            source: .award,
            limit: limit,
            maximumCount: maximumResultCount
        )
    }

    static func galleryDestinations(
        coordinates: [PhotoCoordinate],
        remotePhotos: [RemotePhoto],
        limit: Int
    ) -> [PhotoDestination] {
        makeDestinations(
            coordinates: coordinates,
            remotePhotos: remotePhotos,
            source: .gallery,
            limit: limit,
            maximumCount: maximumGalleryResultCount
        )
    }

    private static func validUniqueCoordinates(
        in catalog: PhotoCoordinateCatalog,
        source: PhotoAPISource
    ) -> [PhotoCoordinate] {
        var seenPhotoIDs = Set<String>()
        var candidates: [PhotoCoordinate] = []

        for photo in catalog.photos where photo.source == source {
            let photoID = photo.photoID.trimmingCharacters(in: .whitespacesAndNewlines)
            let placeName = photo.placeName.trimmingCharacters(in: .whitespacesAndNewlines)
            let address = photo.address.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !photoID.isEmpty,
                  !placeName.isEmpty,
                  !address.isEmpty,
                  photo.latitude.isFinite,
                  photo.longitude.isFinite,
                  CLLocationCoordinate2DIsValid(photo.coordinate) else { continue }

            guard seenPhotoIDs.insert(photoID).inserted else {
                logger.warning(
                    "중복 photoID를 제외합니다: \(photoID, privacy: .public)"
                )
                continue
            }

            candidates.append(photo)
        }

        return candidates
    }

    private static func makeDestinations(
        coordinates: [PhotoCoordinate],
        remotePhotos: [RemotePhoto],
        source: PhotoAPISource,
        limit: Int,
        maximumCount: Int
    ) -> [PhotoDestination] {
        let resultLimit = min(max(limit, 0), maximumCount)
        guard resultLimit > 0 else { return [] }

        var remoteByPhotoID: [String: RemotePhoto] = [:]
        for photo in remotePhotos where photo.source == source {
            let photoID = photo.photoID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !photoID.isEmpty,
                  isDisplayableImageURL(photo.displayImageURL),
                  remoteByPhotoID[photoID] == nil else { continue }
            remoteByPhotoID[photoID] = photo
        }

        let destinations = coordinates.compactMap { place -> PhotoDestination? in
            guard place.source == source else { return nil }
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
