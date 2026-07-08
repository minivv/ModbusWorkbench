import Foundation

enum AppSection: String, CaseIterable, Identifiable {
  case builder
  case parser
  case reference
  case about

  var id: String { rawValue }

  var title: String {
    switch self {
    case .builder:
      "命令构建"
    case .parser:
      "响应解析"
    case .reference:
      "协议说明"
    case .about:
      "关于"
    }
  }

  var subtitle: String {
    switch self {
    case .builder:
      "RTU / TCP 请求帧"
    case .parser:
      "解析粘贴的响应"
    case .reference:
      "限制和字节序"
    case .about:
      "项目链接"
    }
  }

  var systemImage: String {
    switch self {
    case .builder:
      "hammer"
    case .parser:
      "doc.text.magnifyingglass"
    case .reference:
      "book"
    case .about:
      "info.circle"
    }
  }
}
