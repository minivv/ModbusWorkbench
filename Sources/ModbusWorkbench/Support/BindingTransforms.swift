import SwiftUI

extension Binding where Value == UInt8 {
  func intBinding() -> Binding<Int> {
    Binding<Int>(
      get: { Int(wrappedValue) },
      set: { wrappedValue = UInt8(clamping: $0) }
    )
  }
}

extension Binding where Value == UInt16 {
  func intBinding() -> Binding<Int> {
    Binding<Int>(
      get: { Int(wrappedValue) },
      set: { wrappedValue = UInt16(clamping: $0) }
    )
  }
}
