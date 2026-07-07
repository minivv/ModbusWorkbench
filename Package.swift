// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "ModbusWorkbench",
  platforms: [
    .macOS(.v13)
  ],
  products: [
    .executable(name: "ModbusWorkbench", targets: ["ModbusWorkbench"])
  ],
  targets: [
    .executableTarget(
      name: "ModbusWorkbench",
      path: "Sources/ModbusWorkbench"
    ),
    .testTarget(
      name: "ModbusWorkbenchTests",
      dependencies: ["ModbusWorkbench"],
      path: "Tests/ModbusWorkbenchTests"
    )
  ]
)
