//
//  TourPhotoResponse.swift
//  Picsel
//
//  Created by 김나영 on 9/1/26.
//


import Foundation

// 공공데이터포털 JSON은 보통 최상단에 "response" 객체로 한 번 감싸져 있음
struct TourPhotoRoot: Decodable {
    let response: TourPhotoResponse
}

struct TourPhotoResponse: Decodable {
    let header: TourPhotoHeader
    let body: TourPhotoBody
}

struct TourPhotoHeader: Decodable {
    let resultCode: String
    let resultMsg: String
}

struct TourPhotoBody: Decodable {
    let items: TourPhotoItems
    let numOfRows: Int
    let pageNo: Int
    let totalCount: Int
}

struct TourPhotoItems: Decodable {
    // 결과가 1개일 때를 대비해 빈 배열을 기본값으로 처리할 수 있게 옵셔널로 처리
    let item: [TourPhotoItem]?
}

struct TourPhotoItem: Decodable {
    let galTitle: String
    let galWebImageUrl: String
    let galPhotographyLocation: String?
    let galContentId: String
}
