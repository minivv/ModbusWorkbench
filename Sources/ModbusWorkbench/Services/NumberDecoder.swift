import Foundation

enum NumberDecoder {
  static func registerRows(
    startAddress: Int,
    registers: [UInt16],
    defaultMode: DataDisplayMode,
    overrides: [Int: DataDisplayMode]
  ) -> [RegisterDecodeRow] {
    var rows: [RegisterDecodeRow] = []
    var index = 0

    while index < registers.count {
      let address = startAddress + index
      let mode = overrides[address] ?? defaultMode
      let available = registers.count - index
      let span = min(mode.wordCount, available)
      let values = Array(registers[index..<(index + span)])
      let decoded = decode(registers: values, mode: mode)

      rows.append(
        RegisterDecodeRow(
          address: address,
          span: span,
          mode: mode,
          raw: decoded.raw,
          value: decoded.value,
          note: decoded.note
        )
      )

      index += max(span, 1)
    }

    return rows
  }

  static func decode(registers: [UInt16], mode: DataDisplayMode) -> (raw: String, value: String, note: String) {
    let raw = registers.map { "0x\(HexFormatter.word($0))" }.joined(separator: " ")

    switch mode {
    case .unsigned16:
      guard let first = registers.first else {
        return (raw, "-", "无数据")
      }
      return (raw, "\(first)", mode.rawValue)
    case .signed16:
      guard let first = registers.first else {
        return (raw, "-", "无数据")
      }
      return (raw, "\(Int16(bitPattern: first))", mode.rawValue)
    case .unsigned32ABCD, .unsigned32CDAB, .unsigned32BADC, .unsigned32DCBA,
         .signed32ABCD, .signed32CDAB, .signed32BADC, .signed32DCBA,
         .floatABCD, .floatCDAB, .floatBADC, .floatDCBA:
      guard registers.count >= 2 else {
        return (raw, "数据不足", "需要 2 个寄存器")
      }

      let bytes = reorderedBytes32(first: registers[0], second: registers[1], mode: mode)
      let unsigned = UInt32(unsignedInteger(from: bytes))
      let value: String

      switch mode {
      case .unsigned32ABCD, .unsigned32CDAB, .unsigned32BADC, .unsigned32DCBA:
        value = "\(unsigned)"
      case .signed32ABCD, .signed32CDAB, .signed32BADC, .signed32DCBA:
        value = "\(Int32(bitPattern: unsigned))"
      case .floatABCD, .floatCDAB, .floatBADC, .floatDCBA:
        value = formatFloat(Float(bitPattern: unsigned))
      case .unsigned16, .signed16,
           .unsigned64ABCDEFGH, .unsigned64GHEFCDAB, .unsigned64BADCFEHG, .unsigned64HGFEDCBA,
           .signed64ABCDEFGH, .signed64GHEFCDAB, .signed64BADCFEHG, .signed64HGFEDCBA,
           .doubleABCDEFGH, .doubleGHEFCDAB, .doubleBADCFEHG, .doubleHGFEDCBA:
        value = "\(unsigned)"
      }

      return (raw, value, mode.rawValue)
    case .unsigned64ABCDEFGH, .unsigned64GHEFCDAB, .unsigned64BADCFEHG, .unsigned64HGFEDCBA,
         .signed64ABCDEFGH, .signed64GHEFCDAB, .signed64BADCFEHG, .signed64HGFEDCBA,
         .doubleABCDEFGH, .doubleGHEFCDAB, .doubleBADCFEHG, .doubleHGFEDCBA:
      guard registers.count >= 4 else {
        return (raw, "数据不足", "需要 4 个寄存器")
      }

      let bytes = reorderedBytes64(registers: Array(registers.prefix(4)), mode: mode)
      let unsigned = unsignedInteger(from: bytes)
      let value: String

      switch mode {
      case .unsigned64ABCDEFGH, .unsigned64GHEFCDAB, .unsigned64BADCFEHG, .unsigned64HGFEDCBA:
        value = "\(unsigned)"
      case .signed64ABCDEFGH, .signed64GHEFCDAB, .signed64BADCFEHG, .signed64HGFEDCBA:
        value = "\(Int64(bitPattern: unsigned))"
      case .doubleABCDEFGH, .doubleGHEFCDAB, .doubleBADCFEHG, .doubleHGFEDCBA:
        value = formatDouble(Double(bitPattern: unsigned))
      case .unsigned16, .signed16,
           .unsigned32ABCD, .unsigned32CDAB, .unsigned32BADC, .unsigned32DCBA,
           .signed32ABCD, .signed32CDAB, .signed32BADC, .signed32DCBA,
           .floatABCD, .floatCDAB, .floatBADC, .floatDCBA:
        value = "\(unsigned)"
      }

      return (raw, value, mode.rawValue)
    }
  }

  static func registerItems(
    startAddress: Int,
    registers: [UInt16],
    displayMode: DataDisplayMode
  ) -> [DecodedItem] {
    switch displayMode {
    case .unsigned16:
      return registers.enumerated().map { offset, value in
        DecodedItem(
          address: startAddress + offset,
          label: "寄存器 \(startAddress + offset)",
          raw: "0x\(HexFormatter.word(value))",
          value: "\(value)",
          note: displayMode.rawValue
        )
      }
    case .signed16:
      return registers.enumerated().map { offset, value in
        DecodedItem(
          address: startAddress + offset,
          label: "寄存器 \(startAddress + offset)",
          raw: "0x\(HexFormatter.word(value))",
          value: "\(Int16(bitPattern: value))",
          note: displayMode.rawValue
        )
      }
    case .unsigned32ABCD, .unsigned32CDAB, .unsigned32BADC, .unsigned32DCBA,
         .signed32ABCD, .signed32CDAB, .signed32BADC, .signed32DCBA,
         .floatABCD, .floatCDAB, .floatBADC, .floatDCBA,
         .unsigned64ABCDEFGH, .unsigned64GHEFCDAB, .unsigned64BADCFEHG, .unsigned64HGFEDCBA,
         .signed64ABCDEFGH, .signed64GHEFCDAB, .signed64BADCFEHG, .signed64HGFEDCBA,
         .doubleABCDEFGH, .doubleGHEFCDAB, .doubleBADCFEHG, .doubleHGFEDCBA:
      return groupedRegisterItems(startAddress: startAddress, registers: registers, displayMode: displayMode)
    }
  }

  private static func groupedRegisterItems(
    startAddress: Int,
    registers: [UInt16],
    displayMode: DataDisplayMode
  ) -> [DecodedItem] {
    let step = displayMode.wordCount
    let completeCount = registers.count - (registers.count % step)

    return stride(from: 0, to: completeCount, by: step).map { offset in
      let values = Array(registers[offset..<(offset + step)])
      let decoded = decode(registers: values, mode: displayMode)
      let endAddress = startAddress + offset + step - 1

      return DecodedItem(
        address: startAddress + offset,
        label: "寄存器 \(startAddress + offset)-\(endAddress)",
        raw: decoded.raw,
        value: decoded.value,
        note: displayMode.rawValue
      )
    }
  }

  private static func reorderedBytes32(first: UInt16, second: UInt16, mode: DataDisplayMode) -> [UInt8] {
    let a = UInt8(first >> 8)
    let b = UInt8(first & 0x00FF)
    let c = UInt8(second >> 8)
    let d = UInt8(second & 0x00FF)

    switch mode {
    case .unsigned32ABCD, .signed32ABCD, .floatABCD:
      return [a, b, c, d]
    case .unsigned32CDAB, .signed32CDAB, .floatCDAB:
      return [c, d, a, b]
    case .unsigned32BADC, .signed32BADC, .floatBADC:
      return [b, a, d, c]
    case .unsigned32DCBA, .signed32DCBA, .floatDCBA:
      return [d, c, b, a]
    case .unsigned16, .signed16,
         .unsigned64ABCDEFGH, .unsigned64GHEFCDAB, .unsigned64BADCFEHG, .unsigned64HGFEDCBA,
         .signed64ABCDEFGH, .signed64GHEFCDAB, .signed64BADCFEHG, .signed64HGFEDCBA,
         .doubleABCDEFGH, .doubleGHEFCDAB, .doubleBADCFEHG, .doubleHGFEDCBA:
      return [a, b, c, d]
    }
  }

  private static func reorderedBytes64(registers: [UInt16], mode: DataDisplayMode) -> [UInt8] {
    let bytes = registers.flatMap { register in
      [UInt8(register >> 8), UInt8(register & 0x00FF)]
    }
    guard bytes.count == 8 else { return bytes }

    let a = bytes[0]
    let b = bytes[1]
    let c = bytes[2]
    let d = bytes[3]
    let e = bytes[4]
    let f = bytes[5]
    let g = bytes[6]
    let h = bytes[7]

    switch mode {
    case .unsigned64ABCDEFGH, .signed64ABCDEFGH, .doubleABCDEFGH:
      return [a, b, c, d, e, f, g, h]
    case .unsigned64GHEFCDAB, .signed64GHEFCDAB, .doubleGHEFCDAB:
      return [g, h, e, f, c, d, a, b]
    case .unsigned64BADCFEHG, .signed64BADCFEHG, .doubleBADCFEHG:
      return [b, a, d, c, f, e, h, g]
    case .unsigned64HGFEDCBA, .signed64HGFEDCBA, .doubleHGFEDCBA:
      return [h, g, f, e, d, c, b, a]
    case .unsigned16, .signed16,
         .unsigned32ABCD, .unsigned32CDAB, .unsigned32BADC, .unsigned32DCBA,
         .signed32ABCD, .signed32CDAB, .signed32BADC, .signed32DCBA,
         .floatABCD, .floatCDAB, .floatBADC, .floatDCBA:
      return bytes
    }
  }

  private static func unsignedInteger(from bytes: [UInt8]) -> UInt64 {
    bytes.reduce(UInt64(0)) { result, byte in
      (result << 8) | UInt64(byte)
    }
  }

  private static func formatFloat(_ value: Float) -> String {
    formatFloating(Double(value), fractionDigits: 6)
  }

  private static func formatDouble(_ value: Double) -> String {
    formatFloating(value, fractionDigits: 12)
  }

  private static func formatFloating(_ value: Double, fractionDigits: Int) -> String {
    guard value.isFinite else {
      if value.isNaN {
        return "NaN"
      }
      return value.sign == .minus ? "-Infinity" : "Infinity"
    }

    let magnitude = abs(value)

    if magnitude >= 1_000_000_000_000 {
      return String(format: "%.\(fractionDigits)e", value)
    }

    let formatted = String(format: "%.\(fractionDigits)f", value)
    return trimTrailingZeros(formatted)
  }

  private static func trimTrailingZeros(_ value: String) -> String {
    var trimmed = value
    while trimmed.contains(".") && trimmed.last == "0" {
      trimmed.removeLast()
    }
    if trimmed.last == "." {
      trimmed.removeLast()
    }
    return trimmed == "-0" ? "0" : trimmed
  }

  static func bitItems(startAddress: Int, bytes: [UInt8], count: Int?) -> [DecodedItem] {
    let limit = count ?? bytes.count * 8
    return (0..<limit).map { index in
      let byte = bytes[index / 8]
      let bit = (byte >> UInt8(index % 8)) & 0x01
      return DecodedItem(
        address: startAddress + index,
        label: "位 \(startAddress + index)",
        raw: "字节 \(index / 8)，位 \(index % 8)",
        value: bit == 1 ? "开" : "关",
        note: bit == 1 ? "1" : "0"
      )
    }
  }
}
