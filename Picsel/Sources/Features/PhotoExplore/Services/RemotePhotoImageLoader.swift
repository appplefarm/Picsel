//
//  RemotePhotoImageLoader.swift
//  Picsel
//
//  Created by Jonghyeon Lee on 8/28/26.
//

import CoreGraphics
import Foundation
import ImageIO

/// 탐색/상세가 같은 압축 사진을 재사용하고, 디코딩 크기는 각 화면에 맞춥니다.
actor RemotePhotoImageLoader {
    static let shared = RemotePhotoImageLoader()
    nonisolated private static let maximumTexturePixelSize = 1_600
    private let memoryLimit = 24 * 1_024 * 1_024
    private let memory = NSCache<NSURL, NSData>()
    private let session: URLSession
    private var pending: [URL: Task<Data, Error>] = [:]

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.urlCache = nil
            configuration.timeoutIntervalForRequest = 20
            configuration.timeoutIntervalForResource = 45
            configuration.httpMaximumConnectionsPerHost = 4
            self.session = URLSession(configuration: configuration)
        }
        // 고해상도 CGImage 7장을 추가로 보관하지 않습니다. 메모리 압박 시 비워지는 임시 캐시입니다.
        memory.totalCostLimit = memoryLimit
        memory.countLimit = 14
    }

    nonisolated static func image(from url: URL) async throws -> CGImage {
        try await image(from: url, maximumPixelSize: maximumTexturePixelSize)
    }

    nonisolated static func image(
        from url: URL,
        maximumPixelSize: Int
    ) async throws -> CGImage {
        try await shared.image(from: url, maximumPixelSize: maximumPixelSize)
    }

    nonisolated func image(from url: URL, maximumPixelSize: Int) async throws -> CGImage {
        let data = try await data(for: url)
        try Task.checkCancellation()
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw RequestFailure.invalidResponse
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize
        ]

        guard let image = CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            options as CFDictionary
        ) else {
            await removeCachedData(for: url)
            throw RequestFailure.invalidResponse
        }

        return image
    }

    private func removeCachedData(for url: URL) {
        memory.removeObject(forKey: url as NSURL)
    }

    private func data(for url: URL) async throws -> Data {
        try Task.checkCancellation()
        guard url.scheme == "https" || url.scheme == "http" else { throw RequestFailure.invalidResponse }
        if let data = memory.object(forKey: url as NSURL) { return data as Data }

        let task: Task<Data, Error>
        let ownsTask: Bool
        if let existing = pending[url] {
            task = existing
            ownsTask = false
        } else {
            let session = session
            task = Task.detached(priority: .utility) {
                let (data, response) = try await session.data(for: URLRequest(url: url, timeoutInterval: 20))
                guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                    throw RequestFailure.server
                }
                guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                      CGImageSourceGetStatus(source) == .statusComplete,
                      CGImageSourceGetCount(source) > 0 else { throw RequestFailure.invalidResponse }
                return data
            }
            pending[url] = task
            ownsTask = true
        }
        // 탐색 화면의 작업이 취소되어도 상세 화면이 기다리는 공통 다운로드는 유지합니다.
        defer { if ownsTask { pending[url] = nil } }
        let data = try await task.value
        if data.count <= memoryLimit {
            memory.setObject(data as NSData, forKey: url as NSURL, cost: data.count)
        }
        try Task.checkCancellation()
        return data
    }
}
