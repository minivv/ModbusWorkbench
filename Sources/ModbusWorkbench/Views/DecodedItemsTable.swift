import SwiftUI

struct DecodedItemsTable: View {
  @ObservedObject var store: WorkbenchStore
  let frame: ParsedFrame

  var body: some View {
    if frame.isRegisterRead {
      registerRows
    } else if frame.isBitRead {
      bitItems
    } else if frame.decodedItems.isEmpty {
      EmptyStateView(title: "没有可解析的数据值", systemImage: "tablecells.badge.ellipsis")
    } else {
      simpleItems
    }
  }

  private var bitItems: some View {
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
    let rows = NumberDecoder.registerRows(
      startAddress: store.assumedStartAddress,
      registers: frame.registerValues,
      defaultMode: store.parseDisplayMode,
      overrides: store.registerDisplayOverrides
    )

    return VStack(alignment: .leading, spacing: 0) {
      RegisterHeaderRow()

      LazyVStack(alignment: .leading, spacing: 0) {
        ForEach(rows) { row in
          RegisterValueRow(row: row, mode: modeBinding(for: row.address))
            .padding(.vertical, 7)
            .background(row.address.isMultiple(of: 2) ? Color.clear : Color.secondary.opacity(0.06))
        }
      }
    }
    .background(.quaternary.opacity(0.18), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .stroke(.separator.opacity(0.4))
    }
  }

  private var simpleItems: some View {
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

  private func modeBinding(for address: Int) -> Binding<DataDisplayMode> {
    Binding(
      get: {
        store.registerDisplayOverrides[address] ?? store.parseDisplayMode
      },
      set: { newValue in
        if newValue == store.parseDisplayMode {
          store.registerDisplayOverrides.removeValue(forKey: address)
        } else {
          store.registerDisplayOverrides[address] = newValue
        }
      }
    )
  }
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
  var body: some View {
    HStack(spacing: 12) {
      Text("寄存器地址").frame(width: 84, alignment: .leading)
      Text("占用").frame(width: 58, alignment: .leading)
      Text("解析方式").frame(width: 176, alignment: .leading)
      Text("原始值").frame(width: 180, alignment: .leading)
      Text("数值").frame(maxWidth: .infinity, alignment: .leading)
    }
    .font(.caption.weight(.semibold))
    .foregroundStyle(.secondary)
    .padding(.horizontal, 12)
    .padding(.vertical, 9)
    .background(.quaternary.opacity(0.35))
  }
}

private struct RegisterValueRow: View {
  let row: RegisterDecodeRow
  @Binding var mode: DataDisplayMode

  var body: some View {
    HStack(spacing: 12) {
      Text("\(row.address)")
        .frame(width: 84, alignment: .leading)
        .monospacedDigit()

      Text(row.span == 1 ? "1 位" : "\(row.span) 位")
        .frame(width: 58, alignment: .leading)
        .foregroundStyle(.secondary)
        .monospacedDigit()

      Picker("解析方式", selection: $mode) {
        ForEach(DataDisplayMode.allCases) { mode in
          Text(mode.rawValue).tag(mode)
        }
      }
      .labelsHidden()
      .frame(width: 176)

      Text(row.raw)
        .font(.system(.callout, design: .monospaced))
        .lineLimit(1)
        .textSelection(.enabled)
        .frame(width: 180, alignment: .leading)

      VStack(alignment: .leading, spacing: 2) {
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
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .font(.callout)
    .padding(.horizontal, 12)
  }
}
