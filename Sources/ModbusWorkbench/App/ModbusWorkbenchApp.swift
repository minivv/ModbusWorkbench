import AppKit
import SwiftUI

@main
struct ModbusWorkbenchApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  @State private var workbench = WorkbenchStore()

  var body: some Scene {
    WindowGroup("Modbus 调试台") {
      ContentView(store: workbench)
        .frame(minWidth: 1000, minHeight: 660)
    }
    .commands {
      CommandMenu("Modbus") {
        Button("构建命令") {
          workbench.buildCommand()
        }
        .keyboardShortcut("b", modifiers: [.command])

        Button("解析响应") {
          workbench.parseResponse()
        }
        .keyboardShortcut("r", modifiers: [.command])

        Divider()

        Button("载入寄存器示例") {
          workbench.loadRegisterExample()
        }
        .keyboardShortcut("1", modifiers: [.command])

        Button("载入异常示例") {
          workbench.loadExceptionExample()
        }
        .keyboardShortcut("2", modifiers: [.command])
      }
    }

    Settings {
      SettingsView()
    }
  }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
  }
}
