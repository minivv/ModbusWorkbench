import SwiftUI

struct ContentView: View {
  @ObservedObject var store: WorkbenchStore
  @Binding var selection: AppSection

  var body: some View {
    NavigationSplitView {
      SidebarView(selection: $selection)
    } detail: {
      Group {
        switch selection {
        case .builder:
          CommandBuilderView(store: store)
        case .parser:
          ResponseParserView(store: store)
        case .reference:
          ProtocolReferenceView()
        case .about:
          AboutView()
        }
      }
      .navigationTitle(selection.title)
    }
  }
}
