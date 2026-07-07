# Changelog

本项目遵循 [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) 的结构，并使用语义化版本标签发布。

## [0.1.2] - 2026-07-07

### Added

- 支持在响应输入框中按行解析多条响应帧。
- 寄存器解析表支持按响应帧动态展示多列数值。

### Changed

- 收紧寄存器解析表列宽和列间距。
- 缓存寄存器解析表的对齐结果，减少切换页面时的重复计算。

## [0.1.1] - 2026-07-07

### Changed

- 最低运行系统调整为 macOS 13。
- 响应解析寄存器表将地址列标注为“寄存器地址”。

### Fixed

- 移除 macOS 14 专用 Observation API，改用 macOS 13 可用的 ObservableObject 状态模型。

## [0.1.0] - 2026-07-01

### Added

- 支持构建 Modbus RTU / TCP 请求帧。
- 支持解析 RTU / TCP 响应帧、CRC、异常响应、寄存器和线圈数据。
- 提供 macOS 原生 SwiftUI 界面、协议参考页和示例数据。
- 提供 SwiftPM 测试、开发构建脚本和 GitHub Release 打包流程。
