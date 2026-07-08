import SwiftUI

struct AboutView: View {
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        Panel(title: "关于", systemImage: "info.circle") {
          VStack(alignment: .leading, spacing: 12) {
            Link("开源地址 minivv/ModbusWorkbench", destination: URL(string: "https://github.com/minivv/ModbusWorkbench")!)
            Link("个人主页 https://weispot.vercel.app/", destination: URL(string: "https://weispot.vercel.app/")!)
          }
          .font(.callout)
        }
      }
      .padding(20)
      .frame(maxWidth: 720, alignment: .leading)
    }
  }
}
