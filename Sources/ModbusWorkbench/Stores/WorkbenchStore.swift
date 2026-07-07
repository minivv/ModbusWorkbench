import AppKit
import Combine
import Foundation

final class WorkbenchStore: ObservableObject {
  @Published var command = CommandInput()
  @Published var builtFrame: BuiltFrame?
  @Published var commandError: String?

  @Published var parserTransport: TransportMode = .rtu
  @Published var responseText = "01 03 04 00 2A 42 48 EB 6D"
  @Published var parseDisplayMode: DataDisplayMode = .unsigned16
  @Published var registerDisplayOverrides: [Int: DataDisplayMode] = [:]
  @Published var assumedStartAddress: Int = 0
  @Published var expectedCountText = "2"
  @Published var parsedFrames: [ParsedFrame] = []
  @Published var registerComparisonRows: [RegisterComparisonRow] = []
  @Published var parseError: String?

  var parsedFrame: ParsedFrame? {
    parsedFrames.first
  }

  init() {
    buildCommand()
    parseResponse()
  }

  func buildCommand() {
    do {
      builtFrame = try ModbusCodec.buildCommand(command)
      commandError = nil
    } catch {
      builtFrame = nil
      commandError = error.localizedDescription
    }
  }

  func parseResponse() {
    do {
      let expectedCount = Int(expectedCountText.trimmingCharacters(in: .whitespacesAndNewlines))
      let frames = try responseLines().enumerated().map { index, line in
        do {
          let bytes = try HexFormatter.parseHexBytes(line)
          return try ModbusCodec.parseFrame(
            bytes: bytes,
            transport: parserTransport,
            displayMode: parseDisplayMode,
            assumedStartAddress: assumedStartAddress,
            expectedCount: expectedCount
          )
        } catch {
          throw ModbusCodecError.invalidValue("第 \(index + 1) 条：\(error.localizedDescription)")
        }
      }
      parsedFrames = frames
      rebuildRegisterComparisonRows()
      parseError = nil
    } catch {
      parsedFrames = []
      registerComparisonRows = []
      parseError = error.localizedDescription
    }
  }

  func setRegisterDisplayMode(_ mode: DataDisplayMode, for address: Int) {
    if mode == parseDisplayMode {
      registerDisplayOverrides.removeValue(forKey: address)
    } else {
      registerDisplayOverrides[address] = mode
    }
    rebuildRegisterComparisonRows()
  }

  func copyBuiltFrame() {
    guard let builtFrame else { return }
    copy(HexFormatter.bytes(builtFrame.adu))
  }

  func copyPDU() {
    guard let builtFrame else { return }
    copy(HexFormatter.bytes(builtFrame.pdu))
  }

  func copyParsedPayload() {
    guard !parsedFrames.isEmpty else { return }
    copy(parsedFrames.map { HexFormatter.bytes($0.payload) }.joined(separator: "\n"))
  }

  func loadRegisterExample() {
    parserTransport = .rtu
    responseText = "01 03 04 00 2A 42 48 EB 6D"
    parseDisplayMode = .unsigned16
    registerDisplayOverrides = [:]
    assumedStartAddress = 0
    expectedCountText = "2"
    parseResponse()
  }

  func loadFloatExample() {
    parserTransport = .rtu
    responseText = "01 03 04 42 48 00 00 6E 5D"
    parseDisplayMode = .floatABCD
    registerDisplayOverrides = [:]
    assumedStartAddress = 0
    expectedCountText = "2"
    parseResponse()
  }

  func loadCoilExample() {
    parserTransport = .rtu
    responseText = "01 01 02 CD 01 2C AC"
    parseDisplayMode = .unsigned16
    registerDisplayOverrides = [:]
    assumedStartAddress = 0
    expectedCountText = "10"
    parseResponse()
  }

  func loadExceptionExample() {
    parserTransport = .tcp
    responseText = "00 01 00 00 00 03 01 83 02"
    parseDisplayMode = .unsigned16
    registerDisplayOverrides = [:]
    assumedStartAddress = 0
    expectedCountText = ""
    parseResponse()
  }

  private func copy(_ text: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
  }

  private func responseLines() throws -> [String] {
    let lines = responseText
      .components(separatedBy: .newlines)
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
    guard !lines.isEmpty else {
      throw ModbusCodecError.emptyInput
    }
    return lines
  }

  private func rebuildRegisterComparisonRows() {
    guard !parsedFrames.isEmpty, parsedFrames.allSatisfy({ $0.isRegisterRead }) else {
      registerComparisonRows = []
      return
    }

    let rowsByFrame = parsedFrames.map { frame in
      NumberDecoder.registerRows(
        startAddress: assumedStartAddress,
        registers: frame.registerValues,
        defaultMode: parseDisplayMode,
        overrides: registerDisplayOverrides
      )
    }
    let rows = rowsByFrame.first ?? []
    let rowLookupByFrame = rowsByFrame.map { rows in
      Dictionary(uniqueKeysWithValues: rows.map { ($0.address, $0) })
    }

    registerComparisonRows = rows.map { row in
      RegisterComparisonRow(
        address: row.address,
        span: row.span,
        mode: row.mode,
        raw: row.raw,
        values: rowLookupByFrame.map { $0[row.address] }
      )
    }
  }
}
