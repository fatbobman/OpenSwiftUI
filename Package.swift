// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import Foundation
import PackageDescription

func envEnable(_ key: String, default defaultValue: Bool = false) -> Bool {
    guard let value = Context.environment[key] else {
        return defaultValue
    }
    if value == "1" {
        return true
    } else if value == "0" {
        return false
    } else {
        return defaultValue
    }
}

let isXcodeEnv = Context.environment["__CFBundleIdentifier"] == "com.apple.dt.Xcode"
let development = envEnable("OPENSWIFTUI_DEVELOPMENT", default: false)

// Xcode use clang as linker which supports "-iframework" while SwiftPM use swiftc as linker which supports "-Fsystem"
let systemFrameworkSearchFlag = isXcodeEnv ? "-iframework" : "-Fsystem"

var sharedSwiftSettings: [SwiftSetting] = [
    .enableExperimentalFeature("AccessLevelOnImport"),
    .define("OPENSWIFTUI_SUPPRESS_DEPRECATED_WARNINGS"),
]

let warningsAsErrorsCondition = envEnable("OPENSWIFTUI_WERROR", default: isXcodeEnv && development)
if warningsAsErrorsCondition {
    sharedSwiftSettings.append(.unsafeFlags(["-warnings-as-errors"]))
}

let openSwiftUITarget = Target.target(
    name: "OpenSwiftUI",
    dependencies: [
        "COpenSwiftUI",
        .target(name: "CoreServices", condition: .when(platforms: [.iOS])),
        .product(name: "OpenGraphShims", package: "OpenGraph"),
    ],
    swiftSettings: sharedSwiftSettings
)
let openSwiftUITestTarget = Target.testTarget(
    name: "OpenSwiftUITests",
    dependencies: [
        "OpenSwiftUI",
    ],
    exclude: ["README.md"],
    swiftSettings: sharedSwiftSettings
)
let openSwiftUITempTestTarget = Target.testTarget(
    name: "OpenSwiftUITempTests",
    dependencies: [
        "OpenSwiftUI",
    ],
    exclude: ["README.md"],
    swiftSettings: sharedSwiftSettings
)
let openSwiftUICompatibilityTestTarget = Target.testTarget(
    name: "OpenSwiftUICompatibilityTests",
    exclude: ["README.md"],
    swiftSettings: sharedSwiftSettings
)

let swiftBinPath = Context.environment["_"] ?? ""
let swiftBinURL = URL(fileURLWithPath: swiftBinPath)
let SDKPath = swiftBinURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().path
let includePath = SDKPath.appending("/usr/lib/swift_static")

let package = Package(
    name: "OpenSwiftUI",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .macCatalyst(.v13),
        .tvOS(.v13),
        .watchOS(.v7), // WKApplicationMain is available for watchOS 7.0+
        .visionOS(.v1),
    ],
    products: [
        .library(name: "OpenSwiftUI", targets: ["OpenSwiftUI"]),
    ],
    targets: [
        // TODO: Add SwiftGTK as an backend alternative for UIKit/AppKit on Linux and macOS
        .systemLibrary(
            name: "CGTK",
            pkgConfig: "gtk4",
            providers: [
                .brew(["gtk4"]),
                .apt(["libgtk-4-dev clang"]),
            ]
        ),
        .target(
            name: "COpenSwiftUI",
            cSettings: [
                .unsafeFlags(["-I", includePath], .when(platforms: .nonDarwinPlatforms)),
                .define("__COREFOUNDATION_FORSWIFTFOUNDATIONONLY__", to: "1", .when(platforms: .nonDarwinPlatforms)),
            ]
        ),
        .binaryTarget(name: "CoreServices", path: "PrivateFrameworks/CoreServices.xcframework"),
        openSwiftUITarget,
    ]
)

#if os(macOS)
let attributeGraphCondition = envEnable("OPENGRAPH_ATTRIBUTEGRAPH", default: true)
#else
let attributeGraphCondition = envEnable("OPENGRAPH_ATTRIBUTEGRAPH")
#endif

extension Target {
    func addAGSettings() {
        // FIXME: Weird SwiftPM behavior for test Target. Otherwize we'll get the following error message
        // "could not determine executable path for bundle 'AttributeGraph.framework'"
        dependencies.append(.product(name: "AttributeGraph", package: "OpenGraph"))

        var swiftSettings = swiftSettings ?? []
        swiftSettings.append(.define("OPENGRAPH_ATTRIBUTEGRAPH"))
        self.swiftSettings = swiftSettings
    }
}

if attributeGraphCondition {
    openSwiftUITarget.addAGSettings()
    openSwiftUITestTarget.addAGSettings()
    openSwiftUITempTestTarget.addAGSettings()
    openSwiftUICompatibilityTestTarget.addAGSettings()
}

#if os(macOS)
let openCombineCondition = envEnable("OPENSWIFTUI_OPENCOMBINE")
#else
let openCombineCondition = envEnable("OPENSWIFTUI_OPENCOMBINE", default: true)
#endif
if openCombineCondition {
    package.dependencies.append(
        .package(url: "https://github.com/OpenSwiftUIProject/OpenCombine.git", from: "0.15.0")
    )
    openSwiftUITarget.dependencies.append(
        .product(name: "OpenCombine", package: "OpenCombine")
    )
    var swiftSettings: [SwiftSetting] = (openSwiftUITarget.swiftSettings ?? [])
    swiftSettings.append(.define("OPENSWIFTUI_OPENCOMBINE"))
    openSwiftUITarget.swiftSettings = swiftSettings
}

#if os(macOS)
let swiftLogCondition = envEnable("OPENSWIFTUI_SWIFT_LOG")
#else
let swiftLogCondition = envEnable("OPENSWIFTUI_SWIFT_LOG", default: true)
#endif
if swiftLogCondition {
    package.dependencies.append(
        .package(url: "https://github.com/apple/swift-log", from: "1.5.3")
    )
    openSwiftUITarget.dependencies.append(
        .product(name: "Logging", package: "swift-log")
    )
    var swiftSettings: [SwiftSetting] = (openSwiftUITarget.swiftSettings ?? [])
    swiftSettings.append(.define("OPENSWIFTUI_SWIFT_LOG"))
    openSwiftUITarget.swiftSettings = swiftSettings
}

// Remove the check when swift-testing reaches 1.0.0
let swiftTestingCondition = envEnable("OPENSWIFTUI_SWIFT_TESTING", default: true)
if swiftTestingCondition {
    package.dependencies.append(
        // Fix it to be 0.3.0 before we bump to Swift 5.10
        .package(url: "https://github.com/apple/swift-testing", exact: "0.6.0")
    )
    openSwiftUITestTarget.dependencies.append(
        .product(name: "Testing", package: "swift-testing")
    )
    package.targets.append(openSwiftUITestTarget)
    
    openSwiftUITempTestTarget.dependencies.append(
        .product(name: "Testing", package: "swift-testing")
    )
    package.targets.append(openSwiftUITempTestTarget)
    
    openSwiftUICompatibilityTestTarget.dependencies.append(
        .product(name: "Testing", package: "swift-testing")
    )
    package.targets.append(openSwiftUICompatibilityTestTarget)
}

let compatibilityTestCondition = envEnable("OPENSWIFTUI_COMPATIBILITY_TEST")
if compatibilityTestCondition {
    var swiftSettings: [SwiftSetting] = (openSwiftUICompatibilityTestTarget.swiftSettings ?? [])
    swiftSettings.append(.define("OPENSWIFTUI_COMPATIBILITY_TEST"))
    openSwiftUICompatibilityTestTarget.swiftSettings = swiftSettings
} else {
    openSwiftUICompatibilityTestTarget.dependencies.append("OpenSwiftUI")
}

let useLocalDeps = envEnable("OPENSWIFTUI_USE_LOCAL_DEPS")
if useLocalDeps {
    package.dependencies += [
        .package(path: "../OpenGraph"),
    ]
} else {
    package.dependencies += [
        // FIXME: on Linux platform: OG contains unsafe build flags which prevents us using version dependency
        .package(url: "https://github.com/OpenSwiftUIProject/OpenGraph", branch: "main"),
    ]
}

extension [Platform] {
    static var nonDarwinPlatforms: [Platform] {
        [.linux, .android, .wasi, .openbsd, .windows]
    }
}
