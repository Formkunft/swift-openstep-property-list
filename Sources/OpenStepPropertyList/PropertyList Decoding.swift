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

#if TraitFoundation
import Foundation
#endif
import CollectionParser

extension PropertyList {
	public enum ContentError: Error, Equatable {
		case missingContent
		case illegalContent(UInt8)
		case oversuppliedContent
		#if TraitSpan
		case nonUTF8StringContents(UTF8.ValidationError)
		#else
		/// Requires the trait `TraitFoundation` to be set; otherwise, invalid UTF-8 strings are not rejected and replacement characters are used instead.
		case nonUTF8StringContents
		#endif
		case octalCodeOverflowStringEscapeSequence(UInt8, UInt8, UInt8)
		case nonASCIIOctalCodeStringEscapeSequence(UInt8, UInt8, UInt8)
		case incompleteHexadecimalCodeStringEscapeSequence
		case nonUnicodeScalarHexadecimalCodeStringEscapeSequence(UInt16)
		case nonHexadecimalHighByteData(UInt8)
		case missingHexadecimalLowByteData
		case nonHexadecimalLowByteData(UInt8)
		case missingDataEnd
		case missingClosingQuote
		case missingClosingParenthesis
		case missingClosingBrace
		case nonStringKey
		case missingEqualSignInDictionary
		case missingSemicolonInDictionary
		case incompleteCommentStart
		case illegalCommentStart(UInt8)
		case missingCommentEnd
		
		public var errorDescription: String? {
			switch self {
			case .missingContent:
				"Missing content"
			case .illegalContent(let byte):
				"Illegal character 0x\(String(byte, radix: 16, uppercase: true))"
			case .oversuppliedContent:
				"Coding ended before end of file"
			case .nonUTF8StringContents:
				"String value contains invalid UTF-8 data"
			case .octalCodeOverflowStringEscapeSequence(let o1, let o2, let o3):
				"Octal code overflow; 9 bits would be required to represent 0o\(String((UInt16(o1) << 6) | (UInt16(o2) << 3) | UInt16(o3), radix: 8))"
			case .nonASCIIOctalCodeStringEscapeSequence(let o1, let o2, let o3):
				"Non-ASCII octal code; 8 bits would be required to represent 0o\(String((UInt16(o1) << 6) | (UInt16(o2) << 3) | UInt16(o3), radix: 8))"
			case .incompleteHexadecimalCodeStringEscapeSequence:
				"Incomplete hexadecimal code; expected four hexadecimal digits to follow \\U"
			case .nonUnicodeScalarHexadecimalCodeStringEscapeSequence(let value):
				"Hexadecimal value does no represent Unicode scalar: 0x\(String(value, radix: 16, uppercase: true))"
			case .nonHexadecimalHighByteData(let byte):
				"Non-hexadecimal high byte in data value: 0x\(String(byte, radix: 16, uppercase: true))"
			case .missingHexadecimalLowByteData:
				"Missing low byte in hexadecimal data value"
			case .nonHexadecimalLowByteData(let byte):
				"Non-hexadecimal low byte in data value: 0x\(String(byte, radix: 16, uppercase: true))"
			case .missingDataEnd:
				"Missing closing angle bracket (greater-than sign); data value not properly terminated"
			case .missingClosingQuote:
				"Missing closing quote; string not properly terminated"
			case .missingClosingParenthesis:
				"Missing closing parenthesis; array not properly terminated (or: missing separator comma)"
			case .missingClosingBrace:
				"Missing closing curly brace; dictionary not properly terminated"
			case .nonStringKey:
				"Dictionary key is not a string value"
			case .missingEqualSignInDictionary:
				"Missing equals sign following key in dictionary"
			case .missingSemicolonInDictionary:
				"Missing semicolon following value in dictionary"
			case .incompleteCommentStart:
				"Incomplete comment start"
			case .illegalCommentStart(let char):
				"Comment requires `*` or `/` after first `/`, got 0x\(String(char, radix: 16, uppercase: true)) instead."
			case .missingCommentEnd:
				"Missing comment end; comment not properly terminated"
			}
		}
	}
	
	public struct DecodingError: Error, Equatable {
		public let contentError: ContentError
		public let line: Int
		public let column: Int
		
		@usableFromInline
		init(contentError: ContentError, line: Int, column: Int) {
			self.contentError = contentError
			self.line = line
			self.column = column
		}
	}
	
	/// Returns whether a code point is valid in an unquoted string literal.
	///
	/// This implementation differs from the standard property list format by also allowing the plus symbol.
	@inlinable
	public static func isUnquotedStringCharacter(codePoint c: UInt8) -> Bool {
		// a-z, A-Z, - . / 0-9 :, _, $, +
		(c >= UInt8(ascii: "a") && c <= UInt8(ascii: "z")) || (c >= UInt8(ascii: "A") && c <= UInt8(ascii: "Z")) || (c >= UInt8(ascii: "-") && c <= UInt8(ascii: ":")) || c == UInt8(ascii: "_") || c == UInt8(ascii: "$") || c == UInt8(ascii: "+")
	}
	
	@usableFromInline
	static func decodeHexadecimalValue(_ digit: UInt8) -> UInt8? {
		if digit >= UInt8(ascii: "0") && digit <= UInt8(ascii: "9") {
			digit - UInt8(ascii: "0")
		}
		else if digit >= UInt8(ascii: "A") && digit <= UInt8(ascii: "F") {
			10 + (digit - UInt8(ascii: "A"))
		}
		else if digit >= UInt8(ascii: "a") && digit <= UInt8(ascii: "f") {
			10 + (digit - UInt8(ascii: "a"))
		}
		else {
			nil
		}
	}
	
	@usableFromInline
	static func skipTrivia(parser: inout Parser<UnsafeBufferPointer<UInt8>>) throws(ContentError) {
		while let c = parser.peek() {
			if (c >= UInt8(ascii: "\t") && c <= UInt8(ascii: "\r")) || c == UInt8(ascii: " ") {
				// ASCII whitespace: \t, \n, vertical tab, form feed, \r, or space
				parser.advance()
			}
			else if c == 0xE2, let (_, a, b) = parser.peek(), a == 0x80, b == 0xA8 || b == 0xA9 {
				// Unicode whitespace: U+2028 LINE SEPARATOR or U+2029 PARAGRAPH SEPARATOR
				parser.advance(by: 3)
			}
			else if c == UInt8(ascii: "/") {
				// comment
				parser.advance()
				
				switch parser.pop() {
				case UInt8(ascii: "/"):
					// single-line comment
					parser.advance { c, parser in
						if c == UInt8(ascii: "\n") || c == UInt8(ascii: "\r") {
							// ASCII line break
							false
						}
						else if c == 0xE2, let (_, a, b) = parser.peek(), a == 0x80, b == 0xA8 || b == 0xA9 {
							// Unicode line break: U+2028 LINE SEPARATOR or U+2029 PARAGRAPH SEPARATOR
							false
						}
						else {
							true
						}
					}
				case UInt8(ascii: "*"):
					// multi-line comment
					parser.advance { c, parser in
						if c == UInt8(ascii: "*"), let (_, b) = parser.peek(), b == UInt8(ascii: "/") {
							false
						}
						else {
							true
						}
					}
					guard parser.pop(UInt8(ascii: "*")) && parser.pop(UInt8(ascii: "/")) else {
						throw .missingCommentEnd
					}
				case let char?:
					throw .illegalCommentStart(char)
				case nil:
					throw .incompleteCommentStart
				}
			}
			else {
				break
			}
		}
	}
	
	@usableFromInline
	static func skipWhitespace(parser: inout Parser<UnsafeBufferPointer<UInt8>>) {
		while let c = parser.peek() {
			if (c >= UInt8(ascii: "\t") && c <= UInt8(ascii: "\r")) || c == UInt8(ascii: " ") {
				// ASCII whitespace: \t, \n, vertical tab, form feed, \r, or space
				parser.advance()
			}
			else if c == 0xE2, let (_, a, b) = parser.peek(), a == 0x80, b == 0xA8 || b == 0xA9 {
				// Unicode whitespace: U+2028 LINE SEPARATOR or U+2029 PARAGRAPH SEPARATOR
				parser.advance(by: 3)
			}
			else {
				break
			}
		}
	}
	
	@usableFromInline
	static func parsePropertyList(
		parser: inout Parser<UnsafeBufferPointer<UInt8>>,
		keySubset: Set<String>?,
		isSkipping: Bool,
	) throws(ContentError) -> Self {
		try Self.skipTrivia(parser: &parser)
		
		guard let head = parser.peek() else {
			throw .missingContent
		}
		
		switch head {
		case UInt8(ascii: "("):
			parser.advance()
			
			var array: [Self]? = isSkipping ? nil : []
			var options: Self.ArrayOptions = []
			
			if parser.peek() == UInt8(ascii: "\n") {
				options.insert(.breakElementsOntoLines)
			}
			
			try Self.skipTrivia(parser: &parser)
			
			var isUsingTrailingComma = false
			var isUsingSpaceSeparator = false
			
			while parser.peek() != UInt8(ascii: ")") {
				let value = try parsePropertyList(parser: &parser, keySubset: nil, isSkipping: isSkipping)
				array?.append(value)
				
				try Self.skipTrivia(parser: &parser)
				
				if parser.pop(UInt8(ascii: ",")) {
					isUsingTrailingComma = true
					
					if parser.pop(UInt8(ascii: " ")) {
						isUsingSpaceSeparator = true
					}
					
					try Self.skipTrivia(parser: &parser)
				}
				else {
					isUsingTrailingComma = false
					break
				}
			}
			
			guard parser.pop(UInt8(ascii: ")")) else {
				throw .missingClosingParenthesis
			}
			
			if isUsingTrailingComma {
				options.insert(.trailingComma)
			}
			
			if isUsingSpaceSeparator {
				options.insert(.spaceSeparator)
			}
			
			try Self.skipTrivia(parser: &parser)
			
			if let array {
				return .array(array, options: options)
			}
			else {
				return .array([], options: options)
			}
		case UInt8(ascii: "{"):
			parser.advance()
			
			var dictionary: [Key: Self]? = isSkipping ? nil : [:]
			var options: Self.DictionaryOptions = []
			var order: [ByteString]? = isSkipping ? nil : []
			
			if parser.peek() == UInt8(ascii: "\n") {
				options.insert(.breakElementsOntoLines)
			}
			
			try Self.skipTrivia(parser: &parser)
			
			while parser.peek() != UInt8(ascii: "}") {
				let key = try parsePropertyList(parser: &parser, keySubset: nil, isSkipping: isSkipping)
				guard case .string(let keyString, let keyOptions) = key else {
					throw .nonStringKey
				}
				let nestedIsSkipping = isSkipping || (keySubset.map { !$0.contains(keyString.value) } ?? false)
				
				order?.append(keyString)
				
				try Self.skipTrivia(parser: &parser)
				
				guard parser.pop(UInt8(ascii: "=")) else {
					throw .missingEqualSignInDictionary
				}
				
				try Self.skipTrivia(parser: &parser)
				
				let value = try parsePropertyList(parser: &parser, keySubset: nil, isSkipping: nestedIsSkipping)
				
				try Self.skipTrivia(parser: &parser)
				
				guard parser.pop(UInt8(ascii: ";")) else {
					throw .missingSemicolonInDictionary
				}
				
				try Self.skipTrivia(parser: &parser)
				
				if !nestedIsSkipping {
					dictionary![Key(string: keyString, options: keyOptions)] = value
				}
			}
			
			guard parser.pop(UInt8(ascii: "}")) else {
				throw .missingClosingBrace
			}
			
			try Self.skipTrivia(parser: &parser)
			
			let isSorted = if let order {
				zip(order, order.dropFirst()).allSatisfy(<)
			}
			else {
				true
			}
			
			if let dictionary {
				return .dictionary(dictionary, order: isSorted ? nil : order, options: options)
			}
			else {
				return .dictionary([:], order: nil, options: options)
			}
		case UInt8(ascii: "\""), UInt8(ascii: "'"):
			var buffer = isSkipping ? nil : ""
			var lineFeedEscaping: StringOptions.LineFeedEscaping? = nil
			var escapedHorizontalTabsOctal = false
			
			parser.advance()
			
			while true {
				let chunk = parser.read(while: { $0 != head && $0 != UInt8(ascii: "\\") })
				
				if !isSkipping {
					#if TraitSpan
					let utf8Span: UTF8Span
					do {
						utf8Span = try UTF8Span(validating: UnsafeBufferPointer(rebasing: chunk).span)
					}
					catch {
						throw .nonUTF8StringContents(error)
					}
					let stringChunk = String(copying: utf8Span)
					#elseif TraitFoundation
					guard let stringChunk = String(bytes: chunk, encoding: .utf8) else {
						throw .nonUTF8StringContents
					}
					#else
					let stringChunk = String(decoding: chunk, as: UTF8.self)
					#endif
					buffer!.append(stringChunk)
				}
				
				guard let stopChar = parser.pop() else {
					throw .missingClosingQuote
				}
				
				if stopChar == head {
					break
				}
				else if stopChar == UInt8(ascii: "\\") {
					guard let specialChar = parser.pop() else {
						throw .missingClosingQuote
					}
					
					let octalRange: ClosedRange<UInt8> = UInt8(ascii: "0") ... UInt8(ascii: "7")
					
					switch specialChar {
					case UInt8(ascii: "\\"):
						buffer?.append("\\" as Character)
					case UInt8(ascii: "a"):
						buffer?.append("\u{07}" as Character)
					case UInt8(ascii: "b"):
						buffer?.append("\u{08}" as Character)
					case UInt8(ascii: "e"):
						buffer?.append("\u{1B}" as Character)
					case UInt8(ascii: "f"):
						buffer?.append("\u{0C}" as Character)
					case UInt8(ascii: "n"):
						buffer?.append("\n" as Character)
						lineFeedEscaping = .named
					case UInt8(ascii: "r"):
						buffer?.append("\r" as Character)
					case UInt8(ascii: "t"):
						buffer?.append("\t" as Character)
					case UInt8(ascii: "v"):
						buffer?.append("\u{0B}" as Character)
					case UInt8(ascii: "\n"):
						buffer?.append("\n" as Character)
						lineFeedEscaping = .literal
					case octalRange:
						let a1 = specialChar - UInt8(ascii: "0")
						// 0oX == 0bABC
						var codePoint = a1
						
						if let d2 = parser.pop(), octalRange.contains(d2) {
							let a2 = d2 - UInt8(ascii: "0")
							// 0oXY = 0bABC_DEF
							codePoint = (codePoint << 3) | a2
							
							if let d3 = parser.pop(), octalRange.contains(d3) {
								let a3 = d3 - UInt8(ascii: "0")
								
								if a1 >= 0b10 {
									if a1 >= 0b100 {
										// 'A' bit is 1 => 9 bits required => overflow
										throw .octalCodeOverflowStringEscapeSequence(a1, a2, a3)
									}
									else {
										// 'B' bit is 1 => 8 bits => not ASCII
										throw .nonASCIIOctalCodeStringEscapeSequence(a1, a2, a3)
									}
								}
								
								// 0oXYZ = 0b00C_DEF_GHI
								codePoint = (codePoint << 3) | a3
							}
						}
						
						buffer?.append(Character(Unicode.Scalar(codePoint)))
						
						if codePoint == 0o011 {
							escapedHorizontalTabsOctal = true
						}
						else if codePoint == 0o012 {
							lineFeedEscaping = .octal
						}
					case UInt8(ascii: "U"):
						guard let d1 = parser.pop(),
						      let a1 = Self.decodeHexadecimalValue(d1),
						      let d2 = parser.pop(),
						      let a2 = Self.decodeHexadecimalValue(d2),
						      let d3 = parser.pop(),
						      let a3 = Self.decodeHexadecimalValue(d3),
						      let d4 = parser.pop(),
						      let a4 = Self.decodeHexadecimalValue(d4) else {
							throw .incompleteHexadecimalCodeStringEscapeSequence
						}
						
						let codePoint = UInt16(a1) << 12 | UInt16(a2) << 8 | UInt16(a3) << 4 | UInt16(a4)
						
						guard let scalar = Unicode.Scalar(codePoint) else {
							throw .nonUnicodeScalarHexadecimalCodeStringEscapeSequence(codePoint)
						}
						
						buffer?.append(Character(scalar))
					default:
						buffer?.append(Character(Unicode.Scalar(specialChar)))
					}
				}
			}
			
			var options: Self.StringOptions = []
			
			if escapedHorizontalTabsOctal {
				options.insert(.escapedHorizontalTabsOctal)
			}
			
			if let lineFeedEscaping {
				switch lineFeedEscaping {
				case .named:
					options.insert(.escapedLineFeedsNamed)
				case .literal:
					options.insert(.escapedLineFeedsLiteral)
				case .octal:
					options.insert(.escapedLineFeedsOctal)
				}
			}
			
			if let buffer {
				return .string(ByteString(buffer), options: options)
			}
			else {
				return .string(ByteString(value: "", uncheckedIsASCII: true), options: options)
			}
		case UInt8(ascii: "<"):
			parser.advance()
			
			Self.skipWhitespace(parser: &parser)
			
			var buffer: [UInt8]? = isSkipping ? nil : []
			
			while let d1 = parser.peek(), d1 != UInt8(ascii: ">") {
				parser.advance()
				
				guard let a1 = Self.decodeHexadecimalValue(d1) else {
					throw .nonHexadecimalHighByteData(d1)
				}
				
				Self.skipWhitespace(parser: &parser)
				
				guard let d2 = parser.pop(), d2 != UInt8(ascii: ">") else {
					throw .missingHexadecimalLowByteData
				}
				guard let a2 = Self.decodeHexadecimalValue(d2) else {
					throw .nonHexadecimalLowByteData(d2)
				}
				
				buffer?.append((a1 << 4) | a2)
				
				Self.skipWhitespace(parser: &parser)
			}
			
			guard parser.pop() == UInt8(ascii: ">") else {
				throw .missingDataEnd
			}
			
			if let buffer {
				return .data(buffer)
			}
			else {
				return .data([])
			}
		default:
			if Self.isUnquotedStringCharacter(codePoint: head) {
				let stringBytes = parser.read(while: Self.isUnquotedStringCharacter(codePoint:))
				if !isSkipping {
					let string = String(decoding: stringBytes, as: UTF8.self)
					return .string(ByteString(string), options: .unquoted)
				}
				else {
					return .string(ByteString(value: "", uncheckedIsASCII: true), options: .unquoted)
				}
			}
			else {
				throw .illegalContent(head)
			}
		}
	}
	
	/// Reads a property list value from the given bytes.
	///
	/// - Throws: `DecodingError` if parsing failed.
	@available(macOS 10.15, iOS 13, tvOS 13, visionOS 1, watchOS 6, *)
	@inlinable
	@concurrent
	public init(
		concurrentDecoding bytes: UnsafeBufferPointer<UInt8>,
		topLevelKeys: Set<String>? = nil,
	) async throws(DecodingError) {
		try self.init(decoding: bytes, topLevelKeys: topLevelKeys)
	}
	
	/// Reads a property list value from the given bytes.
	///
	/// - Throws: `DecodingError` if parsing failed.
	@inlinable
	public init(
		decoding bytes: UnsafeBufferPointer<UInt8>,
		topLevelKeys: Set<String>? = nil,
	) throws(DecodingError) {
		var parser = Parser(subject: bytes)
		
		do throws(ContentError) {
			self = try Self.parsePropertyList(parser: &parser, keySubset: topLevelKeys, isSkipping: false)
			
			try Self.skipTrivia(parser: &parser)
			
			guard parser.isAtEnd else {
				throw .oversuppliedContent
			}
		}
		catch {
			let subject = parser.subject
			let headIndex = parser.position
			let line = subject[subject.startIndex ..< headIndex].count { $0 == UInt8(ascii: "\n") } + 1
			let lastLineFeed = subject[subject.startIndex ..< headIndex].lastIndex(of: UInt8(ascii: "\n"))
			let column = if let lastLineFeed {
				subject.distance(from: lastLineFeed, to: headIndex)
			}
			else {
				subject.distance(from: subject.startIndex, to: headIndex) + 1
			}
			throw DecodingError(
				contentError: error,
				line: line,
				column: column)
		}
	}
	
	public init(
		decoding string: String,
		topLevelKeys: Set<String>? = nil,
	) throws(DecodingError) {
		var string = string
		do {
			self = try string.withUTF8 {
				try Self(decoding: $0, topLevelKeys: topLevelKeys)
			}
		}
		catch let error as DecodingError {
			throw error
		}
		catch {
			preconditionFailure("unreachable")
		}
	}
	
	#if TraitFoundation
	@available(macOS 10.15, iOS 13, tvOS 13, visionOS 1, watchOS 6, *)
	@inlinable
	@concurrent
	public init(
		concurrentDecoding data: Data,
		topLevelKeys: Set<String>? = nil,
	) async throws(DecodingError) {
		do {
			self = try data.withUnsafeBytes {
				try Self(decoding: $0.assumingMemoryBound(to: UInt8.self), topLevelKeys: topLevelKeys)
			}
		}
		catch let error as DecodingError {
			throw error
		}
		catch {
			preconditionFailure("unreachable")
		}
	}
	
	@inlinable
	public init(
		decoding data: Data,
		topLevelKeys: Set<String>? = nil,
	) throws(DecodingError) {
		do {
			self = try data.withUnsafeBytes {
				try Self(decoding: $0.assumingMemoryBound(to: UInt8.self), topLevelKeys: topLevelKeys)
			}
		}
		catch let error as DecodingError {
			throw error
		}
		catch {
			preconditionFailure("unreachable")
		}
	}
	#endif
	
	public init(
		decoding bytes: [UInt8],
		topLevelKeys: Set<String>? = nil,
	) throws(DecodingError) {
		do {
			self = try bytes.withUnsafeBufferPointer {
				try Self(decoding: $0, topLevelKeys: topLevelKeys)
			}
		}
		catch let error as DecodingError {
			throw error
		}
		catch {
			preconditionFailure("unreachable")
		}
	}
}

#if TraitFoundation

extension PropertyList.ContentError: LocalizedError {}

extension PropertyList.DecodingError: LocalizedError {
	public var errorDescription: String? {
		"[\(self.line):\(self.column)] \(self.contentError.localizedDescription)"
	}
}

#endif
