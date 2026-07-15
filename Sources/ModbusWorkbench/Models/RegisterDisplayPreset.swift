import Foundation

struct RegisterDisplayPreset: Identifiable, Codable, Equatable {
  var id: UUID
  var name: String
  var startAddress: Int
  var pointCount: Int
  var defaultMode: DataDisplayMode
  var overrides: [Int: DataDisplayMode]
  var pointNames: [Int: String]
  var createdAt: Date
  var updatedAt: Date

  var summary: String {
    let endAddress = max(startAddress, startAddress + pointCount - 1)
    let range = startAddress == endAddress ? "\(startAddress)" : "\(startAddress)-\(endAddress)"
    return "起始 \(range) 共 \(pointCount) 点位"
  }

  enum CodingKeys: String, CodingKey {
    case id
    case name
    case startAddress
    case pointCount
    case defaultMode
    case overrides
    case pointNames
    case createdAt
    case updatedAt
  }

  init(
    id: UUID,
    name: String,
    startAddress: Int,
    pointCount: Int,
    defaultMode: DataDisplayMode,
    overrides: [Int: DataDisplayMode],
    pointNames: [Int: String] = [:],
    createdAt: Date,
    updatedAt: Date
  ) {
    self.id = id
    self.name = name
    self.startAddress = startAddress
    self.pointCount = pointCount
    self.defaultMode = defaultMode
    self.overrides = overrides
    self.pointNames = pointNames
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(UUID.self, forKey: .id)
    name = try container.decode(String.self, forKey: .name)
    defaultMode = try container.decode(DataDisplayMode.self, forKey: .defaultMode)
    overrides = try container.decode([Int: DataDisplayMode].self, forKey: .overrides)
    pointNames = try container.decodeIfPresent([Int: String].self, forKey: .pointNames) ?? [:]
    createdAt = try container.decode(Date.self, forKey: .createdAt)
    updatedAt = try container.decode(Date.self, forKey: .updatedAt)

    if
      let savedStartAddress = try container.decodeIfPresent(Int.self, forKey: .startAddress),
      let savedPointCount = try container.decodeIfPresent(Int.self, forKey: .pointCount)
    {
      startAddress = savedStartAddress
      pointCount = savedPointCount
    } else if let range = Self.addressRange(in: name) {
      startAddress = range.startAddress
      pointCount = range.pointCount
    } else if let firstAddress = overrides.keys.min() {
      let lastAddress = overrides.map { address, mode in
        address + mode.wordCount - 1
      }.max() ?? firstAddress
      startAddress = firstAddress
      pointCount = lastAddress - firstAddress + 1
    } else {
      startAddress = 0
      pointCount = 0
    }
  }

  private static func addressRange(in name: String) -> (startAddress: Int, pointCount: Int)? {
    let pattern = #"地址\s*(\d+)(?:\s*-\s*(\d+))?"#
    guard
      let regex = try? NSRegularExpression(pattern: pattern),
      let match = regex.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)),
      let startRange = Range(match.range(at: 1), in: name),
      let startAddress = Int(name[startRange])
    else {
      return nil
    }

    if
      let endRange = Range(match.range(at: 2), in: name),
      let endAddress = Int(name[endRange]),
      endAddress >= startAddress
    {
      return (startAddress, endAddress - startAddress + 1)
    }

    return (startAddress, 1)
  }
}
