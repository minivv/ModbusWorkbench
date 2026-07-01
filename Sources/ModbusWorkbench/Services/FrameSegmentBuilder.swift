import Foundation

enum FrameSegmentBuilder {
  static func command(input: CommandInput, frame: BuiltFrame) -> [FrameSegment] {
    let frameFunction = frame.pdu.first.flatMap(ModbusFunction.init(rawValue:)) ?? input.function

    switch input.transport {
    case .rtu:
      var segments: [FrameSegment] = [
        FrameSegment(label: "从站地址", bytes: slice(frame.adu, 0..<1), kind: .address),
        FrameSegment(label: "功能码", bytes: slice(frame.pdu, 0..<1), kind: .function)
      ]
      segments.append(contentsOf: requestPayloadSegments(function: frameFunction, payload: frame.payload))
      if frame.adu.count >= 2 {
        segments.append(FrameSegment(label: "CRC", bytes: Array(frame.adu.suffix(2)), kind: .checksum))
      }
      return segments

    case .tcp:
      var segments: [FrameSegment] = []
      appendIfPresent(&segments, label: "事务号", bytes: slice(frame.adu, 0..<2), kind: .transport)
      appendIfPresent(&segments, label: "协议号", bytes: slice(frame.adu, 2..<4), kind: .transport)
      appendIfPresent(&segments, label: "长度", bytes: slice(frame.adu, 4..<6), kind: .quantity)
      appendIfPresent(&segments, label: "从站地址", bytes: slice(frame.adu, 6..<7), kind: .address)
      appendIfPresent(&segments, label: "功能码", bytes: slice(frame.adu, 7..<8), kind: .function)
      segments.append(contentsOf: requestPayloadSegments(function: frameFunction, payload: frame.payload))
      return segments
    }
  }

  static func parsed(frame: ParsedFrame) -> [FrameSegment] {
    switch frame.transport {
    case .rtu:
      var segments: [FrameSegment] = []
      appendIfPresent(&segments, label: "从站地址", bytes: slice(frame.rawBytes, 0..<1), kind: .address)
      appendIfPresent(&segments, label: "功能码", bytes: slice(frame.rawBytes, 1..<2), kind: frame.isException ? .exception : .function)
      segments.append(contentsOf: responsePayloadSegments(functionCode: frame.functionCode, payload: frame.payload))
      if frame.rawBytes.count >= 2 {
        appendIfPresent(&segments, label: "CRC", bytes: Array(frame.rawBytes.suffix(2)), kind: .checksum)
      }
      return segments

    case .tcp:
      var segments: [FrameSegment] = []
      appendIfPresent(&segments, label: "事务号", bytes: slice(frame.rawBytes, 0..<2), kind: .transport)
      appendIfPresent(&segments, label: "协议号", bytes: slice(frame.rawBytes, 2..<4), kind: .transport)
      appendIfPresent(&segments, label: "长度", bytes: slice(frame.rawBytes, 4..<6), kind: .quantity)
      appendIfPresent(&segments, label: "从站地址", bytes: slice(frame.rawBytes, 6..<7), kind: .address)
      appendIfPresent(&segments, label: "功能码", bytes: slice(frame.rawBytes, 7..<8), kind: frame.isException ? .exception : .function)
      segments.append(contentsOf: responsePayloadSegments(functionCode: frame.functionCode, payload: frame.payload))
      return segments
    }
  }

  private static func requestPayloadSegments(function: ModbusFunction, payload: [UInt8]) -> [FrameSegment] {
    switch function {
    case .readCoils, .readDiscreteInputs, .readHoldingRegisters, .readInputRegisters:
      return [
        FrameSegment(label: "起始地址", bytes: slice(payload, 0..<2), kind: .addressRange),
        FrameSegment(label: "数量", bytes: slice(payload, 2..<4), kind: .quantity)
      ].filter { !$0.bytes.isEmpty }
    case .writeSingleCoil, .writeSingleRegister:
      return [
        FrameSegment(label: "地址", bytes: slice(payload, 0..<2), kind: .addressRange),
        FrameSegment(label: "写入值", bytes: slice(payload, 2..<4), kind: .value)
      ].filter { !$0.bytes.isEmpty }
    case .writeMultipleCoils, .writeMultipleRegisters:
      return [
        FrameSegment(label: "起始地址", bytes: slice(payload, 0..<2), kind: .addressRange),
        FrameSegment(label: "数量", bytes: slice(payload, 2..<4), kind: .quantity),
        FrameSegment(label: "字节数", bytes: slice(payload, 4..<5), kind: .byteCount),
        FrameSegment(label: "写入数据", bytes: payload.count > 5 ? slice(payload, 5..<payload.count) : [], kind: .data)
      ].filter { !$0.bytes.isEmpty }
    }
  }

  private static func responsePayloadSegments(functionCode: UInt8, payload: [UInt8]) -> [FrameSegment] {
    if (functionCode & 0x80) != 0 {
      return [
        FrameSegment(label: "异常码", bytes: slice(payload, 0..<1), kind: .exception)
      ].filter { !$0.bytes.isEmpty }
    }

    guard let function = ModbusFunction(rawValue: functionCode) else {
      return [
        FrameSegment(label: "Payload", bytes: payload, kind: .data)
      ].filter { !$0.bytes.isEmpty }
    }

    switch function {
    case .readCoils, .readDiscreteInputs, .readHoldingRegisters, .readInputRegisters:
      return [
        FrameSegment(label: "数据长度", bytes: slice(payload, 0..<1), kind: .byteCount),
        FrameSegment(label: "数据", bytes: slice(payload, 1..<payload.count), kind: .data)
      ].filter { !$0.bytes.isEmpty }
    case .writeSingleCoil, .writeSingleRegister:
      return [
        FrameSegment(label: "地址", bytes: slice(payload, 0..<2), kind: .addressRange),
        FrameSegment(label: "回显值", bytes: slice(payload, 2..<4), kind: .value)
      ].filter { !$0.bytes.isEmpty }
    case .writeMultipleCoils, .writeMultipleRegisters:
      return [
        FrameSegment(label: "起始地址", bytes: slice(payload, 0..<2), kind: .addressRange),
        FrameSegment(label: "数量", bytes: slice(payload, 2..<4), kind: .quantity)
      ].filter { !$0.bytes.isEmpty }
    }
  }

  private static func appendIfPresent(
    _ segments: inout [FrameSegment],
    label: String,
    bytes: [UInt8],
    kind: FrameSegmentKind
  ) {
    guard !bytes.isEmpty else { return }
    segments.append(FrameSegment(label: label, bytes: bytes, kind: kind))
  }

  private static func slice(_ bytes: [UInt8], _ range: Range<Int>) -> [UInt8] {
    guard range.lowerBound < bytes.count, range.upperBound > 0 else {
      return []
    }
    let lowerBound = max(0, range.lowerBound)
    let upperBound = min(bytes.count, range.upperBound)
    guard lowerBound < upperBound else {
      return []
    }
    return Array(bytes[lowerBound..<upperBound])
  }
}
