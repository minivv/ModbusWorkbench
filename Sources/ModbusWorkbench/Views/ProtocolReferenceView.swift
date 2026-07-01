import SwiftUI

struct ProtocolReferenceView: View {
  private let readFunctions: [ModbusFunction] = [
    .readCoils,
    .readDiscreteInputs,
    .readHoldingRegisters,
    .readInputRegisters
  ]

  private let writeFunctions: [ModbusFunction] = [
    .writeSingleCoil,
    .writeSingleRegister,
    .writeMultipleCoils,
    .writeMultipleRegisters
  ]

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        HStack(alignment: .top, spacing: 16) {
          FunctionListPanel(title: "读取功能", functions: readFunctions)
            .frame(maxWidth: .infinity)
          FunctionListPanel(title: "写入功能", functions: writeFunctions)
            .frame(maxWidth: .infinity)
        }

        Panel(title: "帧结构", systemImage: "rectangle.split.3x1") {
          VStack(alignment: .leading, spacing: 12) {
            ReferenceRow(label: "RTU 请求", value: "从站地址 + 功能码 + Payload + CRC Lo + CRC Hi")
            ReferenceRow(label: "TCP 请求", value: "事务号 + 协议号 + 长度 + 从站地址 + 功能码 + Payload")
            ReferenceRow(label: "读取请求 Payload", value: "起始地址高字节 + 起始地址低字节 + 数量高字节 + 数量低字节")
            ReferenceRow(label: "读取响应 Payload", value: "Byte Count + 数据区。线圈按 bit 打包，寄存器按 2 字节一组。")
            ReferenceRow(label: "异常响应", value: "功能码最高位置 1，即原功能码 + 0x80，后面跟 1 字节异常码。")
          }
        }

        Panel(title: "数量限制", systemImage: "gauge.with.dots.needle.67percent") {
          LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 240), spacing: 14, alignment: .topLeading)],
            alignment: .leading,
            spacing: 14
          ) {
            LimitCard(title: "读线圈 / 离散输入", value: "1...2000 位", note: "响应按 bit 打包，Byte Count 后每字节包含 8 个点。")
            LimitCard(title: "读保持 / 输入寄存器", value: "1...125 个寄存器", note: "每个寄存器 2 字节，因此单帧数据区最多 250 字节。")
            LimitCard(title: "写多个线圈", value: "1...1968 位", note: "请求中包含 Byte Count 和打包后的线圈数据。")
            LimitCard(title: "写多个寄存器", value: "1...123 个寄存器", note: "请求中包含 Byte Count，数据区每个寄存器 2 字节。")
            LimitCard(title: "从站地址", value: "0...247", note: "RTU 中就是从站地址；TCP 中对应 Unit Identifier。")
          }
        }

        Panel(title: "字节序", systemImage: "arrow.left.arrow.right") {
          VStack(alignment: .leading, spacing: 12) {
            Text("Modbus 寄存器 word 使用大端序。跨多个寄存器的 32 位值因设备而异，所以解析器提供常见字节序。")
              .foregroundStyle(.secondary)
            ReferenceRow(label: "ABCD", value: "寄存器 0 高字节，寄存器 0 低字节，寄存器 1 高字节，寄存器 1 低字节")
            ReferenceRow(label: "CDAB", value: "word 交换")
            ReferenceRow(label: "BADC", value: "每个 word 内部字节交换")
            ReferenceRow(label: "DCBA", value: "完整字节反转")
          }
        }
      }
      .padding(20)
    }
  }
}

private struct FunctionListPanel: View {
  let title: String
  let functions: [ModbusFunction]

  var body: some View {
    Panel(title: title, systemImage: functions.first?.systemImage ?? "list.bullet") {
      VStack(alignment: .leading, spacing: 12) {
        ForEach(functions) { function in
          HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: function.systemImage)
              .foregroundStyle(.secondary)
              .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
              Text(function.title)
                .font(.callout.weight(.semibold))
              Text(description(for: function))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
          }
        }
      }
    }
  }

  private func description(for function: ModbusFunction) -> String {
    switch function {
    case .readCoils:
      "读取可写 bit 输出。"
    case .readDiscreteInputs:
      "读取只读 bit 输入。"
    case .readHoldingRegisters:
      "读取可写 16 位寄存器值。"
    case .readInputRegisters:
      "读取只读 16 位寄存器值。"
    case .writeSingleCoil:
      "写入一个线圈，开为 FF00，关为 0000。"
    case .writeSingleRegister:
      "写入一个 16 位保持寄存器。"
    case .writeMultipleCoils:
      "写入打包线圈值，最低位在前。"
    case .writeMultipleRegisters:
      "写入多个 16 位保持寄存器。"
    }
  }
}

private struct LimitCard: View {
  let title: String
  let value: String
  let note: String

  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(title)
        .font(.callout.weight(.semibold))
      Text(value)
        .font(.system(.title3, design: .rounded).weight(.semibold))
        .monospacedDigit()
      Text(note)
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
  }
}

private struct ReferenceRow: View {
  let label: String
  let value: String

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 12) {
      Text(label)
        .font(.callout.weight(.semibold))
        .frame(width: 140, alignment: .leading)
      Text(value)
        .font(.callout)
        .foregroundStyle(.secondary)
        .textSelection(.enabled)
        .fixedSize(horizontal: false, vertical: true)
    }
  }
}
