import SwiftUI

struct Panel<Content: View>: View {
  let title: String
  let systemImage: String
  let minHeight: CGFloat?
  var content: Content

  init(
    title: String,
    systemImage: String,
    minHeight: CGFloat? = nil,
    @ViewBuilder content: () -> Content
  ) {
    self.title = title
    self.systemImage = systemImage
    self.minHeight = minHeight
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(spacing: 8) {
        Image(systemName: systemImage)
          .foregroundStyle(.secondary)
        Text(title)
          .font(.headline)
        Spacer()
      }

      content
    }
    .padding(16)
    .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .stroke(.separator.opacity(0.55))
    }
  }
}

struct FieldRow<Content: View>: View {
  let title: String
  var labelWidth: CGFloat = 88
  @ViewBuilder var content: Content

  var body: some View {
    GridRow {
      Text(title)
        .foregroundStyle(.secondary)
        .frame(width: labelWidth, alignment: .leading)
      content
        .frame(alignment: .leading)
    }
  }
}

struct KeyValueRow: View {
  let title: String
  let value: String

  var body: some View {
    HStack(alignment: .firstTextBaseline) {
      Text(title)
        .foregroundStyle(.secondary)
      Spacer(minLength: 16)
      Text(value)
        .textSelection(.enabled)
        .monospacedDigit()
    }
    .font(.callout)
  }
}

struct StatusBadge: View {
  enum Kind {
    case ok
    case warning
    case error
    case neutral

    var color: Color {
      switch self {
      case .ok:
        .green
      case .warning:
        .orange
      case .error:
        .red
      case .neutral:
        .secondary
      }
    }

    var image: String {
      switch self {
      case .ok:
        "checkmark.circle.fill"
      case .warning:
        "exclamationmark.triangle.fill"
      case .error:
        "xmark.octagon.fill"
      case .neutral:
        "info.circle.fill"
      }
    }

    var foregroundColor: Color {
      switch self {
      case .ok:
        .black
      case .warning, .error, .neutral:
        color
      }
    }
  }

  let text: String
  let kind: Kind

  var body: some View {
    Label(text, systemImage: kind.image)
      .font(.caption.weight(.medium))
      .foregroundStyle(kind.foregroundColor)
      .labelStyle(.titleAndIcon)
      .padding(.horizontal, 8)
      .padding(.vertical, 5)
      .background(kind.color.opacity(0.12), in: Capsule())
      .overlay {
        Capsule().stroke(kind.color.opacity(0.3))
      }
  }
}

struct HexBlock: View {
  let title: String
  let bytes: [UInt8]
  var actionTitle: String?
  var action: (() -> Void)?
  @State private var didCopy = false

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        Text(title)
          .font(.subheadline.weight(.semibold))
        if let actionTitle, let action {
          Button {
            action()
            didCopy = true
            Task { @MainActor in
              try? await Task.sleep(for: .seconds(1))
              didCopy = false
            }
          } label: {
            HStack(spacing: 5) {
              Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                .frame(width: 14, alignment: .center)
              Text("复制")
            }
          }
          .buttonStyle(.bordered)
          .controlSize(.small)
          .help(actionTitle)
        }
        Spacer()
      }

      Text(HexFormatter.bytes(bytes))
        .font(.system(.body, design: .monospaced))
        .textSelection(.enabled)
        .lineLimit(nil)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
  }
}

struct AnnotatedFrameView: View {
  let title: String
  let segments: [FrameSegment]

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(title)
        .font(.subheadline.weight(.semibold))

      ScrollView(.horizontal) {
        HStack(alignment: .bottom, spacing: 8) {
          ForEach(segments) { segment in
            SegmentTokenView(segment: segment)
          }
        }
        .padding(.vertical, 2)
      }
      .scrollIndicators(.visible)
    }
  }
}

private struct SegmentTokenView: View {
  let segment: FrameSegment

  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(segment.label)
        .font(.caption.weight(.semibold))
        .foregroundStyle(segment.kind.labelColor)
        .lineLimit(1)

      Text(HexFormatter.bytes(segment.bytes))
        .font(.system(.body, design: .monospaced))
        .textSelection(.enabled)
        .lineLimit(1)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(segment.kind.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
          RoundedRectangle(cornerRadius: 7, style: .continuous)
            .stroke(segment.kind.color.opacity(0.34))
        }
    }
  }
}

private extension FrameSegmentKind {
  var color: Color {
    switch self {
    case .transport:
      .secondary
    case .address:
      .blue
    case .function:
      .indigo
    case .addressRange:
      .teal
    case .quantity, .byteCount:
      .orange
    case .data:
      .green
    case .checksum:
      .pink
    case .exception:
      .red
    case .value:
      .purple
    }
  }

  var labelColor: Color {
    switch self {
    case .data:
      .black
    case .transport, .address, .function, .addressRange, .quantity, .byteCount, .checksum, .exception, .value:
      color
    }
  }
}

struct WarningList: View {
  let warnings: [String]

  var body: some View {
    if !warnings.isEmpty {
      VStack(alignment: .leading, spacing: 8) {
        ForEach(warnings, id: \.self) { warning in
          Label(warning, systemImage: "exclamationmark.triangle")
            .font(.callout)
            .foregroundStyle(.orange)
        }
      }
    }
  }
}

struct EmptyStateView: View {
  let title: String
  let systemImage: String

  var body: some View {
    VStack(spacing: 12) {
      Image(systemName: systemImage)
        .font(.system(size: 34, weight: .regular))
        .foregroundStyle(.secondary)
      Text(title)
        .font(.headline)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, minHeight: 180)
  }
}
