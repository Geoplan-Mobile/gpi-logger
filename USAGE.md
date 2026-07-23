# gpi-logger 사용 가이드

`GpiLogger` 인스턴스 준비 방법은 [README](README.md#사용) 참조. 이 문서는 **호출 패턴과 로그 조회 방법** 을 상세히 다룹니다.

## `log()` 호출 패턴

`GpiLogger.log(...)` 는 Swift `print` 시그니처 (`items`, `separator`, `terminator`) 를 그대로 받고, 여기에 gpi-logger 특화 인자 (`category`, `fileID`) 를 추가한 확장형:
```swift
func log(
    _ items: Any...,           // ← print 와 동일 (여러 값을 가변 인자로)
    separator: String = " ",   // ← print 와 동일 (items 사이 구분자)
    terminator: String = "\n", // ← print 와 동일 (print 호환 목적, Logger 가 자체 줄바꿈 처리하므로 실제로는 무시됨)
    category: String? = nil,   // ← 추가: Console.app category. nil 이면 호출 파일명 자동 사용
    fileID: String = #fileID   // ← 추가: 컴파일러가 호출 위치를 자동 삽입 (직접 넘길 일 없음)
)
```

**즉 `print(...)` 호출을 그대로 `logger.log(...)` 로 바꿔도 동작** (Console.app / 파일 로그로 대상만 이관됨).

### 1) 단일 메시지
```swift
logger.log("hello")
```
출력 (subsystem `gpi-tapfree`, category 는 호출 파일명에서 자동 추출):
```
[Console.app]  gpi-tapfree | Zone.swift  | hello
[Xcode console] hello
[파일]         [14:23:11.234] Zone, hello
```

### 2) 여러 값 조합 (print 처럼)
```swift
logger.log("station", stationId, "zone", zoneCode)
```
기본 separator `" "` 로 자동 연결:
```
[Console.app]  gpi-tapfree | Zone | station E01 zone Z-99
[Xcode console] station E01 zone Z-99
[파일]         [14:23:11.234] Zone, station E01 zone Z-99
```

### 3) separator 커스텀
```swift
logger.log("a", "b", "c", separator: " | ")
```
```
[출력]  a | b | c
```

### 4) String interpolation (권장)
```swift
logger.log("connected: \(stationId), aisle=\(aisleId), rssi=\(rssi)")
```
가장 흔한 형태. Swift 문자열 보간이 미리 조합된 뒤 하나의 항목으로 전달됨.

### 5) category 명시 override
파일명이 아닌 논리적 분류로 묶고 싶을 때:
```swift
logger.log("card verify start", category: "Payment")
logger.log("card verify end", category: "Payment")
```
```
[Console.app]  gpi-tapfree | Payment | card verify start
```
Console.app 에서 category=Payment 필터로 결제 흐름만 모아 볼 수 있음.

### 6) 값이 없는 경우
```swift
logger.log()   // 빈 로그 — 호출된 시점만 기록됨
```
```
[출력]  (빈 문자열)
```
드물게 "여기 지났음" 마커로 사용. 대부분은 의미 있는 메시지 붙이는 게 좋음.

## 출력 3곳 요약

| 출력 대상 | 언제 나오나 | 확인 방법 |
|---|---|---|
| **Xcode 콘솔** | Xcode 로 실행 중 (Debug/Release) | Xcode 하단 콘솔 창 |
| **Console.app** | 실기기·시뮬레이터 모두 | macOS Console.app + subsystem 필터 |
| **파일** | `fileLogging: true` 로 생성된 경우만 | `Documents/{subsystem}/yyyyMMdd.txt` |

- Xcode 콘솔은 **메시지만** 표시. subsystem/category 는 안 뜸.
- Console.app 은 subsystem/category/시각 모두 컬럼으로 표시.
- 파일은 `[HH:mm:ss.SSS] {category}, {message}` 형식.

## Console.app 에서 로그 보는 법

앱을 실기기·시뮬레이터에서 실행 중 (Xcode 없이도) macOS Console.app 으로 실시간 관찰 가능.

### 초기 설정 (한 번만)

1. macOS 에서 **Console.app** 실행
2. 좌측 사이드바에서 확인할 기기 선택:
   - 실기기: USB 연결된 iPhone/iPad 이름
   - 시뮬레이터: `iPhone 15 Simulator` 같은 항목
3. 상단 검색창에 필터 입력:
   ```
   subsystem:gpi-tapfree
   ```
   여러 모듈을 함께 볼 거면:
   ```
   subsystem:gpi-tapfree OR subsystem:gpi-dltdoa
   ```
4. **Action → Include Info Messages** 체크 (안 체크하면 우리 로그가 안 보임 — `os.Logger.log` 는 info level 로 분류)
5. **Action → Include Debug Messages** 도 켜두면 안전
6. **File → Save As Filter...** 로 필터 저장 → 다음부터 사이드바에서 원클릭

### 컬럼 조정 (권장)

로그 창 상단 컬럼 헤더 우클릭 → 다음 항목 표시:
- **Time** (기본)
- **Subsystem**
- **Category**
- **Message** (기본)

이러면 각 로그의 `{subsystem, category, message}` 를 한눈에.

### 실기기가 안 보일 때

- USB 연결 확인, 기기 신뢰 프롬프트 응답
- macOS 시스템 설정에서 개발자 도구 접근 허용
- 그래도 안 나오면 Xcode 를 한 번 실행해 디바이스 페어링

### 터미널로 시뮬레이터 로그 tail

```bash
xcrun simctl spawn booted log stream --predicate 'subsystem == "gpi-tapfree"' --level debug
```

실기기 로그를 터미널로 tail 하려면 `ios-deploy` / `libimobiledevice` 별도 설치 필요 — 위 Console.app 방법이 표준.
