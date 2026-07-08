import XCTest
@testable import ModbusWorkbench

final class ModbusCodecTests: XCTestCase {
  func testBuildRTUReadHoldingRegisters() throws {
    let input = CommandInput(
      transport: .rtu,
      transactionID: 1,
      unitID: 1,
      function: .readHoldingRegisters,
      startAddress: 0,
      quantity: 10,
      singleValue: 1,
      valuesText: ""
    )

    let frame = try ModbusCodec.buildCommand(input)

    XCTAssertEqual(HexFormatter.bytes(frame.adu), "01 03 00 00 00 0A C5 CD")
    XCTAssertEqual(frame.pdu, [0x03, 0x00, 0x00, 0x00, 0x0A])
  }

  func testBuildTCPReadHoldingRegisters() throws {
    var input = CommandInput()
    input.transport = .tcp
    input.transactionID = 7
    input.unitID = 2
    input.startAddress = 100
    input.quantity = 2

    let frame = try ModbusCodec.buildCommand(input)

    XCTAssertEqual(HexFormatter.bytes(frame.adu), "00 07 00 00 00 06 02 03 00 64 00 02")
  }

  func testParseRTURegisterResponse() throws {
    let bytes = try HexFormatter.parseHexBytes("01 03 04 00 2A 42 48 EB 6D")

    let parsed = try ModbusCodec.parseFrame(
      bytes: bytes,
      transport: .rtu,
      displayMode: .unsigned16,
      assumedStartAddress: 0,
      expectedCount: 2
    )

    XCTAssertEqual(parsed.unitID, 1)
    XCTAssertEqual(parsed.functionCode, 0x03)
    XCTAssertEqual(parsed.crcIsValid, true)
    XCTAssertEqual(parsed.decodedItems.map(\.value), ["42", "16968"])
  }

  func testParseResponseSupportsMultipleLines() throws {
    let first = "01 03 04 00 2A 42 48 EB 6D"
    let second = HexFormatter.bytes(ModbusCRC.append(to: [0x01, 0x03, 0x04, 0x00, 0x2B, 0x42, 0x49]))
    let store = WorkbenchStore()

    store.responseText = "\(first)\n\(second)"
    store.expectedCountText = "2"
    store.parseResponse()

    XCTAssertNil(store.parseError)
    XCTAssertEqual(store.parsedFrames.count, 2)
    XCTAssertEqual(store.parsedFrames[0].decodedItems.map(\.value), ["42", "16968"])
    XCTAssertEqual(store.parsedFrames[1].decodedItems.map(\.value), ["43", "16969"])
    XCTAssertEqual(store.registerComparisonRows.count, 2)
    XCTAssertEqual(store.registerComparisonRows[0].values.map { $0?.value }, ["42", "43"])
  }

  func testParseTCPException() throws {
    let bytes = try HexFormatter.parseHexBytes("00 01 00 00 00 03 01 83 02")

    let parsed = try ModbusCodec.parseFrame(
      bytes: bytes,
      transport: .tcp,
      displayMode: .unsigned16,
      assumedStartAddress: 0,
      expectedCount: nil
    )

    XCTAssertTrue(parsed.isException)
    XCTAssertEqual(parsed.exceptionTitle, "非法数据地址")
    XCTAssertEqual(parsed.lengthIsValid, true)
  }

  func testFloatFormattingAvoidsScientificNotationForNormalLargeValues() throws {
    let decoded = NumberDecoder.decode(registers: [0x0000, 0x4A8F], mode: .floatCDAB)

    XCTAssertEqual(decoded.value, "4685824")
  }

  func testFloatFormattingKeepsScientificNotationForVeryLargeValues() throws {
    let bits = Float(1_200_000_000_000).bitPattern
    let decoded = NumberDecoder.decode(
      registers: [UInt16(bits >> 16), UInt16(bits & 0xFFFF)],
      mode: .floatABCD
    )

    XCTAssertTrue(decoded.value.contains("e+"))
  }

  func testRegisterRowsApplyAssumedStartAddress() throws {
    let rows = NumberDecoder.registerRows(
      startAddress: 5,
      registers: Array(repeating: UInt16(0), count: 34),
      defaultMode: .unsigned16,
      overrides: [:]
    )

    XCTAssertEqual(rows[32].address, 37)
  }

  func testRegisterDisplayPresetsPersistAndApply() throws {
    let suiteName = "ModbusWorkbenchTests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defer {
      defaults.removePersistentDomain(forName: suiteName)
    }

    let response = HexFormatter.bytes(ModbusCRC.append(to: [0x01, 0x03, 0x46] + Array(repeating: UInt8(0), count: 70)))
    let store = WorkbenchStore(userDefaults: defaults)
    store.responseText = response
    store.assumedStartAddress = 5
    store.expectedCountText = "35"
    store.parseResponse()
    store.setRegisterDisplayMode(.floatABCD, for: 5)
    store.saveCurrentRegisterDisplayPreset(named: "温度点位")

    XCTAssertEqual(store.registerDisplayPresets.count, 1)
    XCTAssertEqual(store.registerDisplayPresets.first?.summary, "起始 5-39 共 35 点位")

    let presetID = try XCTUnwrap(store.registerDisplayPresets.first?.id)
    store.assumedStartAddress = 0
    store.parseDisplayMode = .signed16
    store.registerDisplayOverrides = [:]
    store.parseResponse()

    store.applyRegisterDisplayPreset(id: presetID)

    XCTAssertEqual(store.parseDisplayMode, .unsigned16)
    XCTAssertEqual(store.assumedStartAddress, 5)
    XCTAssertEqual(store.registerDisplayOverrides[5], .floatABCD)
    XCTAssertEqual(store.registerComparisonRows.first?.mode, .floatABCD)

    let reloaded = WorkbenchStore(userDefaults: defaults)
    XCTAssertEqual(reloaded.registerDisplayPresets.map(\.name), ["温度点位"])
    XCTAssertEqual(reloaded.registerDisplayPresets.first?.startAddress, 5)
    XCTAssertEqual(reloaded.registerDisplayPresets.first?.pointCount, 35)
    XCTAssertEqual(reloaded.registerDisplayPresets.first?.overrides[5], .floatABCD)
  }

  func testRegisterDisplayPresetDeletePersists() throws {
    let suiteName = "ModbusWorkbenchTests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defer {
      defaults.removePersistentDomain(forName: suiteName)
    }

    let store = WorkbenchStore(userDefaults: defaults)
    store.setRegisterDisplayMode(.floatABCD, for: 0)
    store.saveCurrentRegisterDisplayPreset(named: "临时预设")

    let presetID = try XCTUnwrap(store.registerDisplayPresets.first?.id)
    store.deleteRegisterDisplayPreset(id: presetID)

    let reloaded = WorkbenchStore(userDefaults: defaults)
    XCTAssertTrue(reloaded.registerDisplayPresets.isEmpty)
  }

  func testBuildMultipleCoilsPacksLeastSignificantBitFirst() throws {
    var input = CommandInput()
    input.function = .writeMultipleCoils
    input.valuesText = "1,0,1,1,0,0,0,1,1"

    let frame = try ModbusCodec.buildCommand(input)

    XCTAssertEqual(frame.payload.suffix(2), [0x8D, 0x01])
  }
}
