import SwiftUI

struct SettingsView: View {
  @AppStorage("uppercaseHex") private var uppercaseHex = true
  @AppStorage("autoParse") private var autoParse = true

  var body: some View {
    Form {
      Toggle("十六进制使用大写显示", isOn: $uppercaseHex)
      Toggle("编辑时自动解析", isOn: $autoParse)
      Text("这些偏好预留给显示行为使用。当前版本保持协议输出确定一致。")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .formStyle(.grouped)
    .padding(20)
    .frame(width: 420)
  }
}
