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

/// OpenStep Property List (also known as NeXTStep, ASCII, or Old-Style Property Lists).
///
/// This implementation differs from the Property Lists used by Objective-C and `PropertyListSerialization` in the following key aspects:
///
/// - All values are represented using Swift value types.
/// - Certain formatting clues are preserved when parsing, allowing to better maintain the original formatting when serializing the values.
/// - Fully Unicode compliant (encodes and decodes as UTF-8).
///
/// For reference of the format, see: <https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/PropertyLists/OldStylePlists/OldStylePLists.html>
public enum PropertyList: Hashable, Sendable {
	case string(ByteString, options: StringOptions)
	case data([UInt8])
	case array([Self], options: ArrayOptions)
	case dictionary([Key: Self], order: [ByteString]?, options: DictionaryOptions)
}

extension PropertyList {
	public struct Key: Hashable, Sendable, ExpressibleByStringLiteral {
		public let string: ByteString
		public let options: StringOptions
		
		@inlinable
		public init(stringLiteral value: StaticString) {
			self.string = ByteString(stringLiteral: value)
			self.options = [] // this init is mainly intended for key access and `options` do not participate in `Hashable` conformance
		}
		
		@inlinable
		public init(string: ByteString, options: StringOptions) {
			self.string = string
			self.options = options
		}
		
		@inlinable @inline(__always)
		public static func == (_ lhs: Self, _ rhs: Self) -> Bool {
			lhs.string == rhs.string
		}
		
		@inlinable
		public func hash(into hasher: inout Hasher) {
			hasher.combine(self.string)
		}
	}
	
	// MARK: - Options
	
	public struct StringOptions: OptionSet, Hashable, Sendable {
		public enum LineFeedEscaping: Sendable {
			/// `"\\n"`, backslash followed by small letter n
			case named
			/// `"\\\n"`, backslash followed by literal line feed
			case literal
			/// `"\\012"`, backslash followed by three-digit octal code for line feed
			case octal
		}
		
		public let rawValue: UInt8
		
		public init(rawValue: UInt8) {
			self.rawValue = rawValue
		}
		
		/// The string is serialized as an unquoted literal.
		public static let unquoted = Self(rawValue: 1 << 0)
		/// The serialized string uses ``LineFeedEscaping.named`` instead of literal line feeds.
		public static let escapedLineFeedsNamed = Self(rawValue: 1 << 1)
		/// The serialized string uses ``LineFeedEscaping.literal`` instead of literal line feeds.
		public static let escapedLineFeedsLiteral = Self(rawValue: 1 << 2)
		/// The serialized string uses ``LineFeedEscaping.octal`` instead of literal line feeds.
		public static let escapedLineFeedsOctal = Self(rawValue: 1 << 3)
		/// The serialized string uses `"\011"` instead of literal horizontal tabs.
		public static let escapedHorizontalTabsOctal = Self(rawValue: 1 << 4)
		
		public var lineFeedEscaping: LineFeedEscaping? {
			if contains(.escapedLineFeedsNamed) {
				.named
			}
			else if contains(.escapedLineFeedsLiteral) {
				.literal
			}
			else if contains(.escapedLineFeedsOctal) {
				.octal
			}
			else {
				nil
			}
		}
	}
	
	public struct ArrayOptions: OptionSet, Hashable, Sendable {
		public let rawValue: UInt8
		
		public init(rawValue: UInt8) {
			self.rawValue = rawValue
		}
		
		/// The serialized array inserts line feeds between elements, after the opening parenthesis, and before the closing parenthesis.
		public static let breakElementsOntoLines = Self(rawValue: 1 << 0)
		/// The last element is followed by a comma.
		public static let trailingComma = Self(rawValue: 1 << 1)
		/// Non-trailing commas are followed by a space character.
		///
		/// Ignored when `breakElementsOntoLines` is set.
		public static let spaceSeparator = Self(rawValue: 1 << 2)
	}
	
	public struct DictionaryOptions: OptionSet, Hashable, Sendable {
		public let rawValue: UInt8
		
		public init(rawValue: UInt8) {
			self.rawValue = rawValue
		}
		
		/// The serialized dictionary inserts line feeds between elements, after the opening brace, and before the closing brace.
		public static let breakElementsOntoLines = Self(rawValue: 1 << 0)
	}
}
