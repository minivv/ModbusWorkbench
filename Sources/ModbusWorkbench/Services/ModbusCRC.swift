import Foundation

enum ModbusCRC {
  static func compute(_ bytes: [UInt8]) -> UInt16 {
    var crc: UInt16 = 0xFFFF
    for byte in bytes {
      crc ^= UInt16(byte)
      for _ in 0..<8 {
        if (crc & 0x0001) != 0 {
          crc = (crc >> 1) ^ 0xA001
        } else {
          crc >>= 1
        }
      }
    }
    return crc
  }

  static func append(to bytes: [UInt8]) -> [UInt8] {
    let crc = compute(bytes)
    return bytes + [UInt8(crc & 0x00FF), UInt8(crc >> 8)]
  }

  static func readLittleEndian(from bytes: [UInt8], at index: Int) -> UInt16 {
    UInt16(bytes[index]) | (UInt16(bytes[index + 1]) << 8)
  }
}
