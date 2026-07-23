// swift-tools-version: 5.9
//
// gpi-logger 배포 매니페스트.
// 소스 저장소는 별도로 존재하고 (사내 GitLab), 본 저장소는 미리 빌드된
// gpi-logger.xcframework 만 배포한다.
// 사용 라이브러리는 본 저장소의 SPM URL 만 의존하면 xcframework 를 자동으로 링크.
//

import PackageDescription

let package = Package(
    name: "gpi-logger",
    platforms: [
        .iOS("14.0"),  // os.Logger 기준
    ],
    products: [
        // binary + carrier 를 하나의 라이브러리로 묶음.
        // 소비자는 .product(name: "gpi-logger", ...) 한 줄로 xcframework 를 build graph 에 포함.
        .library(
            name: "gpi-logger",
            targets: ["gpi-logger", "gpi-logger-deps"]
        ),
    ],
    dependencies: [
        // 현재 gpi-logger 는 외부 의존 없음.
        // (Foundation, os 는 표준 라이브러리라 SPM 선언 불필요.)
    ],
    targets: [
        // 실제 라이브러리 (사용자가 import 하는 대상).
        // 모듈 이름은 dash 가 underscore 로 자동 변환되어 `import gpi_logger` 로 사용.
        .binaryTarget(
            name: "gpi-logger",
            path: "gpi-logger.xcframework"
        ),
        // deps 캐리어. SPM 의 binaryTarget 이 dependencies 인자를 받지 못하는 제약을
        // 우회하기 위한 placeholder. 지금은 외부 dep 이 없어 비어 있지만 향후 필요 시
        // 여기에 transitive 의존을 등록한다.
        .target(
            name: "gpi-logger-deps",
            dependencies: [
            ],
            path: "Sources/gpi-logger-deps"
        ),
    ]
)
