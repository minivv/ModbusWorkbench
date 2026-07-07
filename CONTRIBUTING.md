# Contributing

感谢你对 ModbusWorkbench 感兴趣。这个项目目前聚焦在“离线构建和解析 Modbus 报文”，暂不包含真实串口或 TCP 通讯。

## 开发环境

- macOS 13 或更高版本
- Swift 5.9+
- Xcode Command Line Tools 或完整 Xcode

## 本地验证

提交改动前请至少运行：

```bash
swift test
./script/package_release.sh 0.0.0-dev
```

如果改动涉及界面，也建议运行：

```bash
./script/build_and_run.sh
```

## Pull Request

- 保持改动聚焦，一个 PR 解决一个问题。
- 修改解析、编码、CRC 或数值显示逻辑时，请补充或更新测试。
- 修改用户界面时，请附上截图或说明可验证路径。
- 不要提交 `dist/`、`.build/`、`.swiftpm/`、`DerivedData/` 等本机构建产物。

## Issue

报告问题时请提供：

- macOS 版本
- ModbusWorkbench 版本或 commit
- 输入帧、传输类型 RTU/TCP、期望结果和实际结果
- 如果是 UI 问题，请附截图
