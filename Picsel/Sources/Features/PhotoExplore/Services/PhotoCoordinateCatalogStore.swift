//
//  PhotoCoordinateCatalogStore.swift
//  Picsel
//
//  Created by kosoobin on 9/16/26.
//

import CloudKit
import Foundation
import OSLog

/// 좌표 보강 데이터를 CloudKit public DB에서 받아 옵니다.
///
/// 이 데이터만 저장합니다. API가 주는 제목·이미지 주소는 저장하지 않습니다.
/// 공모전 규정이 실시간 호출을 요구하기 때문이며, 좌표는 API가 주지 않는
/// 우리가 만든 값이라 여기에 해당하지 않습니다.
///
/// 로그인은 필요 없습니다. public 데이터베이스는 iCloud 계정 없이도 읽힙니다.
///
/// 받아 오는 순서
/// 1. 메모리에 있으면 그대로 씁니다.
/// 2. CloudKit에서 버전만 먼저 확인하고, 디스크 캐시와 같으면 캐시를 씁니다.
/// 3. 버전이 올라갔으면 새로 받아 캐시를 갱신합니다.
/// 4. 전부 실패하면 앱 번들에 넣어 둔 복사본을 씁니다. (첫 실행·비행기 모드)
actor PhotoCoordinateCatalogStore {

    static let shared = PhotoCoordinateCatalogStore()

    private let containerIdentifier = "iCloud.com.applefarm.picsel"
    private let recordName = "current"
    private let bundledResourceName = "photo_coordinates"

    private let versionDefaultsKey = "PhotoCoordinateCatalog.version"
    private let cacheFileName = "photo_coordinates.json"

    private let logger = Logger(subsystem: "com.applefarm.picsel", category: "PhotoCatalog")

    /// 한 번 읽으면 앱이 살아 있는 동안 다시 받지 않습니다.
    private var loaded: PhotoCoordinateCatalog?

    // MARK: - 읽기

    func catalog() async -> PhotoCoordinateCatalog {
        if let loaded { return loaded }

        let catalog = await fetch()
        loaded = catalog
        return catalog
    }

    /// 다음 호출 때 다시 받아 오게 합니다. 데이터가 갱신됐을 때만 씁니다.
    func invalidate() {
        loaded = nil
    }

    private func fetch() async -> PhotoCoordinateCatalog {
        let cached = cachedCatalog()

        do {
            let record = try await fetchRecord(includingPayload: cached == nil)
            let remoteVersion = record["version"] as? Int64 ?? 0

            // 버전이 그대로면 이미 갖고 있는 것을 씁니다.
            if let cached, cached.version >= remoteVersion {
                logger.info("좌표 캐시 사용 (version \(cached.version))")
                return cached.catalog
            }

            // 버전 확인만 하려고 payload를 빼고 받았다면 여기서 다시 받습니다.
            let full = record["payload"] is CKAsset
                ? record
                : try await fetchRecord(includingPayload: true)

            let catalog = try decode(full)
            saveCache(catalog, version: remoteVersion)
            logger.info("좌표 내려받음 \(catalog.photos.count)건 (version \(remoteVersion))")
            return catalog
        } catch {
            logger.error("좌표 내려받기 실패: \(error.localizedDescription)")

            if let cached {
                logger.info("캐시로 대체 (version \(cached.version))")
                return cached.catalog
            }

            logger.info("번들 복사본으로 대체")
            return bundledCatalog() ?? .empty
        }
    }

    // MARK: - CloudKit

    private func fetchRecord(includingPayload: Bool) async throws -> CKRecord {
        let database = CKContainer(identifier: containerIdentifier).publicCloudDatabase
        let recordID = CKRecord.ID(recordName: recordName)

        guard !includingPayload else {
            return try await database.record(for: recordID)
        }

        // 버전만 보면 되는데 100KB짜리 파일까지 받으면 낭비입니다.
        let results = try await database.records(
            for: [recordID],
            desiredKeys: ["version"]
        )

        guard let result = results[recordID] else {
            throw CKError(.unknownItem)
        }
        return try result.get()
    }

    private func decode(_ record: CKRecord) throws -> PhotoCoordinateCatalog {
        guard let asset = record["payload"] as? CKAsset,
              let fileURL = asset.fileURL else {
            throw CatalogError.missingPayload
        }

        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(PhotoCoordinateCatalog.self, from: data)
    }

    // MARK: - 디스크 캐시

    private func cachedCatalog() -> (catalog: PhotoCoordinateCatalog, version: Int64)? {
        guard let url = cacheURL(),
              let data = try? Data(contentsOf: url),
              let catalog = try? JSONDecoder().decode(PhotoCoordinateCatalog.self, from: data)
        else { return nil }

        let version = Int64(UserDefaults.standard.integer(forKey: versionDefaultsKey))
        return (catalog, version)
    }

    private func saveCache(_ catalog: PhotoCoordinateCatalog, version: Int64) {
        guard let url = cacheURL() else { return }

        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try JSONEncoder().encode(catalog).write(to: url, options: .atomic)
            UserDefaults.standard.set(Int(version), forKey: versionDefaultsKey)
        } catch {
            // 캐시를 못 써도 동작에는 지장이 없습니다. 다음에 다시 받으면 됩니다.
            logger.error("좌표 캐시 저장 실패: \(error.localizedDescription)")
        }
    }

    private func cacheURL() -> URL? {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("PhotoCatalog", isDirectory: true)
            .appendingPathComponent(cacheFileName)
    }

    // MARK: - 번들 복사본

    private func bundledCatalog() -> PhotoCoordinateCatalog? {
        guard let url = Bundle.main.url(
            forResource: bundledResourceName,
            withExtension: "json"
        ),
        let data = try? Data(contentsOf: url) else { return nil }

        return try? JSONDecoder().decode(PhotoCoordinateCatalog.self, from: data)
    }

    // MARK: - 오류

    enum CatalogError: LocalizedError {
        case missingPayload

        var errorDescription: String? {
            switch self {
            case .missingPayload: "좌표 데이터를 읽지 못했어요."
            }
        }
    }
}
