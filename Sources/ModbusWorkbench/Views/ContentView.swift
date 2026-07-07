import SwiftUI

struct ContentView: View {
  @ObservedObject var store: WorkbenchStore

  var body: some View {
    NavigationSplitView {
      SidebarView(selection: $store.selection)
    } detail: {
      Group {
        switch store.selection {
        case .builder:
          CommandBuilderView(store: store)
        case .parser:
          ResponseParserView(store: store)
        case .reference:
          ProtocolReferenceView()
        }
      }
      .navigationTitle(store.selection.title)
    }
  }
}
