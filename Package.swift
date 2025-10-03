// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "PovioKitAuth",
  platforms: [
    .iOS(.v16)
  ],
  products: [
    .library(name: "PovioKitAuthCore", targets: ["PovioKitAuthCore"]),
    .library(name: "PovioKitAuthApple", targets: ["PovioKitAuthApple"]),
    .library(name: "PovioKitAuthLinkedIn", targets: ["PovioKitAuthLinkedIn"])
  ],
  dependencies: [
    .package(url: "https://github.com/kishikawakatsumi/KeychainAccess", .upToNextMajor(from: "4.0.0"))
  ],
  targets: [
    .target(
      name: "PovioKitAuthCore",
      dependencies: [
        .product(name: "KeychainAccess", package: "KeychainAccess"),
      ],
      path: "Sources/Core",
      resources: [.copy("../../Resources/PrivacyInfo.xcprivacy")]
    ),
    .target(
      name: "PovioKitAuthApple",
      dependencies: [
        "PovioKitAuthCore"
      ],
      path: "Sources/Apple",
      resources: [.copy("../../Resources/PrivacyInfo.xcprivacy")]
    ),
    .target(
      name: "PovioKitAuthLinkedIn",
      dependencies: [
        "PovioKitAuthCore"
      ],
      path: "Sources/LinkedIn",
      resources: [.copy("../../Resources/PrivacyInfo.xcprivacy")]
    ),
    .testTarget(
      name: "Tests",
      dependencies: [
        "PovioKitAuthCore"
      ]
    ),
  ]
)
