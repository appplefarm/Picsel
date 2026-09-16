//
//  TripImageStore.swift
//  Picsel
//
//  Created by Jonghyeon Lee on 9/17/26.
//

import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// 여행 중 필요한 원격 사진만 별도 파일로 보관합니다. SwiftData 스키마는 변경하지 않습니다.
actor TripImageStore {
    static let shared = TripImageStore()
    private let root: URL
    private let session: URLSession
    private let memory = NSCache<NSURL, NSData>()
    private var pending: [URL: Task<Data, Error>] = [:]
    private var completedTrips: Set<UUID> = []

    init(root: URL? = nil, session: URLSession? = nil) {
        self.root = root ?? URL.applicationSupportDirectory.appendingPathComponent("TripThumbnails", isDirectory: true)
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = 20
            configuration.timeoutIntervalForResource = 45
            configuration.httpMaximumConnectionsPerHost = 3
            self.session = URLSession(configuration: configuration)
        }
        memory.totalCostLimit = 8 * 1_024 * 1_024
        memory.countLimit = 30
    }

    func data(for url: URL, tripID: UUID? = nil) async throws -> Data {
        try Task.checkCancellation()
        if let tripID {
            let file = fileURL(for: url, tripID: tripID)
            if let data = try? Data(contentsOf: file) {
                if let source = CGImageSourceCreateWithData(data as CFData, nil),
                   CGImageSourceGetStatus(source) == .statusComplete { return data }
                // 손상된 파일 때문에 재시도할 때마다 같은 실패가 반복되지 않게 합니다.
                try? FileManager.default.removeItem(at: file)
            }
        }
        if let data = memory.object(forKey: url as NSURL) {
            let value = data as Data
            persist(value, url: url, tripID: tripID)
            return value
        }
        let task: Task<Data, Error>
        let ownsTask: Bool
        if let existing = pending[url] {
            task = existing
            ownsTask = false
        } else {
            let session = session
            task = Task.detached(priority: .utility) {
                try await Self.downloadThumbnail(url: url, session: session)
            }
            pending[url] = task
            ownsTask = true
        }
        // 같은 사진의 다른 표시를 막지 않도록, 한 화면의 취소로 공통 다운로드를 중단하지 않습니다.
        defer { if ownsTask { pending[url] = nil } }
        let data = try await task.value
        try Task.checkCancellation()
        memory.setObject(data as NSData, forKey: url as NSURL, cost: data.count)
        persist(data, url: url, tripID: tripID)
        return data
    }

    /// 모든 사진을 한꺼번에 펼치지 않고, 저장된 사진과 중복 URL을 재사용하며 순서대로 받습니다.
    func prefetch(_ urls: [URL], tripID: UUID) async {
        for url in Set(urls) {
            guard !Task.isCancelled, !completedTrips.contains(tripID) else { return }
            do { _ = try await data(for: url, tripID: tripID) }
            catch {
                if Task.isCancelled || RequestFailure.isCancellation(error) { return }
                // 다음 사진도 같은 오프라인 대기에 빠지지 않게 합니다. 복구되면 부족분만 받습니다.
                if RequestFailure(error).retriesOnReconnect { return }
            }
        }
    }

    /// 완료 저장에 성공한 여행만 삭제합니다. 늦게 끝난 다운로드의 재생성도 막습니다.
    func removeTrip(_ tripID: UUID) {
        completedTrips.insert(tripID)
        try? FileManager.default.removeItem(at: root.appendingPathComponent(tripID.uuidString, isDirectory: true))
    }

    private func fileURL(for url: URL, tripID: UUID) -> URL {
        let name = SHA256.hash(data: Data(url.absoluteString.utf8))
            .map { String(format: "%02x", $0) }.joined()
        return root.appendingPathComponent(tripID.uuidString, isDirectory: true)
            .appendingPathComponent(name).appendingPathExtension("jpg")
    }

    private func persist(_ data: Data, url: URL, tripID: UUID?) {
        guard let tripID, !completedTrips.contains(tripID) else { return }
        let file = fileURL(for: url, tripID: tripID)
        guard !FileManager.default.fileExists(atPath: file.path) else { return }
        do {
            var folder = file.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try folder.setResourceValues(values)
            try data.write(to: file, options: .atomic)
        } catch {
            // 디스크 부족으로 저장하지 못해도 지금 받은 사진은 화면에 표시합니다.
        }
    }

    nonisolated private static func downloadThumbnail(url: URL, session: URLSession) async throws -> Data {
        guard url.scheme == "https" else { throw RequestFailure.invalidResponse }
        // 원본을 Data로 메모리에 모두 올리지 않고 파일에서 축소합니다.
        let (file, response) = try await session.download(for: URLRequest(url: url, timeoutInterval: 20))
        defer { try? FileManager.default.removeItem(at: file) }
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw RequestFailure.server
        }
        try Task.checkCancellation()
        guard let source = CGImageSourceCreateWithURL(file as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 1_000
              ] as CFDictionary) else { throw RequestFailure.invalidResponse }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw RequestFailure.invalidResponse
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw RequestFailure.invalidResponse }
        return data as Data
    }
}
