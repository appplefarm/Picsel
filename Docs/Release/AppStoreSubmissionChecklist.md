# App Store 1차 출시 체크리스트

작성일: 2026-09-10 · 제출 마감: 2026-09-21
대상 커밋 기준: 현재 `main` 작업본

> 심사위원 관점에서 코드베이스를 훑고 정리한 문서입니다.
> 🔴 = 안 고치면 출시 불가 / 🟠 = 제출 필수 항목 / 🟡 = 리젝 확률을 낮추는 항목 / ⚪ = 확인 결과 문제 없음

---

## 0. 우선순위 요약

| # | 항목 | 등급 | 예상 시간 | 담당 |
|---|------|------|-----------|------|
| 1.1 | 앱 아이콘 알파 채널 제거 | 🔴 | 10분 | |
| 1.2 | 아이콘 다크/틴티드 파일 누락 | 🔴 | 20분 | |
| 1.3 | `PrivacyInfo.xcprivacy` 추가 | 🔴 | 10분 | |
| 1.4 | 앱 이름 중복 → 개명 | 🔴 | 30분 + 팀 논의 | |
| 2.1 | `support@example.com` placeholder 제거 | 🔴 | 10분 | |
| 2.2 | 회원탈퇴 버튼 미동작 | 🔴 | 1시간 | |
| 2.3 | 로그인 게이트 제거 | 🔴 | 30분 | |
| 2.4 | 지도 placeholder 뷰 노출 | 🔴 | 30분 | |
| 2.5 | 개인정보 처리방침 내용이 실제 동작과 불일치 | 🔴 | 1시간 | |
| 3.1 | 개인정보 처리방침 URL 호스팅 | 🟠 | 1시간 | |
| 3.2 | 지원(Support) URL 호스팅 | 🟠 | 30분 | |
| 3.3 | 스크린샷 (실제 화면) | 🟠 | 1시간 | |
| 3.4 | 심사 노트 작성 | 🟠 | 10분 | |
| 3.5 | Privacy Nutrition Label 작성 | 🟠 | 30분 | |
| 3.6 | 암호화 규정 선언 | 🟠 | 5분 | |
| 4.1 | 반경 슬라이더가 실제로 동작하게 | 🟡 | 2시간 | |
| 4.2 | iPad 지원 해제 | 🟡 | 5분 | |
| 4.3 | `fatalError` 2곳 제거 | 🟡 | 30분 | |
| 4.4 | 이미지 로딩 실패 처리 | 🟡 | 1시간 | |
| 4.5 | 최소 iOS 버전 재검토 | 🟡 | 10분 | |

---

## 1. 🔴 업로드 자체가 막히는 것 (Blocker)

여기 걸리면 **심사에 들어가지도 못하고** 업로드 단계에서 되돌아옵니다.

### 1.1 앱 아이콘에 알파 채널이 있음

**현재 상태**

```
Picsel/Resources/Assets.xcassets/AppIcon.appiconset/AppLogo.png
→ 1024×1024, PNG colorType 6 (RGBA, 알파 채널 있음)
```

App Store 아이콘은 **알파 채널이 있으면 안 됩니다.** 업로드하면 이 에러가 납니다.

```
ERROR ITMS-90717: "Invalid App Store Icon. The App Store Icon in the asset
catalog in 'Picsel.app' can't be transparent nor contain an alpha channel."
```

**해결**

- 디자인 툴에서 배경을 불투명하게 채워 재export (`app-icon.md`의 "배경 풀블리드, 투명 영역 없음" 규칙과 이미 일치하는 방향)
- 또는 터미널에서 즉시 변환:
  ```
  sips -s format png --deleteColorManagementProperties AppLogo.png --out AppLogo_noalpha.png
  ```
  변환 후 반드시 알파가 실제로 빠졌는지 재확인할 것 (sips만으로 안 빠지는 경우가 있음)
- 확인 방법: `sips -g hasAlpha AppLogo.png` → `hasAlpha: no` 여야 함

### 1.2 아이콘 다크/틴티드 변형 파일이 없음

**현재 상태**

`AppIcon.appiconset/Contents.json`은 3개 파일을 참조하는데 실제로는 1개만 있습니다.

| Contents.json 참조 | 실제 존재 |
|---|---|
| `AppLogo.png` (기본) | ✅ |
| `AppLogo 1.png` (dark) | ❌ 없음 |
| `AppLogo 2.png` (tinted) | ❌ 없음 |

빌드 시 에셋 카탈로그 경고가 뜨고, 다크모드/틴티드 모드에서 아이콘이 비정상 표시됩니다.

**해결 (둘 중 하나)**

- **A안 (빠름)**: `Contents.json`에서 dark / tinted 항목을 삭제하고 기본 아이콘 1개만 남기기. iOS가 자동으로 처리합니다
- **B안 (권장)**: `app-icon.md`에 이미 "그레이스케일(틴티드 모드) 테스트 통과"가 요구사항으로 있으니, 다크/틴티드 버전을 실제로 export해서 채우기

### 1.3 Privacy Manifest (`PrivacyInfo.xcprivacy`) 누락

**현재 상태** — 레포 전체에 `PrivacyInfo.xcprivacy` 파일이 없습니다.

그런데 앱은 `UserDefaults`를 사용합니다.

```
Picsel/PicselApp.swift:15        @AppStorage("isLoggedIn")
Picsel/Sources/App/AppRootView.swift:9,37,38,46,47   UserDefaults / @AppStorage
```

`UserDefaults`는 Apple이 지정한 **Required Reason API**입니다. 선언 없이 업로드하면 자동 검사에서 걸립니다.

```
ITMS-91053: Missing API declaration — Your app's code in the "Picsel" file
references one or more APIs that require reasons, including the following
API categories: NSPrivacyAccessedAPICategoryUserDefaults.
```

**해결 (10분)**

1. Xcode → File → New → File → **App Privacy** → `PrivacyInfo.xcprivacy` 생성, Picsel 타깃에 포함
2. `NSPrivacyAccessedAPITypes` 배열에 항목 추가
   - `NSPrivacyAccessedAPIType` = `NSPrivacyAccessedAPICategoryUserDefaults`
   - `NSPrivacyAccessedAPITypeReasons` = **`CA92.1`** (앱 자신의 데이터에만 접근하는 경우)
3. Google Maps SDK는 최신 버전이면 자체 매니페스트를 포함하므로, SPM 의존성 버전이 최신인지만 확인

### 1.4 앱 이름 "Picsel"이 이미 사용 중

**현재 상태** — App Store에 동일 이름 앱이 이미 존재합니다.

- 이름: **PICSEL: 포토부스 검색 & 네컷사진 보관**
- 개발자: surin chae
- 카테고리: **사진 및 비디오** (우리와 동일)
- 성격: 사진 + 지도 조합 (우리와 유사)

**왜 문제인가**

1. App Store Connect의 앱 이름은 스토어 전체에서 고유해야 합니다. "Picsel" 단독으로는 **예약 자체가 불가능**합니다
2. `"Picsel: 픽셀 여행지도"` 처럼 부제를 붙이면 문자열은 통과할 수 있지만, **Guideline 4.1 (Copycats)** 에 정면으로 걸립니다

   > "You cannot use another developer's icon, brand, or **product name** in your app's icon or name, without approval from the developer."

3. 여기에 **Guideline 2.3.7** 의 "Choose a unique app name" 도 겹칩니다

**추가 리스크**

- 같은 카테고리 · 같은 한국 시장 · 둘 다 사진+지도 앱 → 리뷰어가 혼동 가능성을 잡아낼 확률이 높음
- 심사를 통과해도 상대 개발자가 신고하면 **사후에 앱이 내려갑니다.** 공모전 심사 기간 중 앱이 스토어에서 사라지는 게 최악의 시나리오
- ASO: "Picsel" 검색 시 평점 5.0 · 리뷰 3개가 쌓인 기존 앱이 위에 노출됨

**개명 비용은 거의 0입니다**

바꾸지 않아도 되는 것:

| 항목 | 값 | 비고 |
|---|---|---|
| `PRODUCT_BUNDLE_IDENTIFIER` | `com.applefarm.picsel` | 사용자에게 안 보임. 그대로 유지 |
| Xcode 프로젝트명 / 타깃명 | `Picsel` | 그대로 유지. 건드리면 빌드 깨짐 |
| 앱 아이콘 | 픽셀경로 + 사진 심벌 | **워드마크가 아직 없어서 그대로 사용 가능** |

실제로 고칠 곳 — 4군데:

1. `Picsel.xcodeproj` 빌드 설정에 `INFOPLIST_KEY_CFBundleDisplayName` 추가 (홈 화면 표시명)
2. `Sources/Features/Onboarding/OnboardingView.swift:21` — `Text("Picsel")`
3. `Sources/Features/Setting/PrivacyPolicyView.swift` 4곳 — 어차피 §2.5에서 전면 재작성
4. `Sources/Features/PhotoExplore/Services/TourAPIPhotoDestinationService.swift:14` — `mobileApp: String = "Picsel"` (API 요청 파라미터, 사용자 비노출, 선택사항)

**이름 정하는 순서**

1. 후보를 **App Store Connect에서 직접 예약 시도** — 통과 여부가 즉시 나오는 유일하게 확실한 방법
2. App Store에서 후보명 검색 — 유사 앱 확인
3. [KIPRIS](https://www.kipris.or.kr)에서 상표 검색 — 등록 상표는 회피

> "픽셀" / "pic" 조합은 이미 포화 상태입니다. 앞서 후보였던 **"무명풍경"** 같은 한글 고유명사가 중복 확률이 낮고, "이름 없는 풍경을 사진으로 발견한다"는 컨셉과도 맞아 공모전 심사 설명에도 유리합니다. 픽셀맵 수집 요소는 부제에서 살리면 됩니다.

**공모전 제출 문서의 서비스명도 함께 맞출 것.** 스토어 이름과 제출서 이름이 다르면 심사위원이 혼란스러워합니다.

---

## 2. 🔴 심사 리젝이 확실시되는 것

### 2.1 placeholder 문자열이 사용자에게 그대로 노출됨

**현재 상태**

```swift
// Sources/Features/Setting/AppContact.swift:9
static let supportEmail = "support@example.com"
```

이 주소가 개인정보 처리방침 화면과 문의 알럿에 그대로 출력되고, 바로 아랫줄에 이 문장까지 사용자에게 보입니다.

```swift
// Sources/Features/Setting/PrivacyPolicyView.swift:71
"실제 문의 이메일 확정 전까지는 placeholder 주소로 관리합니다."
```

**Guideline 2.1 (App Completeness)** 은 placeholder 콘텐츠를 명시적으로 리젝합니다. 리뷰어가 설정 탭만 열면 바로 보이는 자리입니다.

**해결**

- 팀 공용 이메일 개설 후 `AppContact.supportEmail` 교체
- `PrivacyPolicyView.swift:71` 문장 **삭제**

### 2.2 회원탈퇴 버튼이 아무것도 하지 않음

**현재 상태**

```swift
// Sources/Features/Setting/SettingsView.swift:69
onWithdraw: handleWithdrawalPlaceholder   // ← onWithdraw가 아님

// Sources/Features/Setting/SettingsView.swift:312-313
// TODO: 회원탈퇴 정책과 데이터 삭제 범위가 확정되면 실제 탈퇴 로직을 연결합니다.
showWithdrawalSheet = false                // 시트만 닫힘

// Sources/Features/Setting/WithdrawalSheetView.swift:79
// TODO: 회원탈퇴 데이터 정책 확정 후 실제 삭제 로직을 연결합니다.
```

즉 **UI는 있는데 눌러도 아무 일도 일어나지 않습니다.** 리뷰어의 실제 테스트 동선이 *로그인 → 설정 → 회원탈퇴 → 정말 지워지는지 확인* 이라, 이건 계정 삭제 미비보다 오히려 인상이 나쁩니다 (허위 UI).

**해결** — §2.3에서 로그인을 제거하면 이 섹션 자체를 없애는 게 맞습니다. 로그인을 유지한다면:

- `SettingsView.swift:69`를 `onWithdraw`로 연결
- `AppRootView.withdrawAccount()`가 UserDefaults만 지우지 말고 **SwiftData의 `Trip` / `RouteStop` / `TripPhoto` / `UserPixel` 전부 삭제**까지 수행
- 탈퇴 시트에 "모든 여행 기록이 삭제되며 복구할 수 없습니다" 명시

### 2.3 로그인 게이트 — Guideline 5.1.1(v)

**현재 상태**

- `OnboardingView`에서 Sign in with Apple로만 앱 진입 가능 (`hasCompletedOnboarding` 게이트)
- 백엔드 없음. `appleUserIdentifier`를 `UserDefaults`에 저장하는 게 전부
- 데이터는 전부 로컬 SwiftData

**두 갈래로 걸립니다**

1. **계정 삭제 의무**
   > "If your app supports account creation, you must also offer account deletion within the app."

   로그인 화면이 있으면 리뷰어는 계정 생성이 있는 앱으로 봅니다. → §2.2 문제로 이어짐

2. **의미 없는 로그인 벽** (이쪽이 더 위험)
   > "If your app doesn't include significant account-based features, let people use it without a login."

   서버가 없어서 계정이 하는 일이 **아무것도 없습니다.** 동기화도, 공유도, 서버 저장도 없습니다. 이건 계정 삭제 미비보다 흔한 리젝 사유입니다

**중요: iCloud는 Apple 로그인이 필요 없습니다**

| | Sign in with Apple | iCloud / CloudKit |
|---|---|---|
| 용도 | **자체 서버**에 쓸 사용자 식별자 발급 | 기기의 iCloud 계정으로 데이터 동기화 |
| 앱 내 로그인 화면 | 필요 | **불필요** |
| 인증 주체 | 앱 | iOS 설정 > Apple 계정 (이미 로그인돼 있음) |

CloudKit Private Database는 사용자가 이미 기기에 로그인해둔 iCloud 계정을 그대로 씁니다. 앱이 할 일은 `CKContainer.default().accountStatus()` 확인뿐이고, SwiftData면 `ModelConfiguration(cloudKitDatabase: .automatic)` 한 줄입니다. **로그인 UI가 등장하지 않습니다.**

**게다가 현재 iCloud는 연결조차 안 되어 있습니다**

```
Picsel/Picsel.entitlements
  com.apple.developer.icloud-container-identifiers → <array/>   ← 비어 있음
  com.apple.developer.icloud-services              → <array/>   ← 비어 있음
```

`PicselApp.swift`의 `.modelContainer(for:)`도 `ModelConfiguration` 없이 호출되어 **로컬 전용 저장소**입니다.

**해결 — 권장: 로그인 게이트 제거 (30분)**

- `AppRootView`의 `hasCompletedOnboarding` 분기에서 `OnboardingView` 대신 바로 `MainTabView` 진입
- `OnboardingView`는 **파일을 지우지 말고 남겨둘 것.** 2차에서 재사용
- `Picsel.entitlements`에서 `com.apple.developer.applesignin` 제거 (안 쓰는 entitlement가 남아 있으면 심사에서 지적될 수 있음)
- `SettingsView`의 `accountSection` 제거, 또는 "계정 관리" → **"데이터 관리 > 모든 기록 삭제"** 로 변경

**2차 출시 때 갑자기 넣으면 리젝되나? → 아니요**

업데이트로 기능이 늘어나는 건 리젝 사유가 아닙니다. 심사는 매 제출 시점의 상태만 봅니다.

| 2차 시나리오 | 계정 삭제 의무 |
|---|---|
| iCloud / CloudKit만 추가 | **안 생김** (로그인 화면이 없으므로). Privacy Label에 iCloud 항목만 갱신 |
| 자체 백엔드 + 계정 추가 | 생김 → 로그인 + 인앱 탈퇴 + SIWA revoke API가 세트로 필요 |

> ⚠️ 서버를 붙이면서 Sign in with Apple을 쓰면 [TN3194](https://developer.apple.com/documentation/technotes/tn3194-handling-account-deletions-and-revoking-tokens-for-sign-in-with-apple)의 **revoke 토큰 API 호출이 의무**가 됩니다. `client_secret` JWT 서명이 필요해 서버 없이는 불가능합니다. "서버만 먼저 붙이고 탈퇴 API는 나중에" 는 그 시점부터 리젝 사유가 됩니다.

### 2.4 "준비 중" placeholder 지도가 사용자에게 노출됨

**현재 상태**

```swift
// Sources/Features/RouteConfirmation/Views/RouteConfirmationView.swift:156
if viewModel.mapMarkers.isEmpty {
    RouteMapPlaceholderView()
}

// Sources/Features/RouteConfirmation/Views/Components/RouteMapPlaceholderView.swift:16
Text("지도 사진 + 경로 (네비게이션처럼)")
    .accessibilityLabel("경로 지도 준비 중")
```

좌표가 비면 **"지도 사진 + 경로 (네비게이션처럼)"** 이라는 개발용 문구가 그대로 화면에 뜹니다. 전형적인 **Guideline 2.1** 리젝 사유입니다.

**해결**

- 문구를 사용자용으로 교체: "경로를 불러오지 못했어요. 잠시 후 다시 시도해 주세요." + 재시도 버튼
- 또는 `mapMarkers`가 빌 수 없도록 보장하고 이 분기 자체를 제거
- 번들 카탈로그의 19장에는 좌표가 모두 들어있으므로, 네이버 길찾기 API 실패 시에도 마커는 뜨도록 방어할 것

### 2.5 개인정보 처리방침 내용이 실제 동작과 불일치

**실제 동작과 다른 개인정보 고지는 Guideline 5.1.1 리젝 사유입니다.**

`Sources/Features/Setting/PrivacyPolicyView.swift` 수정 필요 항목:

| 현재 문구 | 문제 |
|---|---|
| "CloudKit Private Database에 저장될 수 있습니다" (L28) | CloudKit 미연결. entitlement 배열이 비어 있음 |
| "CloudKit Public Database를 통해 제공될 수 있습니다" (L54) | 공용 DB 없음 |
| "Apple 로그인 ... `credential.user`를 사용합니다" (L20) | 로그인 제거 시 섹션 통째로 삭제 |
| "삭제 흐름을 **제공할 예정입니다**" (L63) | 처리방침에 "예정"은 쓰면 안 됨 |
| "placeholder 주소로 관리합니다" (L71) | §2.1 참조. 삭제 |

**빠진 것 — 제3자 서비스 고지**

다음으로 통신이 나가는데 처리방침에 명시가 없습니다.

- Google Maps SDK (`GMSServices`)
- 네이버 길찾기 API (`maps.apigw.ntruss.com`)
- 한국관광공사 TourAPI (`apis.data.go.kr`)
- 관광사진 이미지 CDN (`tong.visitkorea.or.kr`)

---

## 3. 🟠 제출에 반드시 필요한 것

### 3.1 개인정보 처리방침 URL — 필수

App Store Connect의 **앱 정보 > 개인정보 처리방침 URL**은 모든 앱의 필수 입력란입니다. 계정이 없든, 데이터를 안 모으든 예외가 없습니다.

**Guideline 5.1.1(i)** 은 두 곳 모두를 요구합니다.

> "All apps must include a link to their privacy policy in the App Store Connect metadata field **and** within the app in an easily accessible manner."

- 앱 안쪽: `PrivacyPolicyView`가 이미 존재 → ✅ (단 §2.5의 내용 수정 필요)
- 외부 URL: **미준비** → 만들어야 함

**조건**

- 로그인 없이 열려야 함 (구글 로그인 걸린 문서 ❌)
- 심사 후에도 계속 살아있어야 함
- GitHub Pages (`docs/privacy.md`) 또는 Notion 공개 페이지 권장. 이미 레포가 있으니 GitHub Pages가 가장 빠름

### 3.2 지원(Support) URL — 필수

개인정보 처리방침 URL과 **별개의 필수 입력란**입니다. 같은 사이트에 `support.md` 한 장 더 만들면 됩니다 (문의 이메일 + 간단한 FAQ).

### 3.3 스크린샷

- **반드시 실제 앱 화면**으로. 픽셀맵이 전국 알록달록하게 채워진 목업 스크린샷을 올리면 **Guideline 2.3.3** 리젝입니다
- 포항 한 칸만 채워진 실제 화면을 쓸 것
- 필수 사이즈: 6.9인치(또는 6.7인치) iPhone 1세트. §4.2에서 iPad를 끄면 iPad 스크린샷은 불필요

### 3.4 App Store 설명 문구

- **첫 문단에 콘텐츠 범위 명시**: "현재 경북 포항 지역의 관광사진으로 서비스하며, 순차적으로 지역을 확대할 예정입니다"
- 앱 이름·부제에 "전국" 류 단어 넣지 말 것
- 설명과 앱이 다른 것이 **Guideline 2.3.1 / 2.3.3** 의 핵심 리젝 사유입니다

### 3.5 심사 노트 (Review Notes)

부록 A의 텍스트를 App Store Connect > 앱 심사 정보 > 메모에 붙여넣으세요.

### 3.6 Privacy Nutrition Label (앱 개인정보 보호 설문)

현재 수집 항목 기준:

| 항목 | 목적 | 기기 외 전송 |
|---|---|---|
| 위치 (대략적/정확한) | 앱 기능 | ❌ 안 함 |
| 사용자 사진 | 앱 기능 | ❌ 안 함 (로컬 전용) |

로그인을 제거하면 이메일/이름 항목이 사라져 설문이 훨씬 단순해집니다.

### 3.7 암호화 규정 준수 선언

`Configs/Info.plist`에 `ITSAppUsesNonExemptEncryption` 키가 없습니다. 리젝 사유는 아니지만 **업로드할 때마다 질문을 받게 됩니다.**

HTTPS만 사용하므로 아래 한 줄을 추가하면 이후 자동 통과됩니다.

```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

### 3.8 기타 App Store Connect 입력 항목

- [ ] 카테고리 (여행 또는 사진 및 비디오)
- [ ] 연령 등급 설문
- [ ] 저작권 표기
- [ ] 판매 지역 (대한민국)
- [ ] 빌드 업로드 후 빌드 선택
- [ ] `MARKETING_VERSION = 1.0` / `CURRENT_PROJECT_VERSION = 1` 확인

---

## 4. 🟡 리젝 확률을 낮추는 것

### 4.1 반경 슬라이더가 실제로는 아무 효과가 없음

**현재 상태**

```swift
// Sources/Features/Home/HomeViewModel.swift:19
private(set) var maximumRadiusKm = 710.0   // 한반도 4극점 기준

// Sources/Features/Home/HomeViewModel.swift:11-16
let mapCenterCoordinate = CLLocationCoordinate2D(   // 포항공대 고정
    latitude: 36.01215824592938,
    longitude: 129.32234943929984
)
```

번들 카탈로그(`Resources/PhotoCatalog/pohang_photo_catalog.json`)에는 **포항 사진 19장뿐**입니다. 슬라이더를 710km까지 밀어도, 32km로 줄여도 결과가 동일합니다.

**Guideline 2.1 (App Completeness)** 은 "동작하는 것처럼 보이지만 실제로는 아무 효과가 없는 컨트롤"을 미완성으로 봅니다. 지금은 **컨트롤이 거짓말을 하는 상태**입니다.

팀이 `PhotoDestinationServiceFactory.sourceNotice`에 "포항 관광사진 · 설정 반경과 무관하게 제공됩니다"를 넣고 `PhotoExploreView:63`에서 표시하는 건 좋은 방어이지만, 슬라이더는 크고 캡션은 작아서 리뷰어가 못 보고 넘어갈 수 있습니다.

**해결**

**Step 1 — 슬라이더 최대치를 실제 데이터 범위로**

- `HomeViewModel.updateMaximumRadius(from:)`를 4극점이 아니라 **번들 카탈로그 사진들의 실제 최대 거리** 기준으로 변경 (포항공대 중심 기준 대략 30km 내외)
- `KoreaExtremePoint` enum은 **지우지 말 것.** 2차에서 전국 데이터 붙일 때 그대로 살아납니다
- 새 메서드 이름 제안: `updateMaximumRadius(fromCatalog:)`

**Step 2 — 슬라이더가 실제로 필터링하게**

- 카탈로그 사진마다 `latitude` / `longitude`가 이미 들어있으므로 중심점 거리로 필터만 걸면 됨
- 포항 안에서도 5km / 15km / 30km면 결과 개수가 실제로 달라짐
- `CatalogPhotoDestinationService`에 반경 파라미터 경로 추가 → `HomeView:147` 부근에서 `currentRadiusMeters` 전달

**Step 3 — 안내 문구 수정**

`sourceNotice`를 "설정 반경과 무관하게" → **"현재 포항 지역 관광사진을 제공합니다"** 로 변경

### 4.2 iPad 지원이 켜져 있음

**현재 상태**

```
Picsel.xcodeproj/project.pbxproj:321,362
TARGETED_DEVICE_FAMILY = "1,2";   // 1=iPhone, 2=iPad
```

**iPad 지원을 선언하면 리뷰어가 iPad에서도 테스트합니다.** iPhone 전용으로 디자인된 UI가 iPad에서 깨지면 **Guideline 2.1 / 4.0** 리젝입니다. iPad 스크린샷도 별도로 요구됩니다.

**해결** — `TARGETED_DEVICE_FAMILY = "1"` 로 변경 (5분). 2차에서 iPad 대응을 제대로 한 뒤 다시 켜면 됩니다.

### 4.3 `fatalError` 2곳 — 실행 즉시 크래시 위험

```swift
// Picsel/PicselApp.swift:25
fatalError("GoogleMapsAPIKey를 불러오지 못했습니다.")

// Sources/Features/Planning/API/TourAPIManager.swift:14
fatalError("TOUR_API_SERVICE_KEY_ENTRY를 찾을 수 없음")
```

`Configs/Secrets.xcconfig`는 `.gitignore`에 있으므로(`.gitignore:67`), **빌드 머신에 이 파일이 없으면 키가 비어 앱이 즉시 죽습니다.** 리뷰어 기기에서 실행 즉시 크래시 = **Guideline 2.1 리젝 1순위**입니다.

**해결**

- Release 스킴으로 Archive → 실기기 설치 → **첫 실행이 되는지 반드시 확인**
- `fatalError` 대신 사용자에게 보이는 에러 화면으로 대체하는 것을 권장 (지도 없이도 앱이 죽지는 않게)
- 최소한 Archive 빌드에 키가 실제로 주입됐는지 확인

### 4.4 이미지 로딩 실패 처리

`Sources/Features/PhotoExplore/Services/RemotePhotoImageLoader.swift`가 `tong.visitkorea.or.kr`에서 이미지를 실시간으로 받아옵니다. 리뷰어 네트워크에서 이 서버가 느리거나 막히면 **사진이 전부 빈 화면**으로 뜨고, 그건 Guideline 2.1입니다.

**해결**

- 기내모드로 실행해서 플레이스홀더가 제대로 뜨는지 확인
- 여유가 되면 19장 정도는 썸네일을 앱에 번들로 포함 (JSON이 10KB에 불과하므로 용량 부담 적음). 심사 통과 확률이 눈에 띄게 올라감

### 4.5 최소 iOS 버전 재검토

```
IPHONEOS_DEPLOYMENT_TARGET = 26.0   (app 타깃, L305/L346)
IPHONEOS_DEPLOYMENT_TARGET = 17.0   (다른 설정, L216/L274)
```

앱 타깃이 **iOS 26 이상**입니다. 설정이 서로 불일치하는 것도 정리가 필요합니다.

리젝 사유는 아니지만 설치 가능 기기가 크게 줄어듭니다. **공모전 심사위원이 구형 기기를 쓰면 설치조차 못 합니다.** iOS 26 전용 API를 실제로 쓰고 있는지 확인하고, 아니라면 낮추는 것을 권장합니다.

### 4.6 코드 내 TODO 정리

사용자에게 보이지 않는 TODO는 리젝과 무관하지만, 아래 두 개는 화면에 영향이 있어 확인이 필요합니다.

```swift
// Sources/Features/History/PixelDetailView.swift:21,33
static let mockStops: [RouteStopDisplay] = [ "호미곶 해맞이광장", ... ]
var stops: [RouteStopDisplay] = RouteStopDisplay.mockStops
```

`PicselMapView:152`에서는 실제 `record.stops`를 넘기므로 정상 동작하지만, **다른 경로로 `stops` 없이 호출되면 목업 데이터가 노출됩니다.** 기본값을 `[]`로 바꾸는 것이 안전합니다.

```swift
// Sources/Features/Planning/DestinationCoordinateStore.swift:37
// TODO: 좌표 파이프라인 완성 후 제거하고, 좌표가 없으면 목적지를 만들지 않도록 되돌립니다.
```

§2.4의 빈 지도 문제와 연결됩니다. 함께 확인할 것.

---

## 5. ⚪ 확인 결과 문제 없는 것

불필요한 걱정을 덜기 위해 함께 기록합니다.

| 항목 | 판단 | 근거 |
|---|---|---|
| **콘텐츠가 포항 지역뿐** | 문제 없음 | 서비스 범위가 좁은 건 가이드라인 위반이 아님. 지역 한정 앱은 App Store에 많음. 단, §3.4의 설명 문구로 범위를 정직하게 밝힐 것 |
| **픽셀맵에 포항 한 칸만 채워짐** | 문제 없음 | 수집형 앱의 정상적인 진행도 표현. 빈 칸이 많은 게 오히려 자연스러움. 리뷰어도 그렇게 읽음 |
| **위치 권한 사용 설명** | ✅ 있음 | `project.pbxproj:299,340`에 `INFOPLIST_KEY_NSLocationWhenInUseUsageDescription` 존재 |
| **사진 접근 권한** | ✅ 불필요 | `TripRecordView`가 SwiftUI `PhotosPicker` 사용 → `NSPhotoLibraryUsageDescription` 없어도 됨 |
| **API 키 관리** | ✅ 적절 | `Secrets.xcconfig`가 `.gitignore:67`에 포함, `Secrets.example.xcconfig`만 추적 |
| **앱 아이콘 크기** | ✅ 1024×1024 | 단 알파 채널 문제는 §1.1 참조 |
| **화면 방향** | ✅ 세로 고정 | `UISupportedInterfaceOrientations` 설정됨 |

---

## 6. 2차 출시를 위해 "지금" 해둘 것

### CloudKit 전환 대비 — SwiftData 모델 제약

2차에서 CloudKit을 켤 때 SwiftData 모델에 제약이 걸립니다. **1차 출시 전에 맞춰두지 않으면, 이미 사용자 데이터가 쌓인 뒤 마이그레이션이 매우 어려워집니다.**

`Trip` / `RouteStop` / `TripPhoto` / `UserPixel` 네 모델을 아래 규칙에 맞출 것:

- 모든 프로퍼티는 **옵셔널이거나 기본값**이 있어야 함
- `@Attribute(.unique)` **사용 금지**
- 관계는 반드시 **양방향(inverse)** 정의

### 2차 전환 시 체크리스트

- [ ] `Picsel.entitlements`의 iCloud 컨테이너 식별자 채우기
- [ ] `ModelConfiguration(cloudKitDatabase: .automatic)` 적용
- [ ] `CKContainer.accountStatus()`로 iCloud 미로그인 상태 안내 처리
- [ ] Privacy Nutrition Label에 iCloud 항목 추가
- [ ] 개인정보 처리방침에서 "예정" → 현재형으로 수정
- [ ] 전국 사진 카탈로그 연결 후 `KoreaExtremePoint` 기반 반경으로 복구
- [ ] `PhotoDestinationServiceFactory`의 기본 Client를 서버 Client로 교체

---

## 부록 A. 심사 노트 (Review Notes) 붙여넣기용

> ⚠️ 아래는 **로그인 게이트를 제거한 경우** 기준입니다. 로그인을 유지한다면 마지막 줄을 빼고 탈퇴 경로를 대신 적으세요.
> ⚠️ 앱 이름 확정 후 `Picsel` 부분을 새 이름으로 교체하세요.

```
Picsel is a photo-based travel discovery app using the Korea Tourism
Organization's open photo data.

Content scope for this initial release:
This version ships with a curated photo catalog covering the Pohang
region only. The radius slider on the Home screen is intentionally
limited to the range covered by this catalog. Nationwide coverage is
planned for a future update as we expand the catalog.

The "Picsel Map" tab is a collection/progress feature. Regions are
unlocked as the user completes trips, so most cells appear empty on a
new install. This is intended behavior, not missing content.

To test: Home tab > adjust the radius slider > browse photos > select a
destination > swipe through waypoints > start the trip. Completing a
trip unlocks a region cell in the Picsel Map tab.

No account is required to use the app.
```

---

## 부록 B. 제출 전 최종 점검

Release 스킴으로 Archive한 빌드를 실기기에 설치하고 아래를 직접 해볼 것.

- [ ] 앱 첫 실행이 크래시 없이 되는가 (§4.3)
- [ ] **기내모드**에서 실행 — 사진 자리에 플레이스홀더가 뜨는가, 크래시하지 않는가 (§4.4)
- [ ] 위치 권한을 **거부**했을 때 앱이 정상 동작하는가
- [ ] 설정 탭 전체를 열어 placeholder 문구가 남아있지 않은가 (§2.1)
- [ ] 홈 → 사진 탐색 → 목적지 선택 → 경유지 스와이프 → 여행 시작 → 완료 전체 플로우가 끊기지 않는가
- [ ] 경로 확인 화면에서 "지도 사진 + 경로 (네비게이션처럼)" 문구가 뜨지 않는가 (§2.4)
- [ ] 여행 완료 후 픽셀맵에 칸이 실제로 채워지는가
- [ ] 다크모드에서 화면이 깨지지 않는가
- [ ] 앱 아이콘이 홈 화면에 정상 표시되는가 (§1.1, §1.2)

---

## 부록 C. 참고 링크

- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Offering account deletion in your app](https://developer.apple.com/support/offering-account-deletion-in-your-app/)
- [TN3194: Handling account deletions and revoking tokens for Sign in with Apple](https://developer.apple.com/documentation/technotes/tn3194-handling-account-deletions-and-revoking-tokens-for-sign-in-with-apple)
- [Describing use of required reason API (Privacy Manifest)](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files/describing_use_of_required_reason_api)
- [KIPRIS 상표 검색](https://www.kipris.or.kr)

주요 가이드라인 조항:

| 조항 | 내용 | 본문 |
|---|---|---|
| 2.1 | App Completeness — placeholder, 크래시, 동작하지 않는 컨트롤 | §2.1, §2.4, §4.1, §4.3, §4.4 |
| 2.3.1 / 2.3.3 | Accurate Metadata — 설명·스크린샷이 실제와 달라선 안 됨 | §3.3, §3.4 |
| 2.3.7 | Choose a unique app name (30자 이내) | §1.4 |
| 4.1 | Copycats — 타 개발자의 제품명을 앱 이름에 쓸 수 없음 | §1.4 |
| 5.1.1(i) | 개인정보 처리방침을 메타데이터와 앱 양쪽에 | §3.1 |
| 5.1.1(v) | 계정 생성이 있으면 인앱 계정 삭제 필수 / 계정 기반 기능이 없으면 로그인 강제 금지 | §2.2, §2.3 |
