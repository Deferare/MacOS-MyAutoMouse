# MyAutoMouse

MyAutoMouse는 macOS에서 반복 클릭을 자동화하는 가벼운 SwiftUI 유틸리티입니다.

## 주요 기능

- 클릭 간격(ms) 기반 자동 클릭
- 반복 횟수 지정(`0`이면 무한 반복)
- 좌/우 클릭 선택
- 고정 좌표 캡처(3초 카운트다운 후 위치 저장)
- 시작 전 3초 카운트다운
- 접근성(Accessibility) 권한 상태 확인 및 설정 이동

## 설치

- 최신 배포본: [GitHub Releases](https://github.com/Deferare/MacOS-MyAutoMouse/releases)
- macOS에서 처음 실행 시 접근성 권한이 필요합니다.

## 사용 방법

1. `Interval`(ms), `Repeat`, `Button`을 설정합니다.
2. 필요하면 `Fixed Position`을 켜고 `Capture`로 좌표를 저장합니다.
3. `Start`를 누르면 3초 후 클릭 자동화가 시작됩니다.
4. 중지하려면 `Stop`을 누릅니다.

## 로컬에서 실행

1. `MyAutoMouse/MyAutoMouse.xcodeproj`를 Xcode로 엽니다.
2. 실행 타겟을 macOS로 선택합니다.
3. `Run`으로 앱을 실행합니다.

## 유지보수: GitHub 릴리즈 절차

Apple Developer Program 계정이 있다면, Developer ID 서명 + 공증(Notarization) 후 릴리즈를 권장합니다.

1. 버전 정리
- Xcode Build Settings의 `MARKETING_VERSION`과 `CURRENT_PROJECT_VERSION` 갱신
- 앱 내부 버전 표기(예: About 화면)와 릴리즈 태그 일치

2. Release 빌드 생성

```bash
xcodebuild \
  -project MyAutoMouse/MyAutoMouse.xcodeproj \
  -scheme MyAutoMouse \
  -configuration Release \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

3. 배포용 ZIP 생성(기본)

```bash
ditto -c -k --keepParent \
  "build/DerivedData/Build/Products/Release/MyAutoMouse.app" \
  "build/MyAutoMouse-macOS-vX.Y.Z.zip"
```

4. (권장) Developer ID 서명 + 공증 + Staple

```bash
codesign --force --deep --timestamp --options runtime \
  --sign "Developer ID Application: <NAME> (<TEAM_ID>)" \
  "build/DerivedData/Build/Products/Release/MyAutoMouse.app"

ditto -c -k --keepParent \
  "build/DerivedData/Build/Products/Release/MyAutoMouse.app" \
  "build/MyAutoMouse-macOS-vX.Y.Z-notarize.zip"

xcrun notarytool submit "build/MyAutoMouse-macOS-vX.Y.Z-notarize.zip" \
  --keychain-profile "AC_NOTARY" \
  --wait

xcrun stapler staple "build/DerivedData/Build/Products/Release/MyAutoMouse.app"
```

5. Git 태그 푸시

```bash
git tag -a vX.Y.Z -m "MyAutoMouse vX.Y.Z"
git push origin main
git push origin vX.Y.Z
```

6. GitHub Release 게시
- `vX.Y.Z` 태그로 Release 생성
- 변경사항(Release Notes) 입력
- `MyAutoMouse-macOS-vX.Y.Z.zip` 첨부

## Privacy Policy

- [PRIVACY_POLICY.md](./PRIVACY_POLICY.md)
