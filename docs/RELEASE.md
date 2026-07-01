# Release Guide

ModbusWorkbench 不通过 App Store 分发。推荐的发布资产是压缩后的 `.app`，例如：

```text
ModbusWorkbench-0.1.0-macos-universal.zip
ModbusWorkbench-0.1.0-macos-universal.zip.sha256
```

不要把裸 `.app` 目录直接作为 Release 资产上传。`.app` 是目录结构，直接上传或随意压缩容易丢失权限、资源分支或签名相关元数据。项目脚本使用 `ditto` 打包，适合 macOS 应用分发。

## 本地发布包

```bash
swift test
./script/package_release.sh 0.1.0
```

产物会生成在：

```text
dist/release/
```

默认发布包是 universal binary，支持 Apple Silicon 和 Intel Mac。如果本机环境不能交叉构建，可以只构建当前架构：

```bash
UNIVERSAL_BINARY=0 ./script/package_release.sh 0.1.0
```

## GitHub Release

创建版本标签后推送：

```bash
git tag v0.1.0
git push origin v0.1.0
```

GitHub Actions 会运行测试、构建 release app bundle、生成 zip 和 sha256，并创建 GitHub Release。

## 签名和公证

没有 Developer ID 证书时也可以发布 zip，但用户首次打开时可能会看到 macOS Gatekeeper 的“无法验证开发者”提示，需要右键打开或在系统设置中允许。

更正式的分发流程是：

1. 使用 Developer ID Application 证书签名。
2. 启用 Hardened Runtime。
3. 使用 Apple notarytool 公证。
4. stapler 把公证票据 stapling 到 `.app`。
5. 重新用 `ditto` 生成 zip。

本项目的打包脚本支持以下环境变量：

```bash
CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
NOTARYTOOL_PROFILE="notarytool-keychain-profile" \
./script/package_release.sh 0.1.0
```

如果未设置 `CODESIGN_IDENTITY`，脚本会生成未签名发布包。
