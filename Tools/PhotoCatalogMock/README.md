# 포항 사진 카탈로그 목업 (#38 · #31 일부)

목업 연결 작업은 [#38](https://github.com/appplefarm/Picsel/issues/38)에서 관리한다.
기존 #31의 위치·반경 검색 전체 범위를 완료하거나 닫는 작업은 아니다.

## 테스트 범위

실제 서버 구축 전에 `서버 역할 → 응답 디코딩 → 기존 모델 변환 → 사진 탐색 → 목적지 확정`을 검증한다.
CloudKit에 읽기/쓰기를 수행하거나 실제 HTTP 서버를 띄우지는 않는다. 거리 필터·랜덤 추출·여행 저장은 담당 작업에서 연결한다.

```
HomeView
  PhotoDestinationServiceFactory
    CatalogPhotoDestinationService
      PhotoCatalogClient
        BundledPhotoCatalogClient → pohang_photo_catalog.json (20개)
      PhotoCatalogResponse → PhotoDestination (최대 10개)
    PhotoExploreViewModel → SpatialPhotoCanvas → DestinationDetailView
      유효한 위치: HomeView에서 RouteStop 생성
      미검증/잘못된 위치: 사진 열람 가능, 목적지 확정 차단
```

`PlaceDTO`, `Trip`, `RouteStop`, `TripPhoto`, `UserPixel`의 필드와 저장 구조는 변경하지 않았다.
`PhotoDestination`에는 필드 변경 없이 좌표 유효성 계산 속성만 추가했다.

## 실행

- Xcode **Debug 실행 기본값**은 포항 목업이다. 홈의 기존 "사진으로 목적지 고르기"로 진입한다.
- JSON에는 20개가 있으며 화면은 기존 10개 배치를 유지한다. 응답 순서대로 앞의 10개를 표시하므로 재진입 시 같고, 내연산도 포함된다.
- 화면 위에 **포항 목업 · 위치·반경 필터 미적용**을 표시한다. 홈의 위치/반경을 적용한 결과가 아니다.
- `PhotoCatalogPreview.swift`의 **포항 목업 · 원본 응답 20개** Preview에서는 모든 응답을 목록으로 확인하고 각 사진의 상세를 열 수 있다.
- JSON 응답에는 API 키나 네트워크가 필요 없다. 사진 파일은 기존 HTTPS URL에서 읽으므로 인터넷이 필요하다.
- 앱 시작의 Google Maps 키와 다음 경유지 화면의 TourAPI 키는 기존과 동일하게 필요하다. 이 작업은 해당 설정을 변경하지 않는다.

Xcode → Scheme → Run → Arguments → Environment Variables:

| 이름 | 값 | 동작 |
| --- | --- | --- |
| `PICSEL_PHOTO_SOURCE` | `pohang` 또는 미설정 | 350ms 후 20개 목업 응답, 앞의 10개 표시 |
| `PICSEL_PHOTO_SOURCE` | `empty` | 빈 목록 화면 |
| `PICSEL_PHOTO_SOURCE` | `failure` | 네트워크 오류 화면 및 재시도 버튼 (계속 실패하는 시나리오) |
| `PICSEL_PHOTO_SOURCE` | `tourAPI` | 기존 실제 TourAPI 사진 조회 |

환경변수 변경 후 앱을 다시 실행한다. `Release`는 목업 구현을 컴파일하지 않고 기존 TourAPI를 사용한다.
JSON 리소스 자체는 현재 번들에 포함된다. Debug 경로로만 읽으며 배포 전 포함 정책은 별도 정리할 수 있다.
실제 TourAPI 사진은 위치 보강 전까지 열람만 가능하며 경로로 확정할 수 없다. 홈의 범용 이가리 좌표 대체 경로는 제거했다.

## 원본과 검증용 데이터

- 원본: `pohang_highres_photos_20_checkbox_fixed.xlsx`, **포항 20장** 시트, A1:Z21
- SHA-256: `749def2c006dd7860ff8a113a1c3eb1319ff439f28c61d5b39d1ad55221628b4`
- 좌표는 사용자가 수정한 **K/L 열**을 읽었다. 이전 기준 좌표 R/S는 사용하지 않았다.
- 최종 선택 Y와 최종 보류 Z를 읽어 `locationConfirmed`에 반영했다. 중간 체크박스 P/Q는 사용하지 않았다.
- 20개 모두 포함: 위치 확인 19개 + 내연산(`3543624`) 검증용 1개.
- 내연산의 원본 좌표는 JSON에 보존한다. `locationConfirmed: false`이면 모델 변환 시 좌표를 nil로 전달한다. 사진은 보이되 경로 확정은 막힌다.
- 이 데이터는 앱 동작 검증용이며 새로 좌표를 지리적으로 검증한 결과가 아니다. `locationConfirmed`는 시트의 사용자 검토 상태다.
- 숫자형 사진 ID도 문자열로 보존한다. 같은 장소의 서로 다른 사진도 별개의 사진 레코드다.
- `sourceRegionCode: "47"`는 원본의 시도 코드다. 시군구/지도 타일 코드로 해석하지 않는다. 미확정 `regionCode`는 모두 null이며 이번 목업만으로 픽셀 해금까지 완성되지 않는다.
- 관광사진 출처는 한국관광공사이며 파일 URL을 그대로 보존했다. 20개 전체가 공모전 수상작인지 이 작업에서 새로 검증한 것은 아니므로 화면은 일반적인 "관광사진"으로 표기한다.

## 서버 연결 지점

`PhotoCatalogClient.fetchCatalog()`가 사진 API 정보와 직접 보강한 장소 정보를 합친 `PhotoCatalogResponse`를 반환한다.
실제 서버 담당자는 CloudKit 레코드 또는 HTTP JSON 응답을 이 타입으로 변환하는 클라이언트를 구현하고, factory의 주입 부분만 교체하면 된다.
현재 규격은 서버 담당자와 합의 전인 임시 규격이며, 서버로 ID를 보내는 개별 조회나 사용자 데이터 저장 API를 구현한 것은 아니다.

- 서버 전용 값: `source`, `photoID`, `photoTitle`, `photoURL`, `thumbnailURL`, `placeName`, `address`, `latitude`, `longitude`, `locationConfirmed`, `sourceRegionCode`, `regionCode`, `shootingMonth`
- 앱 내부 사진 ID는 `source:photoID`. 원본 ID를 조회할 때는 응답의 `photoID`를 사용한다.
- `shootingMonth`는 원본 문자열을 유지한다. `202200`은 월 정보가 없는 원본 값이며 0월 날짜로 변환하지 않는다.
- URL/ID 중복·지원하지 않는 스키마는 오류, 빈 응답은 빈 결과, 좌표 문제는 해당 사진의 확정 제한으로 구분한다.
- 거리 필터 담당자는 전체 응답에서 후보를 필터링한 뒤 최대 10개를 선택하도록 어댑터를 확장한다. 이번 `prefix(limit)`는 목업의 결정적 순서 검증용이다.
- 좌표가 확인된 사진은 기존 공용 `PlaceDTO`로 변환할 수 있다. 주소만 없는 경우에도 유효한 좌표로 `RouteStop`은 생성할 수 있다.

### 서버 전환 시 정리

1. 실제 서버 Client가 `PhotoCatalogClient`를 구현하도록 하고, 서버 데이터를 현재 응답 타입에 매핑한다. 서버 담당자와 응답 규격을 먼저 합의한다.
2. `PhotoDestinationServiceFactory`에서 실제 Client를 주입한다. 목업을 완전히 제거한다면 `PICSEL_PHOTO_SOURCE` 분기와 목업 안내 문구도 정리한다.
3. 목업 전용 `BundledPhotoCatalogClient.swift`, `PhotoCatalogPreview.swift`, `Resources/Mocks/pohang_photo_catalog.json`을 제거한다. JSON은 현재 Release 번들에도 포함되므로 소스만이 아니라 빌드 산출물에서도 제거 여부를 확인한다.
4. 응답 인터페이스·변환/검증 서비스·ViewModel·공용 모델은 유지한다. 다른 데이터로도 쓰는 일반 디버깅 진입점은 일괄 삭제하지 않는다.
5. `Tools/PhotoCatalogMock`의 포항 전용 데이터 검사는 교체하되 중복 ID·좌표 오류·로딩 상태 테스트는 서버 전환 후에도 유지한다.

공용 `RouteStop`은 현재 `placeId`를 인자로 받지만 저장하지 않으며 사진 URL도 별도로 전달한다.
원본 사진 ID의 영구 보존과 여행 저장/복원은 공용 모델 담당자와 협의할 후속 작업이고 이번 목업 구현에 포함하지 않는다.

## 회귀 테스트

macOS + Xcode에서 실제 앱의 모델·서비스·ViewModel을 컴파일해 실행한다. 임의 복제 모델을 사용하지 않는다.

```sh
xcrun swiftc -swift-version 5 -default-isolation MainActor -parse-as-library -D DEBUG \
  Picsel/Sources/Models/StaticModels.swift \
  Picsel/Sources/Features/PhotoExplore/Models/PhotoDestination.swift \
  Picsel/Sources/Features/PhotoExplore/Models/SpatialPlaceItem.swift \
  Picsel/Sources/Features/PhotoExplore/Services/PhotoDestinationService.swift \
  Picsel/Sources/Features/PhotoExplore/Services/PhotoCatalogClient.swift \
  Picsel/Sources/Features/PhotoExplore/Services/CatalogPhotoDestinationService.swift \
  Picsel/Sources/Debugging/PhotoExplore/BundledPhotoCatalogClient.swift \
  Picsel/Sources/Features/PhotoExplore/ViewModels/PhotoExploreViewModel.swift \
  Tools/PhotoCatalogMock/validate_photo_catalog.swift \
  -o /tmp/validate-photo-catalog
/tmp/validate-photo-catalog /빌드경로/Picsel.app
```

20개 디코딩, ID·수정 좌표 보존, 표시 개수, 19개 위치 확정, 내연산 포함/확정 차단, nil·범위 오류 좌표, 주소 누락,
중복 ID·잘못된 URL·스키마 오류, 로딩 결과·빈 결과·실패·재시도·취소를 검사한다.

### 2026-09-10 검증 결과

- 위 CLI 회귀 검사 26개 통과. 빌드된 Debug 앱 번들의 실제 JSON을 사용했다.
- Xcode 26.6, iOS Simulator 대상 Debug/Release 빌드 성공. 기존 Home/RouteConfirmation/SDK 경고는 별도 사항이다.
- 공용 Models 디렉토리와 기존 미커밋 설정/History 이동은 변경하지 않았다.
- 새 앱의 시뮬레이터 UI 조작 및 실제 기기 실행은 아직 검증하지 않았다. 실행 중 시뮬레이터가 종료되어 UI 검증은 보류했다.
