import Foundation
import MapKit
import Observation

@Observable
final class ManualLocationSearchViewModel: NSObject {
    var searchQuery = "" {
        didSet {
            completer.queryFragment = searchQuery
        }
    }
    
    private(set) var searchResults: [MKLocalSearchCompletion] = []
    private(set) var isSearching = false
    var errorMessage: String?
    
    private let completer: MKLocalSearchCompleter
    
    override init() {
        self.completer = MKLocalSearchCompleter()
        super.init()
        self.completer.delegate = self
        // 장소와 주소 모두 검색할 수 있도록 결과 타입 설정
        self.completer.resultTypes = [.address, .pointOfInterest]
    }
    
    func selectLocation(completion: MKLocalSearchCompletion) async -> (CLLocation, String)? {
        isSearching = true
        defer { isSearching = false }
        
        let searchRequest = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: searchRequest)
        
        do {
            let response = try await search.start()
            if let mapItem = response.mapItems.first {
                let name = mapItem.name ?? completion.title
                let location = mapItem.placemark.location ?? CLLocation(
                    latitude: mapItem.placemark.coordinate.latitude,
                    longitude: mapItem.placemark.coordinate.longitude
                )
                return (location, name)
            }
        } catch {
            self.errorMessage = "위치 정보를 가져오는데 실패했습니다: \(error.localizedDescription)"
        }
        return nil
    }
}

extension ManualLocationSearchViewModel: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        self.searchResults = completer.results
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        // 사용자가 타이핑 중 발생하는 취소 에러 등은 무시
        if let error = error as NSError?, error.code == MKError.directionsNotFound.rawValue { return }
        self.errorMessage = error.localizedDescription
    }
}
