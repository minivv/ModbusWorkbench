import SwiftUI

struct ResponseParserView: View {
  @Bindable var store: WorkbenchStore

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Text("粘贴采集到的响应帧，查看字段、校验和数据值。")
              .foregroundStyle(.secondary)
            Text("输入支持空格、逗号、换行、0x 前缀或紧凑十六进制。")
              .font(.caption)
              .foregroundStyle(.tertiary)
          }
          Spacer()
        }

        HStack(alignment: .top, spacing: 16) {
          ParserInputPanel(store: store, minHeight: topPanelMinHeight)
            .frame(maxWidth: .infinity)

          ParserOptionsPanel(store: store, minHeight: topPanelMinHeight)
            .frame(width: 300)
        }

        ParserResultPanel(store: store)
          .frame(maxWidth: .infinity)
      }
      .padding(20)
    }
    .onChange(of: store.parserTransport) { _, _ in store.parseResponse() }
    .onChange(of: store.responseText) { _, _ in store.parseResponse() }
    .onChange(of: store.parseDisplayMode) { _, _ in store.parseResponse() }
    .onChange(of: store.assumedStartAddress) { _, _ in store.parseResponse() }
    .onChange(of: store.expectedCountText) { _, _ in store.parseResponse() }
  }

  private var topPanelMinHeight: CGFloat { 190 }
}

private struct ParserInputPanel: View {
  @Bindable var store: WorkbenchStore
  let minHeight: CGFloat

  var body: some View {
    Panel(title: "响应输入", systemImage: "square.and.pencil", minHeight: minHeight) {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .center, spacing: 12) {
          Picker("传输方式", selection: $store.parserTransport) {
            ForEach(TransportMode.allCases) { mode in
              Text(mode.rawValue).tag(mode)
            }
          }
          .pickerStyle(.segmented)
          .frame(width: 180)

          Spacer(minLength: 12)

          Text("载入示例")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)

          HStack(spacing: 6) {
            Button("寄存器") { store.loadRegisterExample() }
            Button("浮点") { store.loadFloatExample() }
            Button("线圈") { store.loadCoilExample() }
            Button("异常") { store.loadExceptionExample() }
          }
          .buttonStyle(.bordered)
          .controlSize(.small)
        }

        TextEditor(text: $store.responseText)
          .font(.system(.body, design: .monospaced))
          .frame(height: 68)
          .scrollContentBackground(.hidden)
          .padding(2)
          .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
          .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
              .stroke(.separator.opacity(0.45))
          }
      }
    }
  }
}

private struct ParserOptionsPanel: View {
  @Bindable var store: WorkbenchStore
  let minHeight: CGFloat

  var body: some View {
    Panel(title: "解析选项", systemImage: "slider.horizontal.3", minHeight: minHeight) {
      Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
        FieldRow(title: "起始地址") {
          Stepper(value: $store.assumedStartAddress, in: 0...65535) {
            TextField("", value: $store.assumedStartAddress, format: .number)
              .textFieldStyle(.roundedBorder)
              .monospacedDigit()
              .frame(width: 92)
          }
        }

        FieldRow(title: "数量") {
          Stepper(value: expectedCountBinding, in: 1...65535) {
            TextField("自动", text: $store.expectedCountText)
              .textFieldStyle(.roundedBorder)
              .monospacedDigit()
              .frame(width: 92)
          }
        }

        FieldRow(title: "显示方式") {
          Picker("显示方式", selection: $store.parseDisplayMode) {
            ForEach(DataDisplayMode.allCases) { mode in
              Text(mode.rawValue).tag(mode)
            }
          }
          .labelsHidden()
          .frame(width: 160)
        }
      }

      Text("起始地址和数量不参与 CRC 或 MBAP 校验。")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }

  private var expectedCountBinding: Binding<Int> {
    Binding(
      get: {
        let text = store.expectedCountText.trimmingCharacters(in: .whitespacesAndNewlines)
        return Int(text).map { min(max($0, 1), 65535) } ?? 1
      },
      set: { newValue in
        store.expectedCountText = "\(min(max(newValue, 1), 65535))"
      }
    )
  }
}

private struct ParserResultPanel: View {
  @Bindable var store: WorkbenchStore

  var body: some View {
    Panel(title: "解析结果", systemImage: "waveform.path.ecg") {
      if let error = store.parseError {
        Label(error, systemImage: "xmark.octagon.fill")
          .foregroundStyle(.red)
          .font(.callout)
      } else if let frame = store.parsedFrame {
        VStack(alignment: .leading, spacing: 16) {
          ParserStatusRow(frame: frame)

          if frame.isException {
            ExceptionView(frame: frame)
          }

          AnnotatedFrameView(
            title: "响应帧分段",
            segments: FrameSegmentBuilder.parsed(frame: frame)
          )

          WarningList(warnings: frame.warnings)

          VStack(alignment: .leading, spacing: 10) {
            Text("解析值")
              .font(.subheadline.weight(.semibold))
            DecodedItemsTable(store: store, frame: frame)
          }
        }
      } else {
        EmptyStateView(title: "粘贴响应帧后开始解析", systemImage: "doc.text.magnifyingglass")
      }
    }
  }
}

private struct ParserStatusRow: View {
  let frame: ParsedFrame

  var body: some View {
    HStack(spacing: 8) {
      StatusBadge(text: frame.transport.rawValue, kind: .neutral)

      if let crcIsValid = frame.crcIsValid {
        StatusBadge(text: crcIsValid ? "CRC 正常" : "CRC 失败", kind: crcIsValid ? .ok : .error)
      }

      if let lengthIsValid = frame.lengthIsValid {
        StatusBadge(text: lengthIsValid ? "长度正常" : "长度不一致", kind: lengthIsValid ? .ok : .warning)
      }

      if frame.isException {
        StatusBadge(text: frame.exceptionTitle ?? "异常", kind: .error)
      }
    }
  }
}

private struct ExceptionView: View {
  let frame: ParsedFrame

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Label(frame.exceptionTitle ?? "异常", systemImage: "xmark.octagon.fill")
        .font(.headline)
        .foregroundStyle(.red)
      Text(frame.exceptionDescription ?? "")
        .font(.callout)
        .foregroundStyle(.secondary)
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .stroke(.red.opacity(0.25))
    }
  }
}
