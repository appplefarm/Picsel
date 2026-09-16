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
        
        // 대한민국 전체를 대략적으로 포함하는 범위를 주어 국내 결과를 우선적으로 검색하도록 바이어스(bias) 설정
        let koreaCenter = CLLocationCoordinate2D(latitude: 36.5, longitude: 127.5)
        let koreaSpan = MKCoordinateSpan(latitudeDelta: 6.0, longitudeDelta: 6.0)
        self.completer.region = MKCoordinateRegion(center: koreaCenter, span: koreaSpan)
    }
    
    func selectLocation(completion: MKLocalSearchCompletion) async -> (CLLocation, String)? {
        isSearching = true
        defer { isSearching = false }
        
        let searchRequest = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: searchRequest)
        
        do {
            let response = try await search.start()
            if let mapItem = response.mapItems.first {
                // 국내 장소만 선택 가능하도록 차단
                if mapItem.placemark.isoCountryCode != "KR" {
                    self.errorMessage = "국내 지역만 선택 가능합니다."
                    return nil
                }
                
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
