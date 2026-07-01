import Foundation

enum HexFormatter {
  static func byte(_ value: UInt8) -> String {
    String(format: "%02X", value)
  }

  static func word(_ value: UInt16) -> String {
    String(format: "%04X", value)
  }

  static func bytes(_ bytes: [UInt8], separator: String = " ") -> String {
    bytes.map(byte).joined(separator: separator)
  }

  static func decimalAndHex(_ value: UInt16) -> String {
    "\(value) / 0x\(word(value))"
  }

  static func parseHexBytes(_ text: String) throws -> [UInt8] {
    let normalized = text
      .replacingOccurrences(of: "0x", with: "", options: [.caseInsensitive])
      .replacingOccurrences(of: ",", with: " ")
      .replacingOccurrences(of: ";", with: " ")
      .replacingOccurrences(of: "\n", with: " ")
      .replacingOccurrences(of: "\t", with: " ")

    let rawTokens = normalized
      .split(separator: " ")
      .map(String.init)

    let tokens: [String]
    if rawTokens.count == 1, let compact = rawTokens.first, compact.count > 2 {
      guard compact.count.isMultiple(of: 2) else {
        throw ModbusCodecError.invalidHexToken(compact)
      }
      tokens = stride(from: 0, to: compact.count, by: 2).map { index in
        let start = compact.index(compact.startIndex, offsetBy: index)
        let end = compact.index(start, offsetBy: 2)
        return String(compact[start..<end])
      }
    } else {
      tokens = rawTokens
    }

    guard !tokens.isEmpty else {
      throw ModbusCodecError.emptyInput
    }

    return try tokens.map { token in
      guard token.range(of: #"^[0-9a-fA-F]{1,2}$"#, options: .regularExpression) != nil else {
        throw ModbusCodecError.invalidHexToken(token)
      }
      guard let value = UInt8(token, radix: 16) else {
        throw ModbusCodecError.invalidByte(token)
      }
      return value
    }
  }
}

extension Array where Element == UInt8 {
  func word(at index: Int) -> UInt16 {
    (UInt16(self[index]) << 8) | UInt16(self[index + 1])
  }
}
