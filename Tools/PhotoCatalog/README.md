# 포항 번들 카탈로그 — 1차 출시 공급 계층 (#52)

서버 도입 전에도 같은 모델과 화면 흐름을 사용하도록 장소 카탈로그를 앱에 포함한다.
기존 목업 작업은 #38, 위치·반경 검색은 별도 #31에서 관리한다.

## 기본 동작

- Debug와 Release 모두 `CatalogPhotoDestinationService(client: BundledPhotoCatalogClient())`를 사용한다.
- `Resources/PhotoCatalog/pohang_photo_catalog.json`의 사용자 검토 완료 레코드는 **19개**다. 기본 로더에는 지연이나 네트워크 요청이 없다.
- 서비스는 확정 가능한 좌표가 있는 장소만 남긴 뒤 응답 순서대로 최대 10개를 전달한다. 10개 미만도 허용하며, 모두 부적합하면 빈 결과다.
- 공용 `PlaceDTO`, `Trip`, `RouteStop`, `TripPhoto`, `UserPixel`은 변경하지 않는다. 사진 ID와 원본 좌표도 유지한다.
- 사진 탐색과 홈 안내에는 포항 카탈로그임을 표시한다. 거리 필터·랜덤 추천은 이번 작업에 포함하지 않는다. 홈 반경 컨트롤은 아직 후보 필터에 연결되지 않았으며 후속 출시 점검 대상이다.
- 사진 이미지 자체는 HTTPS URL에서 읽는다. Google Maps 초기화, 경유지 TourAPI, 경로 API 등 기존 네트워크·API 키 의존성은 남는다. 오프라인 앱으로 설명하면 안 된다.
- 이 작업만으로 출시 준비 완료를 뜻하지 않는다. 실제 장소·사진 이용 권한 검증, 개인정보·탈퇴, 권한 거절 처리, TestFlight 종단 테스트는 별도다.

## Debug 검증

실패·빈 결과·지연 및 미검증 사진은 `Debugging/PhotoExplore/DebugPhotoCatalogClient.swift`에만 존재한다.
해당 구현과 미검증 사진 상수는 `#if DEBUG`로 Release에서 제외한다.

Xcode → Scheme → Run → Arguments → Environment Variables:

| PICSEL_PHOTO_SOURCE | 동작 |
| --- | --- |
| 미설정 / `pohang` | Release와 같은 19개 카탈로그에서 최대 10개 선택 |
| `empty` | 빈 응답 화면 |
| `failure` | 오류 화면·재시도 |
| `slow` | 2초 지연 후 정상 응답 |
| `tourAPI` | 기존 실제 사진 API를 시험. 좌표가 없어 목적지 확정 불가 |

Release는 이 환경변수를 무시하며 항상 번들 카탈로그를 사용한다.
`PhotoCatalogPreview.swift`의 **포항 · 미검증 포함 응답 20개** 프리뷰는 19개와 내연산을 원본 순서로 합쳐 보여 준다. 내연산 상세의 확정 버튼은 비활성화된다.
**포항 · 출시 카탈로그 탐색** 프리뷰는 실제 선택 가능한 목록을 보여 준다.

## 원본과 검증 데이터

- 원본: `pohang_highres_photos_20_checkbox_fixed.xlsx`, 포항 20장 시트 A1:Z21.
- 원본 SHA-256: `749def2c006dd7860ff8a113a1c3eb1319ff439f28c61d5b39d1ad55221628b4`.
- 사용자가 수정한 K/L 좌표와 Y/Z 최종 선택·보류 상태를 그대로 유지한다. 새 지리 검증을 수행한 것은 아니다.
- 내연산 `3543624`는 출시 JSON에서 제외하고 Debug 상수로 이동했다. 원본 URL, 제목, 주소, 월, 좌표, 미검증 상태를 모두 보존한다.
- `sourceRegionCode: "47"`는 시도 코드이며 픽셀 시군구 코드가 아니다. 미확정 `regionCode`는 null을 유지한다.
- `shootingMonth`는 원본 문자열이다. `202200`은 월 정보가 없는 원본 값이며 0월 날짜로 해석하지 않는다.
- 숫자형 photoID도 문자열로 유지한다. 서로 다른 사진이 같은 장소를 찍었어도 별개의 사진 ID다.
- 전체 자료의 수상작 여부와 사진 이용 조건은 이번 작업에서 새로 검증하지 않았다. 화면에는 일반적인 관광사진으로 표시한다.

## 서버로 교체하기

1. 서버 담당자와 `PhotoCatalogResponse`의 `schemaVersion`, 필드, 사진 ID, 좌표 기준을 합의한다. 현재 규격은 HTTP/CloudKit 양쪽에서 매핑할 수 있는 앱의 입력 규격이다.
2. `PhotoCatalogClient.fetchCatalog()`를 구현하는 서버 Client를 만든다. 서버별 오류·인증·캐시·취소는 그 구현에서 처리한다.
3. `PhotoDestinationServiceFactory.make()`의 기본 Client를 교체한다. 변환·검증 서비스와 화면·공용 모델은 유지한다.
4. 서버 장애 시 번들 fallback을 유지할지는 별도로 결정한다. 필요 없으면 번들 Client와 JSON만 제거한다.
5. 포항 한정/반경 미적용 안내를 실제 서비스 범위에 맞춰 갱신하고 Debug/Release 회귀 검사를 다시 실행한다.

이 인터페이스는 사진/장소 **읽기 전용**이다. 사용자 기록 업로드·계정 동기화는 별도 기능이다.
현재 공용 `RouteStop`은 `placeId`를 인자로 받지만 저장하지 않으므로 원본 사진 ID 영구 보존은 모델 담당자와 별도로 협의해야 한다.

## 회귀 검사

macOS + Xcode에서 실제 앱 모델·서비스·ViewModel을 컴파일한다. 출력 바이너리는 JSON이 없는 임시 폴더에 둔다.

```sh
xcrun swiftc -swift-version 5 -default-isolation MainActor -parse-as-library -D DEBUG \
  Picsel/Sources/Models/StaticModels.swift \
  Picsel/Sources/Features/PhotoExplore/Models/PhotoDestination.swift \
  Picsel/Sources/Features/PhotoExplore/Models/SpatialPlaceItem.swift \
  Picsel/Sources/Features/PhotoExplore/Services/PhotoDestinationService.swift \
  Picsel/Sources/Features/PhotoExplore/Services/PhotoCatalogClient.swift \
  Picsel/Sources/Features/PhotoExplore/Services/BundledPhotoCatalogClient.swift \
  Picsel/Sources/Features/PhotoExplore/Services/CatalogPhotoDestinationService.swift \
  Picsel/Sources/Features/PhotoExplore/Services/TourAPIPhotoDestinationService.swift \
  Picsel/Sources/Features/PhotoExplore/Services/PhotoDestinationServiceFactory.swift \
  Picsel/Sources/Debugging/PhotoExplore/DebugPhotoCatalogClient.swift \
  Picsel/Sources/Features/PhotoExplore/ViewModels/PhotoExploreViewModel.swift \
  Tools/PhotoCatalog/validate_photo_catalog.swift \
  -o /tmp/validate-photo-catalog-debug
/tmp/validate-photo-catalog-debug /빌드경로/Picsel.app
```

Release 검사에서는 `-D DEBUG`를 빼고 `-O`를 추가한다. 출력 이름을 구분하고 Release 앱 번들을 입력한다.
19개 원본, ID/좌표 보존, 최대 10개, 모델 변환, 잘못된 좌표 제외, 잘못된 응답·리소스 누락·취소, ViewModel 상태, factory 기본값, Release의 Debug 환경변수 무시를 검사한다.
Debug에서는 원래의 20개 검증 응답과 내연산 확정 차단, 실패·빈 결과·지연 취소도 검사한다.
