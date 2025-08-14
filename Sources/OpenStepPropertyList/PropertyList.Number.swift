//
//  Copyright 2025 Florian Pircher
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      https://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#if !$Embedded
extension PropertyList {
	/// Returns a string representing an integer value.
	@inlinable
	public static func number(_ value: Int) -> Self {
		.string(ByteString(value: value.description, uncheckedIsASCII: true), options: .unquoted)
	}
	
	/// Returns a string representing a floating point value, if the value is finite, `nil` otherwise.
	@inlinable
	public static func number(_ value: Double) -> Self? {
		guard value.isFinite else {
			return nil
		}
		return .string(ByteString(value: value.description, uncheckedIsASCII: true), options: .unquoted)
	}
	
	public enum Number {
		case int(Int)
		case float(Double)
	}
	
	@usableFromInline
	static func isNumericString(_ string: String) -> Bool {
		guard let head = string.utf8.first else {
			return false
		}
		return ((head >= UInt8(ascii: "0") && head <= UInt8(ascii: "9")) || head == UInt8(ascii: "-"))
			&& string.utf8.dropFirst().allSatisfy({ ($0 >= UInt8(ascii: "0") && $0 <= UInt8(ascii: "9")) || $0 == UInt8(ascii: ".") })
	}
	
	@inlinable
	public func numberValue() -> Number? {
		guard case .string(let byteString, options: let options) = self else {
			return nil
		}
		guard options.contains(.unquoted) else {
			return nil
		}
		guard Self.isNumericString(byteString.value) else {
			return nil
		}
		if let int = Int(byteString.value) {
			return .int(int)
		}
		else if let float = Double(byteString.value) {
			return .float(float)
		}
		else {
			return nil
		}
	}
}

extension PropertyList.Number: Equatable {
	public static func == (lhs: Self, rhs: Self) -> Bool {
		switch lhs {
		case .int(let a):
			switch rhs {
			case .int(let b):
				a == b
			case .float(let b):
				Double(a) == b
			}
		case .float(let a):
			switch rhs {
			case .int(let b):
				a == Double(b)
			case .float(let b):
				a == b
			}
		}
	}
}

extension PropertyList.Number: Hashable {
	public func hash(into hasher: inout Hasher) {
		switch self {
		case .int(let int):
			hasher.combine(Double(int))
		case .float(let float):
			hasher.combine(float)
		}
	}
}

extension PropertyList.Number: Comparable {
	public static func < (lhs: Self, rhs: Self) -> Bool {
		switch (lhs, rhs) {
		case (.int(let a), .int(let b)): a < b
		case (.int(let a), .float(let b)): Double(a) < b
		case (.float(let a), .int(let b)): a < Double(b)
		case (.float(let a), .float(let b)): a < b
		}
	}
}

extension PropertyList.Number: Sendable, BitwiseCopyable {}

extension PropertyList.Number: AdditiveArithmetic {
	public static let zero = Self.int(.zero)
	
	public static func + (lhs: Self, rhs: Self) -> Self {
		switch (lhs, rhs) {
		case (.int(let a), .int(let b)): .int(a + b)
		case (.int(let a), .float(let b)): .float(Double(a) + b)
		case (.float(let a), .int(let b)): .float(a + Double(b))
		case (.float(let a), .float(let b)): .float(a + b)
		}
	}
	
	public static func - (lhs: Self, rhs: Self) -> Self {
		switch (lhs, rhs) {
		case (.int(let a), .int(let b)): .int(a - b)
		case (.int(let a), .float(let b)): .float(Double(a) - b)
		case (.float(let a), .int(let b)): .float(a - Double(b))
		case (.float(let a), .float(let b)): .float(a - b)
		}
	}
}

extension PropertyList.Number: Numeric {
	public enum Magnitude {
		case uint(UInt)
		case float(Double)
	}
	
	public init(integerLiteral value: Int) {
		self = .int(value)
	}
	
	public init?(exactly source: some BinaryInteger) {
		if let uint = Int(exactly: source) {
			self = .int(uint)
		}
		else if let float = Double(exactly: source) {
			self = .float(float)
		}
		else {
			return nil
		}
	}
	
	public static func * (lhs: Self, rhs: Self) -> Self {
		switch (lhs, rhs) {
		case (.int(let a), .int(let b)): .int(a * b)
		case (.int(let a), .float(let b)): .float(Double(a) * b)
		case (.float(let a), .int(let b)): .float(a * Double(b))
		case (.float(let a), .float(let b)): .float(a * b)
		}
	}
	
	public static func *= (lhs: inout Self, rhs: Self) {
		switch (lhs, rhs) {
		case (.int(let a), .int(let b)): lhs = .int(a * b)
		case (.int(let a), .float(let b)): lhs = .float(Double(a) * b)
		case (.float(let a), .int(let b)): lhs = .float(a * Double(b))
		case (.float(let a), .float(let b)): lhs = .float(a * b)
		}
	}
	
	public var magnitude: Magnitude {
		switch self {
		case .int(let int):
			.uint(int.magnitude)
		case .float(let float):
			.float(float.magnitude)
		}
	}
}

extension PropertyList.Number.Magnitude: Equatable {
	public static func == (lhs: Self, rhs: Self) -> Bool {
		switch lhs {
		case .uint(let a):
			switch rhs {
			case .uint(let b):
				a == b
			case .float(let b):
				Double(a) == b
			}
		case .float(let a):
			switch rhs {
			case .uint(let b):
				a == Double(b)
			case .float(let b):
				a == b
			}
		}
	}
}

extension PropertyList.Number.Magnitude: Hashable {
	public func hash(into hasher: inout Hasher) {
		switch self {
		case .uint(let int):
			hasher.combine(Double(int))
		case .float(let float):
			hasher.combine(float)
		}
	}
}

extension PropertyList.Number.Magnitude: Comparable {
	public static func < (lhs: Self, rhs: Self) -> Bool {
		switch (lhs, rhs) {
		case (.uint(let a), .uint(let b)): a < b
		case (.uint(let a), .float(let b)): Double(a) < b
		case (.float(let a), .uint(let b)): a < Double(b)
		case (.float(let a), .float(let b)): a < b
		}
	}
}

extension PropertyList.Number.Magnitude: Sendable, BitwiseCopyable {}

extension PropertyList.Number.Magnitude: AdditiveArithmetic {
	public static let zero = Self.uint(.zero)
	
	public static func + (lhs: Self, rhs: Self) -> Self {
		switch (lhs, rhs) {
		case (.uint(let a), .uint(let b)): .uint(a + b)
		case (.uint(let a), .float(let b)): .float(Double(a) + b)
		case (.float(let a), .uint(let b)): .float(a + Double(b))
		case (.float(let a), .float(let b)): .float(a + b)
		}
	}
	
	public static func - (lhs: Self, rhs: Self) -> Self {
		switch (lhs, rhs) {
		case (.uint(let a), .uint(let b)): .uint(a - b)
		case (.uint(let a), .float(let b)): .float(Double(a) - b)
		case (.float(let a), .uint(let b)): .float(a - Double(b))
		case (.float(let a), .float(let b)): .float(a - b)
		}
	}
}

extension PropertyList.Number.Magnitude: Numeric {
	public typealias Magnitude = Self
	
	public init(integerLiteral value: UInt) {
		self = .uint(value)
	}
	
	public init?(exactly source: some BinaryInteger) {
		if let uint = UInt(exactly: source) {
			self = .uint(uint)
		}
		else if let float = Double(exactly: source) {
			self = .float(float)
		}
		else {
			return nil
		}
	}
	
	public static func * (lhs: Self, rhs: Self) -> Self {
		switch (lhs, rhs) {
		case (.uint(let a), .uint(let b)): .uint(a * b)
		case (.uint(let a), .float(let b)): .float(Double(a) * b)
		case (.float(let a), .uint(let b)): .float(a * Double(b))
		case (.float(let a), .float(let b)): .float(a * b)
		}
	}
	
	public static func *= (lhs: inout Self, rhs: Self) {
		switch (lhs, rhs) {
		case (.uint(let a), .uint(let b)): lhs = .uint(a * b)
		case (.uint(let a), .float(let b)): lhs = .float(Double(a) * b)
		case (.float(let a), .uint(let b)): lhs = .float(a * Double(b))
		case (.float(let a), .float(let b)): lhs = .float(a * b)
		}
	}
	
	public var magnitude: Self {
		self
	}
}

extension PropertyList.Number: SignedNumeric {
	public mutating func negate() {
		switch self {
		case .int(let int):
			self = .int(-int)
		case .float(let float):
			self = .float(-float)
		}
	}
}

extension PropertyList.Number: Strideable {
	public typealias Stride = Self
	
	public func advanced(by n: Stride) -> Self {
		switch self {
		case .int(let a):
			switch n {
			case .int(let b):
				.int(a + b)
			case .float(let b):
				.float(Double(a) + b)
			}
		case .float(let a):
			switch n {
			case .int(let b):
				.float(a + Double(b))
			case .float(let b):
				.float(a + b)
			}
		}
	}
	
	public func distance(to other: Self) -> Self {
		switch self {
		case .int(let a):
			switch other {
			case .int(let b):
				.int(a.distance(to: b))
			case .float(let b):
				.float(Double(a).distance(to: b))
			}
		case .float(let a):
			switch other {
			case .int(let b):
				.float(a.distance(to: Double(b)))
			case .float(let b):
				.float(a.distance(to: b))
			}
		}
	}
}

extension PropertyList.Number: LosslessStringConvertible {
	public init?(_ description: String) {
		if let int = Int(description) {
			self = .int(int)
		}
		else if let float = Double(description) {
			self = .float(float)
		}
		else {
			return nil
		}
	}
	
	public var description: String {
		switch self {
		case .int(let int):
			int.description
		case .float(let float):
			float.description
		}
	}
}
#endif
