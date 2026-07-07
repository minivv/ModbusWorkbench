import SwiftUI

struct DecodedItemsTable: View {
  @ObservedObject var store: WorkbenchStore
  let frames: [ParsedFrame]
  let comparisonRows: [RegisterComparisonRow]

  var body: some View {
    if !frames.isEmpty, frames.allSatisfy({ $0.isRegisterRead }) {
      registerRows
    } else if frames.count == 1, let frame = frames.first, frame.isBitRead {
      bitItems(frame: frame)
    } else if frames.count == 1, let frame = frames.first, frame.decodedItems.isEmpty {
      EmptyStateView(title: "没有可解析的数据值", systemImage: "tablecells.badge.ellipsis")
    } else if frames.count == 1, let frame = frames.first {
      simpleItems(frame: frame)
    } else {
      EmptyStateView(title: "多条响应类型不一致", systemImage: "tablecells.badge.ellipsis")
    }
  }

  private func bitItems(frame: ParsedFrame) -> some View {
    LazyVGrid(
      columns: [GridItem(.adaptive(minimum: 76), spacing: 6)],
      alignment: .leading,
      spacing: 6
    ) {
      ForEach(frame.decodedItems) { item in
        BitValuePill(item: item)
      }
    }
    .padding(8)
    .background(.quaternary.opacity(0.18), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .stroke(.separator.opacity(0.35))
    }
  }

  private var registerRows: some View {
    let valueCount = max(frames.count, 1)

    return ScrollView(.horizontal) {
      VStack(alignment: .leading, spacing: 0) {
        RegisterHeaderRow(valueCount: valueCount)

        LazyVStack(alignment: .leading, spacing: 0) {
          ForEach(comparisonRows) { row in
            RegisterValueRow(row: row, mode: modeBinding(for: row.address))
              .padding(.vertical, 7)
              .background(row.address.isMultiple(of: 2) ? Color.clear : Color.secondary.opacity(0.06))
          }
        }
      }
      .frame(minWidth: tableWidth(valueCount: valueCount), alignment: .leading)
    }
    .background(.quaternary.opacity(0.18), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .stroke(.separator.opacity(0.4))
    }
  }

  private func simpleItems(frame: ParsedFrame) -> some View {
    LazyVGrid(
      columns: [GridItem(.adaptive(minimum: 132), spacing: 10)],
      alignment: .leading,
      spacing: 10
    ) {
      ForEach(frame.decodedItems) { item in
        VStack(alignment: .leading, spacing: 4) {
          Text(item.label)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
          Text(item.value)
            .font(.system(.callout, design: .monospaced))
            .monospacedDigit()
            .lineLimit(1)
          Text(item.raw)
            .font(.caption2.monospaced())
            .foregroundStyle(.tertiary)
            .lineLimit(1)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
      }
    }
  }

  private func tableWidth(valueCount: Int) -> CGFloat {
    RegisterTableLayout.addressWidth +
      RegisterTableLayout.spanWidth +
      RegisterTableLayout.modeWidth +
      RegisterTableLayout.rawWidth +
      (CGFloat(valueCount) * RegisterTableLayout.valueWidth) +
      (CGFloat(valueCount + 3) * RegisterTableLayout.columnSpacing) +
      (RegisterTableLayout.horizontalPadding * 2)
  }

  private func modeBinding(for address: Int) -> Binding<DataDisplayMode> {
    Binding(
      get: {
        store.registerDisplayOverrides[address] ?? store.parseDisplayMode
      },
      set: { newValue in
        store.setRegisterDisplayMode(newValue, for: address)
      }
    )
  }
}

private enum RegisterTableLayout {
  static let columnSpacing: CGFloat = 8
  static let horizontalPadding: CGFloat = 10
  static let addressWidth: CGFloat = 74
  static let spanWidth: CGFloat = 44
  static let modeWidth: CGFloat = 156
  static let rawWidth: CGFloat = 150
  static let valueWidth: CGFloat = 132
}

private struct BitValuePill: View {
  let item: DecodedItem

  private var isOn: Bool { item.note == "1" || item.value == "开" }

  var body: some View {
    HStack(spacing: 6) {
      Circle()
        .fill(isOn ? Color.green : Color.secondary.opacity(0.35))
        .frame(width: 7, height: 7)

      Text("\(item.address)")
        .font(.caption.monospacedDigit())
        .foregroundStyle(.secondary)
        .frame(minWidth: 28, alignment: .leading)

      Text(isOn ? "开" : "关")
        .font(.caption.weight(.semibold))
        .foregroundStyle(isOn ? .black : .secondary)
        .frame(width: 18, alignment: .leading)
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 5)
    .frame(height: 28)
    .background(
      isOn ? Color.green.opacity(0.16) : Color.secondary.opacity(0.08),
      in: RoundedRectangle(cornerRadius: 6, style: .continuous)
    )
    .overlay {
      RoundedRectangle(cornerRadius: 6, style: .continuous)
        .stroke(isOn ? Color.green.opacity(0.42) : Color.secondary.opacity(0.16))
    }
    .help("\(item.label)：\(item.value)，\(item.raw)")
  }
}

private struct RegisterHeaderRow: View {
  let valueCount: Int

  var body: some View {
    HStack(spacing: RegisterTableLayout.columnSpacing) {
      Text("寄存器地址").frame(width: RegisterTableLayout.addressWidth, alignment: .leading)
      Text("占用").frame(width: RegisterTableLayout.spanWidth, alignment: .leading)
      Text("解析方式").frame(width: RegisterTableLayout.modeWidth, alignment: .leading)
      Text("原始值").frame(width: RegisterTableLayout.rawWidth, alignment: .leading)
      ForEach(0..<valueCount, id: \.self) { index in
        Text(valueCount == 1 ? "数值" : "数值 \(index + 1)")
          .frame(width: RegisterTableLayout.valueWidth, alignment: .leading)
      }
    }
    .font(.caption.weight(.semibold))
    .foregroundStyle(.secondary)
    .padding(.horizontal, RegisterTableLayout.horizontalPadding)
    .padding(.vertical, 9)
    .background(.quaternary.opacity(0.35))
  }
}

private struct RegisterValueRow: View {
  let row: RegisterComparisonRow
  @Binding var mode: DataDisplayMode

  var body: some View {
    HStack(spacing: RegisterTableLayout.columnSpacing) {
      Text("\(row.address)")
        .frame(width: RegisterTableLayout.addressWidth, alignment: .leading)
        .monospacedDigit()

      Text(row.span == 1 ? "1 位" : "\(row.span) 位")
        .frame(width: RegisterTableLayout.spanWidth, alignment: .leading)
        .foregroundStyle(.secondary)
        .monospacedDigit()

      Picker("解析方式", selection: $mode) {
        ForEach(DataDisplayMode.allCases) { mode in
          Text(mode.rawValue).tag(mode)
        }
      }
      .labelsHidden()
      .controlSize(.small)
      .frame(width: RegisterTableLayout.modeWidth)

      Text(row.raw)
        .font(.system(.callout, design: .monospaced))
        .lineLimit(1)
        .textSelection(.enabled)
        .frame(width: RegisterTableLayout.rawWidth, alignment: .leading)

      ForEach(row.values.indices, id: \.self) { index in
        RegisterValueCell(row: row.values[index], mode: mode)
      }
    }
    .font(.callout)
    .padding(.horizontal, RegisterTableLayout.horizontalPadding)
  }
}

private struct RegisterValueCell: View {
  let row: RegisterDecodeRow?
  let mode: DataDisplayMode

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      if let row {
        Text(row.value)
          .font(.system(.callout, design: .monospaced))
          .monospacedDigit()
          .lineLimit(1)
          .textSelection(.enabled)
        if row.note != mode.rawValue {
          Text(row.note)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
      } else {
        Text("-")
          .font(.system(.callout, design: .monospaced))
          .foregroundStyle(.secondary)
      }
    }
    .frame(width: RegisterTableLayout.valueWidth, alignment: .leading)
  }
}
