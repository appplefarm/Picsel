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
    let body: TourBody
}

struct TourHeader: Decodable {
    let resultCode: String
    let resultMsg: String
}

struct TourBody: Decodable {
    let items: TourItems
    let numOfRows: Int
    let pageNo: Int
    let totalCount: Int
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
