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

  func testBuildMultipleCoilsPacksLeastSignificantBitFirst() throws {
    var input = CommandInput()
    input.function = .writeMultipleCoils
    input.valuesText = "1,0,1,1,0,0,0,1,1"

    let frame = try ModbusCodec.buildCommand(input)

    XCTAssertEqual(frame.payload.suffix(2), [0x8D, 0x01])
  }
}
