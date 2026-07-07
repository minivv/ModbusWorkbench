import Foundation

enum TransportMode: String, CaseIterable, Identifiable {
  case rtu = "RTU"
  case tcp = "TCP"

  var id: String { rawValue }
}

enum DataDisplayMode: String, CaseIterable, Identifiable {
  case unsigned16 = "UINT16"
  case signed16 = "INT16"
  case unsigned32ABCD = "UINT32_ABCD"
  case unsigned32CDAB = "UINT32_CDAB"
  case unsigned32BADC = "UINT32_BADC"
  case unsigned32DCBA = "UINT32_DCBA"
  case signed32ABCD = "INT32_ABCD"
  case signed32CDAB = "INT32_CDAB"
  case signed32BADC = "INT32_BADC"
  case signed32DCBA = "INT32_DCBA"
  case floatABCD = "FLOAT_ABCD"
  case floatCDAB = "FLOAT_CDAB"
  case floatBADC = "FLOAT_BADC"
  case floatDCBA = "FLOAT_DCBA"
  case unsigned64ABCDEFGH = "UINT64_ABCDEFGH"
  case unsigned64GHEFCDAB = "UINT64_GHEFCDAB"
  case unsigned64BADCFEHG = "UINT64_BADCFEHG"
  case unsigned64HGFEDCBA = "UINT64_HGFEDCBA"
  case signed64ABCDEFGH = "INT64_ABCDEFGH"
  case signed64GHEFCDAB = "INT64_GHEFCDAB"
  case signed64BADCFEHG = "INT64_BADCFEHG"
  case signed64HGFEDCBA = "INT64_HGFEDCBA"
  case doubleABCDEFGH = "DOUBLE_ABCDEFGH"
  case doubleGHEFCDAB = "DOUBLE_GHEFCDAB"
  case doubleBADCFEHG = "DOUBLE_BADCFEHG"
  case doubleHGFEDCBA = "DOUBLE_HGFEDCBA"

  var id: String { rawValue }

  var wordCount: Int {
    switch self {
    case .unsigned16, .signed16:
      1
    case .unsigned32ABCD, .unsigned32CDAB, .unsigned32BADC, .unsigned32DCBA,
         .signed32ABCD, .signed32CDAB, .signed32BADC, .signed32DCBA,
         .floatABCD, .floatCDAB, .floatBADC, .floatDCBA:
      2
    case .unsigned64ABCDEFGH, .unsigned64GHEFCDAB, .unsigned64BADCFEHG, .unsigned64HGFEDCBA,
         .signed64ABCDEFGH, .signed64GHEFCDAB, .signed64BADCFEHG, .signed64HGFEDCBA,
         .doubleABCDEFGH, .doubleGHEFCDAB, .doubleBADCFEHG, .doubleHGFEDCBA:
      4
    }
  }
}

enum ModbusFunction: UInt8, CaseIterable, Identifiable {
  case readCoils = 0x01
  case readDiscreteInputs = 0x02
  case readHoldingRegisters = 0x03
  case readInputRegisters = 0x04
  case writeSingleCoil = 0x05
  case writeSingleRegister = 0x06
  case writeMultipleCoils = 0x0F
  case writeMultipleRegisters = 0x10

  var id: UInt8 { rawValue }

  var title: String {
    switch self {
    case .readCoils:
      "01 读线圈"
    case .readDiscreteInputs:
      "02 读离散输入"
    case .readHoldingRegisters:
      "03 读保持寄存器"
    case .readInputRegisters:
      "04 读输入寄存器"
    case .writeSingleCoil:
      "05 写单个线圈"
    case .writeSingleRegister:
      "06 写单个寄存器"
    case .writeMultipleCoils:
      "15 写多个线圈"
    case .writeMultipleRegisters:
      "16 写多个寄存器"
    }
  }

  var shortTitle: String {
    switch self {
    case .readCoils:
      "读线圈"
    case .readDiscreteInputs:
      "读离散输入"
    case .readHoldingRegisters:
      "读保持寄存器"
    case .readInputRegisters:
      "读输入寄存器"
    case .writeSingleCoil:
      "写单个线圈"
    case .writeSingleRegister:
      "写单个寄存器"
    case .writeMultipleCoils:
      "写多个线圈"
    case .writeMultipleRegisters:
      "写多个寄存器"
    }
  }

  var systemImage: String {
    switch self {
    case .readCoils, .readDiscreteInputs:
      "switch.2"
    case .readHoldingRegisters, .readInputRegisters:
      "tablecells"
    case .writeSingleCoil, .writeMultipleCoils:
      "powerplug"
    case .writeSingleRegister, .writeMultipleRegisters:
      "square.and.pencil"
    }
  }

  var isRead: Bool {
    switch self {
    case .readCoils, .readDiscreteInputs, .readHoldingRegisters, .readInputRegisters:
      true
    case .writeSingleCoil, .writeSingleRegister, .writeMultipleCoils, .writeMultipleRegisters:
      false
    }
  }

  var usesBits: Bool {
    switch self {
    case .readCoils, .readDiscreteInputs, .writeSingleCoil, .writeMultipleCoils:
      true
    case .readHoldingRegisters, .readInputRegisters, .writeSingleRegister, .writeMultipleRegisters:
      false
    }
  }

  static func label(for code: UInt8) -> String {
    if let function = ModbusFunction(rawValue: code) {
      return function.title
    }
    return "0x\(HexFormatter.byte(code))"
  }
}

enum ModbusExceptionCode: UInt8 {
  case illegalFunction = 0x01
  case illegalDataAddress = 0x02
  case illegalDataValue = 0x03
  case serverDeviceFailure = 0x04
  case acknowledge = 0x05
  case serverDeviceBusy = 0x06
  case memoryParityError = 0x08
  case gatewayPathUnavailable = 0x0A
  case gatewayTargetFailed = 0x0B

  var title: String {
    switch self {
    case .illegalFunction:
      "非法功能码"
    case .illegalDataAddress:
      "非法数据地址"
    case .illegalDataValue:
      "非法数据值"
    case .serverDeviceFailure:
      "从站设备故障"
    case .acknowledge:
      "已确认"
    case .serverDeviceBusy:
      "从站设备忙"
    case .memoryParityError:
      "存储奇偶校验错误"
    case .gatewayPathUnavailable:
      "网关路径不可用"
    case .gatewayTargetFailed:
      "网关目标无响应"
    }
  }

  var description: String {
    switch self {
    case .illegalFunction:
      "从站不支持请求中的功能码。"
    case .illegalDataAddress:
      "起始地址或地址范围不被从站接受。"
    case .illegalDataValue:
      "请求数据字段中的数量或数值不合法。"
    case .serverDeviceFailure:
      "从站执行请求时出现不可恢复错误。"
    case .acknowledge:
      "从站已接受请求，但需要更长时间处理。"
    case .serverDeviceBusy:
      "从站忙，稍后重试。"
    case .memoryParityError:
      "从站扩展存储区出现奇偶校验错误。"
    case .gatewayPathUnavailable:
      "网关没有可用路径到目标设备。"
    case .gatewayTargetFailed:
      "网关未从目标设备收到响应。"
    }
  }
}

struct CommandInput {
  var transport: TransportMode = .rtu
  var transactionID: UInt16 = 1
  var unitID: UInt8 = 1
  var function: ModbusFunction = .readHoldingRegisters
  var startAddress: UInt16 = 0
  var quantity: UInt16 = 10
  var singleValue: UInt16 = 1
  var valuesText: String = "1, 2, 3"
}

struct BuiltFrame {
  var adu: [UInt8]
  var pdu: [UInt8]
  var payload: [UInt8]
  var summary: String
  var warnings: [String]
}

struct ParsedFrame {
  var rawBytes: [UInt8]
  var transport: TransportMode
  var transactionID: UInt16?
  var protocolID: UInt16?
  var length: UInt16?
  var unitID: UInt8
  var functionCode: UInt8
  var functionName: String
  var isException: Bool
  var exceptionTitle: String?
  var exceptionDescription: String?
  var payload: [UInt8]
  var dataBytes: [UInt8]
  var crcExpected: UInt16?
  var crcActual: UInt16?
  var crcIsValid: Bool?
  var lengthIsValid: Bool?
  var warnings: [String]
  var decodedItems: [DecodedItem]

  var registerValues: [UInt16] {
    guard functionCode == ModbusFunction.readHoldingRegisters.rawValue ||
      functionCode == ModbusFunction.readInputRegisters.rawValue else {
      return []
    }

    return stride(from: 0, to: dataBytes.count - (dataBytes.count % 2), by: 2).map { index in
      (UInt16(dataBytes[index]) << 8) | UInt16(dataBytes[index + 1])
    }
  }

  var isRegisterRead: Bool {
    functionCode == ModbusFunction.readHoldingRegisters.rawValue ||
      functionCode == ModbusFunction.readInputRegisters.rawValue
  }

  var isBitRead: Bool {
    functionCode == ModbusFunction.readCoils.rawValue ||
      functionCode == ModbusFunction.readDiscreteInputs.rawValue
  }
}

struct DecodedItem: Identifiable, Hashable {
  let id = UUID()
  var address: Int
  var label: String
  var raw: String
  var value: String
  var note: String
}

struct FrameSegment: Identifiable, Hashable {
  let id = UUID()
  var label: String
  var bytes: [UInt8]
  var kind: FrameSegmentKind
}

enum FrameSegmentKind: Hashable {
  case transport
  case address
  case function
  case addressRange
  case quantity
  case byteCount
  case data
  case checksum
  case exception
  case value
}

struct RegisterDecodeRow: Identifiable, Hashable {
  var id: Int { address }
  var address: Int
  var span: Int
  var mode: DataDisplayMode
  var raw: String
  var value: String
  var note: String
}

struct RegisterComparisonRow: Identifiable, Hashable {
  var id: Int { address }
  var address: Int
  var span: Int
  var mode: DataDisplayMode
  var raw: String
  var values: [RegisterDecodeRow?]
}

enum ModbusCodecError: LocalizedError, Equatable {
  case emptyInput
  case invalidHexToken(String)
  case invalidByte(String)
  case frameTooShort(String)
  case unsupportedFunction(UInt8)
  case invalidQuantity(String)
  case invalidValue(String)
  case invalidByteCount(expected: Int, actual: Int)
  case invalidLength(String)

  var errorDescription: String? {
    switch self {
    case .emptyInput:
      "请输入十六进制帧。"
    case .invalidHexToken(let token):
      "无效的十六进制片段：\(token)"
    case .invalidByte(let token):
      "字节超出范围：\(token)"
    case .frameTooShort(let message):
      message
    case .unsupportedFunction(let code):
      "暂不支持构建功能码 0x\(HexFormatter.byte(code))。"
    case .invalidQuantity(let message):
      message
    case .invalidValue(let message):
      message
    case .invalidByteCount(let expected, let actual):
      "数据字节数不匹配，期望 \(expected) 字节，实际 \(actual) 字节。"
    case .invalidLength(let message):
      message
    }
  }
}
