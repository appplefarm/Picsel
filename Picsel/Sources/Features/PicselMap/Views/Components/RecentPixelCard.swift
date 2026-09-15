//
//  RecentPixelCard.swift
//  Picsel
//
//  Created by Jonghyeon Lee on 9/8/26.
//

import SwiftUI

struct RecentPixelCard: View {
    let snapshot: TripRecordSnapshot

    var body: some View {
        TripListRow(
            title: snapshot.title,
            travelDate: snapshot.travelDate,
            photoURL: snapshot.destinationPhotoURL,
            fallbackPhotoData: snapshot.representativePhotoData
        )
    }
}
