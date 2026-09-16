//
//  TourResponse.swift
//  Picsel
//

import Foundation

struct TourRoot: Decodable {
    let response: TourResponse
}

struct TourResponse: Decodable {
    let header: TourHeader
    let body: TourBody?
}

struct TourHeader: Decodable {
    let resultCode: String
    let resultMsg: String
}

struct TourBody: Decodable {
    let items: TourItems?
    let numOfRows: Int
    let pageNo: Int
    let totalCount: Int

    private enum CodingKeys: String, CodingKey { case items, numOfRows, pageNo, totalCount }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        totalCount = try container.decode(Int.self, forKey: .totalCount)
        numOfRows = try container.decode(Int.self, forKey: .numOfRows)
        pageNo = try container.decode(Int.self, forKey: .pageNo)
        // TourAPI는 정상적인 빈 결과에서 items를 객체 대신 ""로 돌려주기도 합니다.
        items = totalCount == 0 ? nil : try container.decode(TourItems.self, forKey: .items)
    }
}

struct TourItems: Decodable {
    let item: [TourItem]?
}

struct TourItem: Decodable {
    let title: String
    let firstimage: String?
    let addr1: String?
    let mapx: String?
    let mapy: String?
    let contentid: String
}
