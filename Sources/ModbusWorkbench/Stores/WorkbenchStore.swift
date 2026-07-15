import AppKit
import Combine
import Foundation

final class WorkbenchStore: ObservableObject {
  private static let registerDisplayPresetsKey = "registerDisplayPresets"
  private static let maxRegisterDisplayPresetCount = 24

  private let userDefaults: UserDefaults

  @Published var command = CommandInput()
  @Published var builtFrame: BuiltFrame?
  @Published var commandError: String?

  @Published var parserTransport: TransportMode = .rtu
  @Published var responseText = "01 03 04 00 2A 42 48 EB 6D"
  @Published var parseDisplayMode: DataDisplayMode = .unsigned16
  @Published var registerDisplayOverrides: [Int: DataDisplayMode] = [:]
  @Published var registerPointNames: [Int: String] = [:]
  @Published var assumedStartAddress: Int = 0
  @Published var expectedCountText = "2"
  @Published var parsedFrames: [ParsedFrame] = []
  @Published var registerComparisonRows: [RegisterComparisonRow] = []
  @Published var parseError: String?
  @Published var registerDisplayPresets: [RegisterDisplayPreset] = []

  var parsedFrame: ParsedFrame? {
    parsedFrames.first
  }

  init(userDefaults: UserDefaults = .standard) {
    self.userDefaults = userDefaults
    registerDisplayPresets = Self.loadRegisterDisplayPresets(from: userDefaults)
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

  func setRegisterPointName(_ name: String, for address: Int) {
    if name.isEmpty {
      registerPointNames.removeValue(forKey: address)
    } else {
      registerPointNames[address] = String(name.prefix(40))
    }
  }

  var canSaveRegisterDisplayPreset: Bool {
    !registerComparisonRows.isEmpty
  }

  func suggestedRegisterDisplayPresetName() -> String {
    guard let first = registerComparisonRows.first else {
      return "解析方式"
    }

    let last = registerComparisonRows.last?.address ?? first.address
    let range = first.address == last ? "\(first.address)" : "\(first.address)-\(last)"
    return "地址 \(range)"
  }

  func saveCurrentRegisterDisplayPreset(named rawName: String) {
    guard canSaveRegisterDisplayPreset else { return }

    let now = Date()
    let name = normalizedPresetName(rawName)
    let preset = RegisterDisplayPreset(
      id: UUID(),
      name: name,
      startAddress: assumedStartAddress,
      pointCount: currentRegisterDisplayPresetPointCount(),
      defaultMode: parseDisplayMode,
      overrides: currentRegisterDisplayPresetOverrides(),
      pointNames: currentRegisterDisplayPresetPointNames(),
      createdAt: now,
      updatedAt: now
    )

    if let index = registerDisplayPresets.firstIndex(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
      var updated = preset
      updated.id = registerDisplayPresets[index].id
      updated.createdAt = registerDisplayPresets[index].createdAt
      registerDisplayPresets.remove(at: index)
      registerDisplayPresets.insert(updated, at: 0)
    } else {
      registerDisplayPresets.insert(preset, at: 0)
    }

    if registerDisplayPresets.count > Self.maxRegisterDisplayPresetCount {
      registerDisplayPresets = Array(registerDisplayPresets.prefix(Self.maxRegisterDisplayPresetCount))
    }

    persistRegisterDisplayPresets()
  }

  func applyRegisterDisplayPreset(id: RegisterDisplayPreset.ID) {
    guard let preset = registerDisplayPresets.first(where: { $0.id == id }) else { return }
    assumedStartAddress = preset.startAddress
    parseDisplayMode = preset.defaultMode
    registerDisplayOverrides = preset.overrides
    registerPointNames = preset.pointNames
    parseResponse()
  }

  func deleteRegisterDisplayPreset(id: RegisterDisplayPreset.ID) {
    registerDisplayPresets.removeAll { $0.id == id }
    persistRegisterDisplayPresets()
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
    registerPointNames = [:]
    assumedStartAddress = 0
    expectedCountText = "2"
    parseResponse()
  }

  func loadFloatExample() {
    parserTransport = .rtu
    responseText = "01 03 04 42 48 00 00 6E 5D"
    parseDisplayMode = .floatABCD
    registerDisplayOverrides = [:]
    registerPointNames = [:]
    assumedStartAddress = 0
    expectedCountText = "2"
    parseResponse()
  }

  func loadCoilExample() {
    parserTransport = .rtu
    responseText = "01 01 02 CD 01 2C AC"
    parseDisplayMode = .unsigned16
    registerDisplayOverrides = [:]
    registerPointNames = [:]
    assumedStartAddress = 0
    expectedCountText = "10"
    parseResponse()
  }

  func loadExceptionExample() {
    parserTransport = .tcp
    responseText = "00 01 00 00 00 03 01 83 02"
    parseDisplayMode = .unsigned16
    registerDisplayOverrides = [:]
    registerPointNames = [:]
    assumedStartAddress = 0
    expectedCountText = ""
    parseResponse()
  }

  private func copy(_ text: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
  }

  private func normalizedPresetName(_ rawName: String) -> String {
    let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
    let name = trimmed.isEmpty ? suggestedRegisterDisplayPresetName() : trimmed
    return String(name.prefix(40))
  }

  private func currentRegisterDisplayPresetOverrides() -> [Int: DataDisplayMode] {
    let visibleAddresses = Set(registerComparisonRows.map(\.address))
    return registerDisplayOverrides.filter { address, mode in
      visibleAddresses.contains(address) && mode != parseDisplayMode
    }
  }

  private func currentRegisterDisplayPresetPointNames() -> [Int: String] {
    let visibleAddresses = Set(registerComparisonRows.map(\.address))
    return registerPointNames.reduce(into: [:]) { result, entry in
      let (address, rawName) = entry
      let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
      if visibleAddresses.contains(address), !name.isEmpty {
        result[address] = String(name.prefix(40))
      }
    }
  }

  private func currentRegisterDisplayPresetPointCount() -> Int {
    guard
      let first = registerComparisonRows.first,
      let last = registerComparisonRows.last
    else {
      return 0
    }

    return last.address + last.span - first.address
  }

  private static func loadRegisterDisplayPresets(from userDefaults: UserDefaults) -> [RegisterDisplayPreset] {
    guard let data = userDefaults.data(forKey: registerDisplayPresetsKey) else {
      return []
    }

    do {
      return try JSONDecoder().decode([RegisterDisplayPreset].self, from: data)
    } catch {
      return []
    }
  }

  private func persistRegisterDisplayPresets() {
    do {
      let data = try JSONEncoder().encode(registerDisplayPresets)
      userDefaults.set(data, forKey: Self.registerDisplayPresetsKey)
    } catch {
      userDefaults.removeObject(forKey: Self.registerDisplayPresetsKey)
    }
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
