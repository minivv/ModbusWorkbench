import Foundation

enum ModbusCodec {
  static func buildCommand(_ input: CommandInput) throws -> BuiltFrame {
    let payload = try payload(for: input)
    let pdu = [input.function.rawValue] + payload
    let adu: [UInt8]

    switch input.transport {
    case .rtu:
      adu = ModbusCRC.append(to: [input.unitID] + pdu)
    case .tcp:
      let length = UInt16(pdu.count + 1)
      adu = [
        UInt8(input.transactionID >> 8), UInt8(input.transactionID & 0x00FF),
        0x00, 0x00,
        UInt8(length >> 8), UInt8(length & 0x00FF),
        input.unitID
      ] + pdu
    }

    return BuiltFrame(
      adu: adu,
      pdu: pdu,
      payload: payload,
      summary: commandSummary(input, payload: payload),
      warnings: commandWarnings(input)
    )
  }

  static func parseFrame(
    bytes: [UInt8],
    transport: TransportMode,
    displayMode: DataDisplayMode,
    assumedStartAddress: Int,
    expectedCount: Int?
  ) throws -> ParsedFrame {
    switch transport {
    case .rtu:
      try parseRTU(bytes: bytes, displayMode: displayMode, assumedStartAddress: assumedStartAddress, expectedCount: expectedCount)
    case .tcp:
      try parseTCP(bytes: bytes, displayMode: displayMode, assumedStartAddress: assumedStartAddress, expectedCount: expectedCount)
    }
  }

  private static func parseRTU(
    bytes: [UInt8],
    displayMode: DataDisplayMode,
    assumedStartAddress: Int,
    expectedCount: Int?
  ) throws -> ParsedFrame {
    guard bytes.count >= 5 else {
      throw ModbusCodecError.frameTooShort("RTU 响应至少需要地址、功能码、数据和 2 字节 CRC。")
    }

    let body = Array(bytes.dropLast(2))
    let expectedCRC = ModbusCRC.readLittleEndian(from: bytes, at: bytes.count - 2)
    let actualCRC = ModbusCRC.compute(body)
    let unitID = bytes[0]
    let functionCode = bytes[1]
    let payload = Array(body.dropFirst(2))

    var warnings: [String] = []
    if expectedCRC != actualCRC {
      warnings.append("CRC 校验不通过，可能是帧不完整、字节顺序错误或传输错误。")
    }

    let decode = decodePayload(
      functionCode: functionCode,
      payload: payload,
      displayMode: displayMode,
      assumedStartAddress: assumedStartAddress,
      expectedCount: expectedCount,
      warnings: &warnings
    )

    return ParsedFrame(
      rawBytes: bytes,
      transport: .rtu,
      transactionID: nil,
      protocolID: nil,
      length: nil,
      unitID: unitID,
      functionCode: functionCode,
      functionName: ModbusFunction.label(for: functionCode & 0x7F),
      isException: decode.isException,
      exceptionTitle: decode.exceptionTitle,
      exceptionDescription: decode.exceptionDescription,
      payload: payload,
      dataBytes: decode.dataBytes,
      crcExpected: expectedCRC,
      crcActual: actualCRC,
      crcIsValid: expectedCRC == actualCRC,
      lengthIsValid: nil,
      warnings: warnings,
      decodedItems: decode.items
    )
  }

  private static func parseTCP(
    bytes: [UInt8],
    displayMode: DataDisplayMode,
    assumedStartAddress: Int,
    expectedCount: Int?
  ) throws -> ParsedFrame {
    guard bytes.count >= 9 else {
      throw ModbusCodecError.frameTooShort("TCP 响应至少需要 7 字节 MBAP、功能码和数据。")
    }

    let transactionID = bytes.word(at: 0)
    let protocolID = bytes.word(at: 2)
    let length = bytes.word(at: 4)
    let unitID = bytes[6]
    let functionCode = bytes[7]
    let payload = Array(bytes.dropFirst(8))
    let declaredTotal = Int(length) + 6
    let lengthIsValid = declaredTotal == bytes.count
    var warnings: [String] = []

    if protocolID != 0 {
      warnings.append("Protocol ID 不是 0，标准 Modbus TCP 应为 0。")
    }
    if !lengthIsValid {
      warnings.append("MBAP Length 与实际帧长度不一致，声明总长 \(declaredTotal) 字节，实际 \(bytes.count) 字节。")
    }

    let decode = decodePayload(
      functionCode: functionCode,
      payload: payload,
      displayMode: displayMode,
      assumedStartAddress: assumedStartAddress,
      expectedCount: expectedCount,
      warnings: &warnings
    )

    return ParsedFrame(
      rawBytes: bytes,
      transport: .tcp,
      transactionID: transactionID,
      protocolID: protocolID,
      length: length,
      unitID: unitID,
      functionCode: functionCode,
      functionName: ModbusFunction.label(for: functionCode & 0x7F),
      isException: decode.isException,
      exceptionTitle: decode.exceptionTitle,
      exceptionDescription: decode.exceptionDescription,
      payload: payload,
      dataBytes: decode.dataBytes,
      crcExpected: nil,
      crcActual: nil,
      crcIsValid: nil,
      lengthIsValid: lengthIsValid,
      warnings: warnings,
      decodedItems: decode.items
    )
  }

  private static func payload(for input: CommandInput) throws -> [UInt8] {
    switch input.function {
    case .readCoils, .readDiscreteInputs, .readHoldingRegisters, .readInputRegisters:
      try validateQuantity(input.quantity, min: 1, max: input.function.usesBits ? 2000 : 125)
      return [
        UInt8(input.startAddress >> 8),
        UInt8(input.startAddress & 0x00FF),
        UInt8(input.quantity >> 8),
        UInt8(input.quantity & 0x00FF)
      ]
    case .writeSingleCoil:
      guard input.singleValue == 0 || input.singleValue == 1 else {
        throw ModbusCodecError.invalidValue("单线圈写入值只能是 0 或 1。")
      }
      let value: UInt16 = input.singleValue == 1 ? 0xFF00 : 0x0000
      return [
        UInt8(input.startAddress >> 8),
        UInt8(input.startAddress & 0x00FF),
        UInt8(value >> 8),
        UInt8(value & 0x00FF)
      ]
    case .writeSingleRegister:
      return [
        UInt8(input.startAddress >> 8),
        UInt8(input.startAddress & 0x00FF),
        UInt8(input.singleValue >> 8),
        UInt8(input.singleValue & 0x00FF)
      ]
    case .writeMultipleCoils:
      let bits = try parseBitValues(input.valuesText)
      guard !bits.isEmpty, bits.count <= 1968 else {
        throw ModbusCodecError.invalidQuantity("多线圈写入数量范围是 1...1968。")
      }
      let packed = packBits(bits)
      return [
        UInt8(input.startAddress >> 8),
        UInt8(input.startAddress & 0x00FF),
        UInt8(UInt16(bits.count) >> 8),
        UInt8(UInt16(bits.count) & 0x00FF),
        UInt8(packed.count)
      ] + packed
    case .writeMultipleRegisters:
      let registers = try parseRegisterValues(input.valuesText)
      guard !registers.isEmpty, registers.count <= 123 else {
        throw ModbusCodecError.invalidQuantity("多寄存器写入数量范围是 1...123。")
      }
      let registerBytes = registers.flatMap { value in
        [UInt8(value >> 8), UInt8(value & 0x00FF)]
      }
      return [
        UInt8(input.startAddress >> 8),
        UInt8(input.startAddress & 0x00FF),
        UInt8(UInt16(registers.count) >> 8),
        UInt8(UInt16(registers.count) & 0x00FF),
        UInt8(registerBytes.count)
      ] + registerBytes
    }
  }

  private static func validateQuantity(_ value: UInt16, min: UInt16, max: UInt16) throws {
    guard value >= min, value <= max else {
      throw ModbusCodecError.invalidQuantity("数量范围是 \(min)...\(max)。")
    }
  }

  private static func parseRegisterValues(_ text: String) throws -> [UInt16] {
    try valueTokens(text).map { token in
      let value = try parseIntegerToken(token)
      guard value >= 0, value <= 0xFFFF else {
        throw ModbusCodecError.invalidValue("寄存器值超出 0...65535：\(token)")
      }
      return UInt16(value)
    }
  }

  private static func parseBitValues(_ text: String) throws -> [Bool] {
    try valueTokens(text).map { token in
      switch token.lowercased() {
      case "1", "true", "on":
        true
      case "0", "false", "off":
        false
      default:
        throw ModbusCodecError.invalidValue("线圈值只能是 0/1、true/false 或 on/off：\(token)")
      }
    }
  }

  private static func valueTokens(_ text: String) throws -> [String] {
    let tokens = text
      .replacingOccurrences(of: "\n", with: ",")
      .replacingOccurrences(of: ";", with: ",")
      .split(separator: ",")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
    guard !tokens.isEmpty else {
      throw ModbusCodecError.invalidValue("请输入至少一个值。")
    }
    return tokens
  }

  private static func parseIntegerToken(_ token: String) throws -> Int {
    let lower = token.lowercased()
    if lower.hasPrefix("0x") {
      guard let value = Int(lower.dropFirst(2), radix: 16) else {
        throw ModbusCodecError.invalidValue("无效数值：\(token)")
      }
      return value
    }
    guard let value = Int(lower) else {
      throw ModbusCodecError.invalidValue("无效数值：\(token)")
    }
    return value
  }

  private static func packBits(_ bits: [Bool]) -> [UInt8] {
    var bytes = Array(repeating: UInt8(0), count: Int(ceil(Double(bits.count) / 8.0)))
    for (index, bit) in bits.enumerated() where bit {
      bytes[index / 8] |= UInt8(1 << UInt8(index % 8))
    }
    return bytes
  }

  private static func commandSummary(_ input: CommandInput, payload: [UInt8]) -> String {
    switch input.function {
    case .readCoils, .readDiscreteInputs, .readHoldingRegisters, .readInputRegisters:
      return "\(input.function.shortTitle)，从站地址 \(input.unitID)，起始地址 \(input.startAddress)，数量 \(input.quantity)"
    case .writeSingleCoil:
      return "写单个线圈，从站地址 \(input.unitID)，地址 \(input.startAddress)，值 \(input.singleValue == 1 ? "开" : "关")"
    case .writeSingleRegister:
      return "写单个寄存器，从站地址 \(input.unitID)，地址 \(input.startAddress)，值 \(input.singleValue)"
    case .writeMultipleCoils:
      let quantity = Int(payload.word(at: 2))
      return "写多个线圈，从站地址 \(input.unitID)，起始地址 \(input.startAddress)，数量 \(quantity)"
    case .writeMultipleRegisters:
      let quantity = Int(payload.word(at: 2))
      return "写多个寄存器，从站地址 \(input.unitID)，起始地址 \(input.startAddress)，数量 \(quantity)"
    }
  }

  private static func commandWarnings(_ input: CommandInput) -> [String] {
    var warnings: [String] = []
    if input.transport == .tcp {
      warnings.append("TCP 报文包含 MBAP 头，不带 RTU CRC。")
    }
    return warnings
  }

  private struct PayloadDecode {
    var isException: Bool
    var exceptionTitle: String?
    var exceptionDescription: String?
    var dataBytes: [UInt8]
    var items: [DecodedItem]
  }

  private static func decodePayload(
    functionCode: UInt8,
    payload: [UInt8],
    displayMode: DataDisplayMode,
    assumedStartAddress: Int,
    expectedCount: Int?,
    warnings: inout [String]
  ) -> PayloadDecode {
    if (functionCode & 0x80) != 0 {
      let code = payload.first ?? 0
      let known = ModbusExceptionCode(rawValue: code)
      return PayloadDecode(
        isException: true,
        exceptionTitle: known?.title ?? "异常 0x\(HexFormatter.byte(code))",
        exceptionDescription: known?.description ?? "设备返回了非标准异常码。",
        dataBytes: payload,
        items: []
      )
    }

    guard let function = ModbusFunction(rawValue: functionCode) else {
      warnings.append("未知或未内置解析的功能码，仅显示原始载荷。")
      return PayloadDecode(isException: false, exceptionTitle: nil, exceptionDescription: nil, dataBytes: payload, items: [])
    }

    switch function {
    case .readCoils, .readDiscreteInputs:
      guard let byteCount = payload.first else {
        warnings.append("响应缺少 Byte Count。")
        return PayloadDecode(isException: false, exceptionTitle: nil, exceptionDescription: nil, dataBytes: [], items: [])
      }
      let data = Array(payload.dropFirst())
      if data.count != Int(byteCount) {
        warnings.append("Byte Count 为 \(byteCount)，实际数据 \(data.count) 字节。")
      }
      let items = NumberDecoder.bitItems(startAddress: assumedStartAddress, bytes: data, count: expectedCount)
      return PayloadDecode(isException: false, exceptionTitle: nil, exceptionDescription: nil, dataBytes: data, items: items)
    case .readHoldingRegisters, .readInputRegisters:
      guard let byteCount = payload.first else {
        warnings.append("响应缺少 Byte Count。")
        return PayloadDecode(isException: false, exceptionTitle: nil, exceptionDescription: nil, dataBytes: [], items: [])
      }
      let data = Array(payload.dropFirst())
      if data.count != Int(byteCount) {
        warnings.append("Byte Count 为 \(byteCount)，实际数据 \(data.count) 字节。")
      }
      if !data.count.isMultiple(of: 2) {
        warnings.append("寄存器数据字节数不是偶数，最后一个字节无法组成完整寄存器。")
      }
      let registers = stride(from: 0, to: data.count - (data.count % 2), by: 2).map { index in
        (UInt16(data[index]) << 8) | UInt16(data[index + 1])
      }
      let items = NumberDecoder.registerItems(
        startAddress: assumedStartAddress,
        registers: registers,
        displayMode: displayMode
      )
      return PayloadDecode(isException: false, exceptionTitle: nil, exceptionDescription: nil, dataBytes: data, items: items)
    case .writeSingleCoil, .writeSingleRegister, .writeMultipleCoils, .writeMultipleRegisters:
      let items = acknowledgeItems(function: function, payload: payload, warnings: &warnings)
      return PayloadDecode(isException: false, exceptionTitle: nil, exceptionDescription: nil, dataBytes: payload, items: items)
    }
  }

  private static func acknowledgeItems(
    function: ModbusFunction,
    payload: [UInt8],
    warnings: inout [String]
  ) -> [DecodedItem] {
    guard payload.count >= 4 else {
      warnings.append("写入响应长度不足，正常应回显地址和值或数量。")
      return []
    }

    let address = Int(payload.word(at: 0))
    let value = payload.word(at: 2)
    let label: String
    let displayValue: String

    switch function {
    case .writeSingleCoil:
      label = "线圈 \(address)"
      displayValue = value == 0xFF00 ? "开" : value == 0x0000 ? "关" : "0x\(HexFormatter.word(value))"
    case .writeSingleRegister:
      label = "寄存器 \(address)"
      displayValue = "\(value)"
    case .writeMultipleCoils:
      label = "线圈起始 \(address)"
      displayValue = "\(value) 个线圈"
    case .writeMultipleRegisters:
      label = "寄存器起始 \(address)"
      displayValue = "\(value) 个寄存器"
    case .readCoils, .readDiscreteInputs, .readHoldingRegisters, .readInputRegisters:
      label = "确认"
      displayValue = "\(value)"
    }

    return [
      DecodedItem(
        address: address,
        label: label,
        raw: HexFormatter.bytes(payload),
        value: displayValue,
        note: "回显"
      )
    ]
  }
}
