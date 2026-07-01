import SwiftUI

struct CommandBuilderView: View {
  @Bindable var store: WorkbenchStore

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Text("构建请求帧，不打开串口。")
              .foregroundStyle(.secondary)
            Text("RTU 帧包含 CRC16。TCP 帧包含 MBAP，不带 CRC。")
              .font(.caption)
              .foregroundStyle(.tertiary)
          }
          Spacer()
        }

        HStack(alignment: .top, spacing: 16) {
          CommandParametersPanel(store: store, minHeight: controlsPanelMinHeight)
            .frame(width: 310, alignment: .topLeading)

          FunctionParametersPanel(store: store, minHeight: controlsPanelMinHeight)
            .frame(width: 310, alignment: .topLeading)
        }

        CommandOutputPanel(store: store)
          .frame(maxWidth: .infinity)
      }
      .padding(20)
    }
    .onChange(of: store.command.transport) { _, _ in store.buildCommand() }
    .onChange(of: store.command.transactionID) { _, _ in store.buildCommand() }
    .onChange(of: store.command.unitID) { _, _ in store.buildCommand() }
    .onChange(of: store.command.function) { oldFunction, function in
      normalizeDefaults(from: oldFunction, to: function)
      store.buildCommand()
    }
    .onChange(of: store.command.startAddress) { _, _ in store.buildCommand() }
    .onChange(of: store.command.quantity) { _, _ in store.buildCommand() }
    .onChange(of: store.command.singleValue) { _, _ in store.buildCommand() }
    .onChange(of: store.command.valuesText) { _, _ in store.buildCommand() }
  }

  private func normalizeDefaults(from oldFunction: ModbusFunction, to function: ModbusFunction) {
    switch function {
    case .readCoils, .readDiscreteInputs:
      store.command.quantity = min(max(store.command.quantity, 1), 2000)
    case .readHoldingRegisters, .readInputRegisters:
      store.command.quantity = min(max(store.command.quantity, 1), 125)
    case .writeSingleCoil:
      store.command.singleValue = store.command.singleValue == 0 ? 0 : 1
    case .writeSingleRegister:
      break
    case .writeMultipleCoils:
      if !valuesTextIsValidForCoils(store.command.valuesText) {
        store.command.valuesText = coilDefaults
      }
    case .writeMultipleRegisters:
      if oldFunction == .writeMultipleCoils ||
        store.command.valuesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        store.command.valuesText = registerDefaults
      }
    }
  }

  private var coilDefaults: String { "1, 0, 1, 1, 0, 0, 0, 1" }

  private var registerDefaults: String { "1, 2, 3" }

  private func valuesTextIsValidForCoils(_ text: String) -> Bool {
    let tokens = text
      .replacingOccurrences(of: "\n", with: ",")
      .replacingOccurrences(of: ";", with: ",")
      .split(separator: ",")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
      .filter { !$0.isEmpty }

    guard !tokens.isEmpty else { return false }
    return tokens.allSatisfy { token in
      token == "0" || token == "1" || token == "true" || token == "false" || token == "on" || token == "off"
    }
  }

  private var controlsPanelMinHeight: CGFloat {
    switch store.command.function {
    case .writeMultipleCoils, .writeMultipleRegisters:
      220
    default:
      180
    }
  }
}

private struct CommandParametersPanel: View {
  @Bindable var store: WorkbenchStore
  let minHeight: CGFloat

  var body: some View {
    Panel(title: "传输方式", systemImage: "cable.connector", minHeight: minHeight) {
      Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
        FieldRow(title: "模式") {
          Picker("模式", selection: $store.command.transport) {
            ForEach(TransportMode.allCases) { mode in
              Text(mode.rawValue).tag(mode)
            }
          }
          .pickerStyle(.segmented)
          .labelsHidden()
          .frame(width: 180)
        }

        if store.command.transport == .tcp {
          FieldRow(title: "事务号") {
            Stepper(value: $store.command.transactionID.intBinding(), in: 0...65535) {
              NumericValueField(value: $store.command.transactionID.intBinding(), range: 0...65535)
            }
          }
        }

        FieldRow(title: "从站地址") {
          Stepper(value: $store.command.unitID.intBinding(), in: 0...247) {
            NumericValueField(value: $store.command.unitID.intBinding(), range: 0...247)
          }
        }
      }
    }
  }
}

private struct FunctionParametersPanel: View {
  @Bindable var store: WorkbenchStore
  let minHeight: CGFloat

  var body: some View {
    Panel(title: "功能码", systemImage: store.command.function.systemImage, minHeight: minHeight) {
      VStack(alignment: .leading, spacing: 12) {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
          FieldRow(title: "功能码") {
            Picker("功能码", selection: $store.command.function) {
              ForEach(ModbusFunction.allCases) { function in
                Text(function.title).tag(function)
              }
            }
            .labelsHidden()
            .frame(width: 180, alignment: .leading)
          }

          FieldRow(title: "起始地址") {
            Stepper(value: $store.command.startAddress.intBinding(), in: 0...65535) {
              NumericValueField(value: $store.command.startAddress.intBinding(), range: 0...65535)
            }
          }

          switch store.command.function {
          case .readCoils, .readDiscreteInputs:
            FieldRow(title: "数量") {
              Stepper(value: $store.command.quantity.intBinding(), in: 1...2000) {
                NumericValueField(value: $store.command.quantity.intBinding(), range: 1...2000)
              }
            }
          case .readHoldingRegisters, .readInputRegisters:
            FieldRow(title: "数量") {
              Stepper(value: $store.command.quantity.intBinding(), in: 1...125) {
                NumericValueField(value: $store.command.quantity.intBinding(), range: 1...125)
              }
            }
          case .writeSingleCoil:
            FieldRow(title: "写入值") {
              Picker("写入值", selection: $store.command.singleValue) {
                Text("关").tag(UInt16(0))
                Text("开").tag(UInt16(1))
              }
              .pickerStyle(.segmented)
              .labelsHidden()
              .frame(width: 160)
            }
          case .writeSingleRegister:
            FieldRow(title: "写入值") {
              Stepper(value: $store.command.singleValue.intBinding(), in: 0...65535) {
                NumericValueField(value: $store.command.singleValue.intBinding(), range: 0...65535)
              }
            }
          case .writeMultipleCoils:
            FieldRow(title: "批量值") {
              ValuesEditor(text: $store.command.valuesText)
            }
          case .writeMultipleRegisters:
            FieldRow(title: "批量值") {
              ValuesEditor(text: $store.command.valuesText)
            }
          }
        }

        Text(helpText(for: store.command.function))
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private func helpText(for function: ModbusFunction) -> String {
    switch function {
    case .readCoils:
      "读取线圈状态，数量上限 2000，响应数据按低位在前的 bit 顺序打包。"
    case .readDiscreteInputs:
      "读取离散输入，只读 bit 区，响应格式与线圈读取相同。"
    case .readHoldingRegisters:
      "读取保持寄存器，数量上限 125，每个寄存器为 2 字节大端序。"
    case .readInputRegisters:
      "读取输入寄存器，只读 word 区，响应格式与保持寄存器相同。"
    case .writeSingleCoil:
      "写单个线圈时开编码为 FF 00，关编码为 00 00。"
    case .writeSingleRegister:
      "写单个保持寄存器，响应通常回显地址和值。"
    case .writeMultipleCoils:
      "多线圈值用逗号分隔，支持 1/0、on/off、true/false。"
    case .writeMultipleRegisters:
      "多寄存器值用逗号分隔，支持十进制和 0x 前缀十六进制。"
    }
  }
}

private struct CommandOutputPanel: View {
  @Bindable var store: WorkbenchStore

  var body: some View {
    Panel(title: "生成的报文", systemImage: "terminal") {
      if let error = store.commandError {
        Label(error, systemImage: "xmark.octagon.fill")
          .foregroundStyle(.red)
          .font(.callout)
      } else if let frame = store.builtFrame {
        VStack(alignment: .leading, spacing: 16) {
          Text(frame.summary)
            .font(.callout)
            .foregroundStyle(.secondary)

          HStack(spacing: 8) {
            StatusBadge(text: store.command.transport.rawValue, kind: .neutral)
            if store.command.transport == .rtu {
              StatusBadge(text: "CRC \(HexFormatter.word(ModbusCRC.compute(Array(frame.adu.dropLast(2)))))", kind: .ok)
            } else {
              StatusBadge(text: "MBAP 长度 \(frame.adu.word(at: 4))", kind: .ok)
            }
          }

          HexBlock(title: "ADU", bytes: frame.adu, actionTitle: "复制 ADU") {
            store.copyBuiltFrame()
          }

          HexBlock(title: "PDU", bytes: frame.pdu, actionTitle: "复制 PDU") {
            store.copyPDU()
          }

          AnnotatedFrameView(
            title: "字段拆解",
            segments: FrameSegmentBuilder.command(input: store.command, frame: frame)
          )
          WarningList(warnings: frame.warnings)
        }
      } else {
        EmptyStateView(title: "尚未生成报文", systemImage: "terminal")
      }
    }
  }
}

private struct NumericValueField: View {
  @Binding var value: Int
  let range: ClosedRange<Int>

  var body: some View {
    TextField("", value: $value, format: .number)
      .textFieldStyle(.roundedBorder)
      .monospacedDigit()
      .frame(width: 92)
      .onChange(of: value) { _, newValue in
        value = min(max(newValue, range.lowerBound), range.upperBound)
      }
  }
}

private struct ValuesEditor: View {
  @Binding var text: String

  var body: some View {
    TextEditor(text: $text)
      .font(.system(.body, design: .monospaced))
      .frame(height: 52)
      .scrollContentBackground(.hidden)
      .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
          .stroke(.separator.opacity(0.45))
    }
  }
}
