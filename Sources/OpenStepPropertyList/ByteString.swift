//
//  Copyright 2023 Florian Pircher
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

#if canImport(WASILibc)
import WASILibc
#elseif canImport(Darwin)
import Darwin
#elseif os(Windows)
import MSVCRT
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Android)
import Android
#elseif canImport(Musl)
import Musl
#endif

public struct ByteString: Sendable {
	public let value: String
	public let isASCII: Bool
	
	@usableFromInline
	init(value: consuming String, uncheckedIsASCII isASCII: Bool) {
		assert(value.isContiguousUTF8)
		
		#if DEBUG
		// TODO: use `value.utf8Span.isKnownASCII` when span API is available
		var value = value
		assert(value.withUTF8(ByteString.isAllASCII(_:)) == isASCII)
		#endif
		
		self.value = value
		self.isASCII = isASCII
	}
}

extension ByteString: LosslessStringConvertible {
	/// Copied from the [internal Swift standard library](https://github.com/swiftlang/swift/blob/main/stdlib/public/core/StringCreate.swift), license: <https://www.swift.org/LICENSE.txt>
	@usableFromInline
	static func isAllASCII(_ input: UnsafeBufferPointer<UInt8>) -> Bool {
		if input.isEmpty { return true }
		
		let count = input.count
		var pointer = UnsafeRawPointer(input.baseAddress.unsafelyUnwrapped)
		
		let asciiMask64 = 0x8080_8080_8080_8080 as UInt64
		let asciiMask32 = UInt32(truncatingIfNeeded: asciiMask64)
		let asciiMask16 = UInt16(truncatingIfNeeded: asciiMask64)
		let asciiMask8 = UInt8(truncatingIfNeeded: asciiMask64)
		
		let end128 = pointer + count & ~(MemoryLayout<(UInt64, UInt64)>.stride &- 1)
		let end64 = pointer + count & ~(MemoryLayout<UInt64>.stride &- 1)
		let end32 = pointer + count & ~(MemoryLayout<UInt32>.stride &- 1)
		let end16 = pointer + count & ~(MemoryLayout<UInt16>.stride &- 1)
		let end = pointer + count
		
		while pointer < end128 {
			let pair = pointer.loadUnaligned(as: (UInt64, UInt64).self)
			let result = (pair.0 | pair.1) & asciiMask64
			guard result == 0 else { return false }
			pointer = pointer + MemoryLayout<(UInt64, UInt64)>.stride
		}
		
		if pointer < end64 {
			let value = pointer.loadUnaligned(as: UInt64.self)
			guard value & asciiMask64 == 0 else { return false }
			pointer = pointer + MemoryLayout<UInt64>.stride
		}
		
		if pointer < end32 {
			let value = pointer.loadUnaligned(as: UInt32.self)
			guard value & asciiMask32 == 0 else { return false }
			pointer = pointer + MemoryLayout<UInt32>.stride
		}
		
		if pointer < end16 {
			let value = pointer.loadUnaligned(as: UInt16.self)
			guard value & asciiMask16 == 0 else { return false }
			pointer = pointer + MemoryLayout<UInt16>.stride
		}
		
		if pointer < end {
			let value = pointer.loadUnaligned(fromByteOffset: 0, as: UInt8.self)
			guard value & asciiMask8 == 0 else { return false }
		}
		
		return true
	}
	
	@inlinable
	public init(_ value: consuming String) {
		assert(value.isContiguousUTF8)
		
		var value = value
		// TODO: use `value.utf8Span.isKnownASCII` when span API is available
		self.isASCII = value.withUTF8(ByteString.isAllASCII(_:))
		self.value = value
	}
	
	@inlinable
	public var description: String { self.value }
}

extension ByteString: Hashable {
	@inlinable
	@_effects(readonly)
	public static func == (lhs: Self, rhs: Self) -> Bool {
		if lhs.isASCII {
			guard rhs.isASCII else {
				return false
			}
			return lhs.value == rhs.value
		}
		else if rhs.isASCII {
			return false
		}
		
		var lhs = lhs.value
		var rhs = rhs.value
		return lhs.withUTF8 { lhsUTF8 in
			rhs.withUTF8 { rhsUTF8 in
				guard lhsUTF8.count == rhsUTF8.count else {
					return false
				}
				let lhsBaseAddress = lhsUTF8.baseAddress.unsafelyUnwrapped
				let rhsBaseAddress = rhsUTF8.baseAddress.unsafelyUnwrapped
				if lhsBaseAddress == rhsBaseAddress {
					return true
				}
				
				#if !$Embedded
				return memcmp(lhsBaseAddress, rhsBaseAddress, lhsUTF8.count) == 0
				#else
				return lhsUTF8.elementsEqual(rhsUTF8)
				#endif
			}
		}
	}
	
	@inlinable
	public func hash(into hasher: inout Hasher) {
		if self.isASCII {
			hasher.combine(self.value)
		}
		else {
			var value = self.value
			value.withUTF8 { utf8 in
				hasher.combine(bytes: UnsafeRawBufferPointer(utf8))
			}
		}
	}
}

extension ByteString: Comparable {
	@inlinable
	@_effects(readonly)
	public static func < (lhs: ByteString, rhs: ByteString) -> Bool {
		if lhs.isASCII && rhs.isASCII {
			return lhs.value < rhs.value
		}
		
		var lhs = lhs.value
		var rhs = rhs.value
		return lhs.withUTF8 { lhsUTF8 in
			rhs.withUTF8 { rhsUTF8 in
				let lhsBaseAddress = lhsUTF8.baseAddress.unsafelyUnwrapped
				let rhsBaseAddress = rhsUTF8.baseAddress.unsafelyUnwrapped
				if lhsBaseAddress == rhsBaseAddress && lhsUTF8.count == rhsUTF8.count {
					return false
				}
				let count = min(lhsUTF8.count, rhsUTF8.count)
				
				#if !$Embedded
				let result = memcmp(lhsBaseAddress, rhsBaseAddress, count)
				if result != 0 {
					return result < 0
				}
				else {
					return lhsUTF8.count < rhsUTF8.count
				}
				#else
				for index in 0 ..< count {
					let a = lhsUTF8[index]
					let b = rhsUTF8[index]
					if a != b {
						return a < b
					}
				}
				return lhsUTF8.count < rhsUTF8.count
				#endif
			}
		}
	}
}

extension ByteString: CustomDebugStringConvertible {
	public var debugDescription: String { self.value.debugDescription }
}

extension ByteString: ExpressibleByStringLiteral {
	@inlinable
	public init(stringLiteral value: StaticString) {
		self.isASCII = value.isASCII
		self.value = value.description
	}
}

extension ByteString {
	@inlinable @inline(__always)
	public var utf8: String.UTF8View { self.value.utf8 }
	@inlinable @inline(__always)
	public var count: Int { self.utf8.count }
	@inlinable @inline(__always)
	public var isEmpty: Bool { self.utf8.isEmpty }
}
