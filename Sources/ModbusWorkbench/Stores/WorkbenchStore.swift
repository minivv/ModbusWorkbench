import AppKit
import Foundation
import Observation

@Observable
final class WorkbenchStore {
  var selection: AppSection = .builder
  var command = CommandInput()
  var builtFrame: BuiltFrame?
  var commandError: String?

  var parserTransport: TransportMode = .rtu
  var responseText = "01 03 04 00 2A 42 48 EB 6D"
  var parseDisplayMode: DataDisplayMode = .unsigned16
  var registerDisplayOverrides: [Int: DataDisplayMode] = [:]
  var assumedStartAddress: Int = 0
  var expectedCountText = "2"
  var parsedFrame: ParsedFrame?
  var parseError: String?

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
      let bytes = try HexFormatter.parseHexBytes(responseText)
      parsedFrame = try ModbusCodec.parseFrame(
        bytes: bytes,
        transport: parserTransport,
        displayMode: parseDisplayMode,
        assumedStartAddress: assumedStartAddress,
        expectedCount: Int(expectedCountText.trimmingCharacters(in: .whitespacesAndNewlines))
      )
      parseError = nil
    } catch {
      parsedFrame = nil
      parseError = error.localizedDescription
    }
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
    guard let parsedFrame else { return }
    copy(HexFormatter.bytes(parsedFrame.payload))
  }

  func loadRegisterExample() {
    selection = .parser
    parserTransport = .rtu
    responseText = "01 03 04 00 2A 42 48 EB 6D"
    parseDisplayMode = .unsigned16
    registerDisplayOverrides = [:]
    assumedStartAddress = 0
    expectedCountText = "2"
    parseResponse()
  }

  func loadFloatExample() {
    selection = .parser
    parserTransport = .rtu
    responseText = "01 03 04 42 48 00 00 6E 5D"
    parseDisplayMode = .floatABCD
    registerDisplayOverrides = [:]
    assumedStartAddress = 0
    expectedCountText = "2"
    parseResponse()
  }

  func loadCoilExample() {
    selection = .parser
    parserTransport = .rtu
    responseText = "01 01 02 CD 01 2C AC"
    parseDisplayMode = .unsigned16
    registerDisplayOverrides = [:]
    assumedStartAddress = 0
    expectedCountText = "10"
    parseResponse()
  }

  func loadExceptionExample() {
    selection = .parser
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
}
