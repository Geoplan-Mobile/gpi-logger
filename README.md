# gpi-logger

iOS 통합 로그 클래스. `os.Logger` + 파일 로그 이중 기록. Public API 는 `GpiLogger` 하나.

## 설치

Swift import 시 SPM 이 대시를 언더스코어로 치환하므로 모든 경우 공통:
```swift
import gpi_logger
```

### 방법 A — SPM (`Package.swift` 사용 프로젝트)

Package.swift 에 의존 추가:
```swift
dependencies: [
    .package(url: "https://github.com/Geoplan-Mobile/gpi-logger.git", exact: "1.0.0"),
],
targets: [
    .target(
        name: "your-module",
        dependencies: [
            .product(name: "gpi-logger", package: "gpi-logger"),
        ]
    )
]
```

### 방법 B — Xcode 프로젝트 (`xcodeproj` 사용, xcframework 빌드 등)

Package.swift 대신 xcodeproj 로 관리되는 프로젝트는 **Xcode 의 Package Dependencies UI 를 통해 gpi-logger 를 추가**한다. URL: `https://github.com/Geoplan-Mobile/gpi-logger.git`.

## 사용

각 소비자 모듈이 자기 subsystem 으로 **전역 인스턴스 하나** 만들어놓고 어디서든 재사용:

```swift
// e.g. YourModule/Log.swift
import gpi_logger

let logger = GpiLogger(subsystem: "gpi-tapfree")                         // 파일 로그 on (기본)
// let logger = GpiLogger(subsystem: "gpi-tapfree", fileLogging: false)  // os.Logger 만, 파일 로그 off
```

파일 로그 활성 여부는 **생성 시점에 결정**하고 이후 변경 불가. 필요 시 인스턴스를 새로 만들어야 함.

간단한 호출:
```swift
class Zone {
    func doSomething() {
        logger.log("hello")
        // → Console.app: subsystem="gpi-tapfree", category="Zone", message="hello"
        // → 파일: Documents/gpi-tapfree/yyyyMMdd.txt  (fileLogging: true 인 경우)
    }
}
```

상세한 호출 패턴 (여러 값 조합, category override, String interpolation 등) 과 **Console.app 에서 로그 조회하는 법** 은 → [USAGE.md](USAGE.md) 참조.

## Public API

| 항목 | 설명 |
|---|---|
| `GpiLogger(subsystem: String, fileLogging: Bool = true)` | 인스턴스 생성. subsystem 이 Console.app 필터·파일 로그 폴더 이름. fileLogging 은 이후 변경 불가 |
| `logger.log(_ items:, category:, ...)` | 로그 기록. `print` 호환 시그니처 |

내부 구현 (`FileLogger` 등) 은 모두 internal — 소비자가 접근할 필요 없음.

## 권장 패턴 — 모듈 내 `Log.swift` 로 감싸기

소비자 모듈은 `logger` 를 직접 노출하지 말고 **자유 함수** 로 감싸는 게 관리 편함. `logger` 는 파일-스코프 `private` 로 격리하고, 다른 파일은 그 자유 함수만 씀.

함수 이름은 자유롭게 (예: `tlog`, `log`, `mLog` 등). **시그니처는 `GpiLogger.log` 와 동일하게 유지** 해서 소비자 코드 스타일이 gpi-logger 와 일치하도록.

```swift
// YourModule/internal/log/Log.swift
import Foundation
import gpi_logger

private let logger = GpiLogger(subsystem: "your-module")

/// GpiLogger.log 와 동일 시그니처의 자유 함수. 이름은 프로젝트 관례에 맞게.
func tlog(
    _ items: Any...,
    separator: String = " ",
    terminator: String = "\n",
    category: String? = nil,
    fileID: String = #fileID
) {
    let message = items.map { String(describing: $0) }.joined(separator: separator)
    logger.log(message, separator: separator, terminator: terminator, category: category, fileID: fileID)
}
```

이후 소비자 모듈의 다른 파일들은 gpi-logger 를 import 안 하고 `tlog("...")` 만 호출.

## 동작 원리

### subsystem 격리

같은 subsystem 을 쓰는 `GpiLogger` 인스턴스가 여러 개여도 내부 `FileLogger` 는 subsystem 별 싱글톤이라 파일 로그가 뒤섞이지 않음. 다른 subsystem 은 완전히 독립.

여러 모듈이 각자 자기 이름으로 로그를 남기고 싶으면 각 모듈이 자기 `GpiLogger(subsystem: "…")` 를 선언하면 됨. Console.app 에서도 subsystem 필터로 분리해서 볼 수 있음.

### 배치 write

파일 write 는 큐 기반 백그라운드 스레드에서 최대 500개씩 묶어 한 번의 open/write/close 세션으로 처리. DL-TDoA 같은 고빈도 로그도 시스템콜 부담 낮음.

### 크래시 안전성

파일은 매 배치마다 close 되므로 프로세스 크래시 시:
- 큐에 아직 쌓여 있던 최대 50ms 분량 메시지는 손실 가능
- 이미 배치로 flush 된 데이터는 안전
- 다음 실행이 같은 파일을 재열어 append (잠금·손상 없음)

### 파일 관리

- 파일명: `Documents/{subsystem}/yyyyMMdd.txt`
- 5일 초과된 파일은 12시간 주기로 자동 삭제

## 로그 파일을 파일 앱에서 열어보기

이 모듈을 사용하는 **앱**의 `Info.plist` 에 아래 두 키를 `YES` 로 설정하면 iOS 파일 앱 / macOS Finder 에서 `Documents/{subsystem}/yyyyMMdd.txt` 를 열람·복사할 수 있습니다.

| 키 | 효과 |
|---|---|
| `UIFileSharingEnabled` | Finder(맥 연결) → 파일 → 앱 목록에 Documents 노출 |
| `LSSupportsOpeningDocumentsInPlace` | iOS 파일 앱 → 둘러보기 → "내 iPhone" 에서 앱 폴더 접근 |

### 방법 A — Info.plist 직접 편집

```xml
<key>UIFileSharingEnabled</key>
<true/>
<key>LSSupportsOpeningDocumentsInPlace</key>
<true/>
```

### 방법 B — Build Settings (`GENERATE_INFOPLIST_FILE = YES` 프로젝트)

xcconfig 또는 target build settings 에:
```
INFOPLIST_KEY_UIFileSharingEnabled = YES
INFOPLIST_KEY_LSSupportsOpeningDocumentsInPlace = YES
```

### 사용 예

앱 재빌드 후 실기기에 설치하면:

**iOS 파일 앱**
```
파일 → 둘러보기 → "내 iPhone" → <앱 이름>
  └─ {subsystem}/
       └─ yyyyMMdd.txt  ← 여기서 탭해서 열람, 공유 시트로 AirDrop 등 가능
```

**macOS Finder** (USB 연결)
```
Finder → 사이드바의 기기 → 파일 탭 → <앱 이름>
  └─ Documents 하위 파일을 드래그로 맥에 복사
```

두 키는 **권한이 아니라 노출 스위치**입니다 (사용자 프롬프트 없음). 개발·QA 편의를 위한 설정이며, 배포 앱에도 남겨두면 사용자가 로그를 뽑아 지원팀에 전달하기 쉽습니다.

## 라이센스

내부 사용.
