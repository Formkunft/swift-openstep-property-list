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

extension PropertyList {
	public typealias EncodingBuffer = [UInt8]
	
	public struct EncodingConfiguration {
		public enum Indentation {
			case spaces(UInt8)
			case tabs
		}
		
		public let indentation: [UInt8]?
		public var level: Int
		
		public init(indentation: Indentation?, level: Int = 0) {
			self.indentation = switch indentation {
			case .spaces(let count):
				if count > 0 {
					[UInt8](repeating: UInt8(ascii: " "), count: Int(count))
				}
				else {
					nil
				}
			case .tabs:
				[UInt8(ascii: "\t")]
			case nil:
				nil
			}
			self.level = level
		}
	}
	
	@inlinable
	public func encode(
		to buffer: inout EncodingBuffer,
		configuration: EncodingConfiguration
	) {
		switch self {
		case .string(let byteString, options: let options):
			Self.encodeString(
				byteString,
				to: &buffer,
				prefersUnquoted: options.contains(.unquoted),
				lineFeedEscaping: options.lineFeedEscaping,
				escapedHorizontalTabsOctal: options.contains(.escapedHorizontalTabsOctal))
		case .data(let data):
			Self.encodeData(
				data,
				to: &buffer)
		case .array(let array, options: let options):
			Self.encodeArray(
				array,
				to: &buffer,
				configuration: configuration,
				breakElementsOntoLines: options.contains(.breakElementsOntoLines),
				trailingComma: options.contains(.trailingComma),
				spaceSeparator: options.contains(.spaceSeparator)
			) { element, buffer, configuration in
				element.encode(to: &buffer, configuration: configuration)
			}
		case .dictionary(let dictionary, order: let order, options: let options):
			Self.encodeDictionary(
				dictionary,
				to: &buffer,
				configuration: configuration,
				order: order,
				breakElementsOntoLines: options.contains(.breakElementsOntoLines)
			) { element, buffer, configuration in
				element.encode(to: &buffer, configuration: configuration)
			}
		}
	}
	
	@inlinable
	public static func encodeString(
		_ byteString: ByteString,
		to buffer: inout EncodingBuffer,
		prefersUnquoted: Bool,
		lineFeedEscaping: PropertyList.StringOptions.LineFeedEscaping?,
		escapedHorizontalTabsOctal: Bool
	) {
		let isUnquoted = prefersUnquoted && !byteString.isEmpty && byteString.utf8.allSatisfy(PropertyList.isUnquotedStringCharacter(codePoint:))
		
		if isUnquoted {
			buffer.append(contentsOf: byteString.utf8)
		}
		else {
			buffer.append(UInt8(ascii: "\""))
			
			var iterator = byteString.utf8.makeIterator()
			
			func writeLineFeed() {
				switch lineFeedEscaping {
				case .named:
					buffer.append(UInt8(ascii: "\\"))
					buffer.append(UInt8(ascii: "n"))
				case .literal:
					buffer.append(UInt8(ascii: "\\"))
					buffer.append(UInt8(ascii: "\n"))
				case .octal:
					buffer.append(UInt8(ascii: "\\"))
					buffer.append(UInt8(ascii: "0"))
					buffer.append(UInt8(ascii: "1"))
					buffer.append(UInt8(ascii: "2"))
				case nil:
					buffer.append(UInt8(ascii: "\n"))
				}
			}
			
			func write(byte: UInt8) {
				switch byte {
				case UInt8(ascii: "\t"):
					if escapedHorizontalTabsOctal {
						buffer.append(UInt8(ascii: "\\"))
						buffer.append(UInt8(ascii: "0"))
						buffer.append(UInt8(ascii: "1"))
						buffer.append(UInt8(ascii: "1"))
					}
					else {
						buffer.append(UInt8(ascii: "\t"))
					}
				case UInt8(ascii: "\\"):
					buffer.append(UInt8(ascii: "\\"))
					buffer.append(UInt8(ascii: "\\"))
				case UInt8(ascii: "\""):
					buffer.append(UInt8(ascii: "\\"))
					buffer.append(UInt8(ascii: "\""))
				case UInt8(ascii: "\r"):
					if let nextByte = iterator.next(), nextByte != UInt8(ascii: "\n") {
						// next byte exists and it is not a line feed
						// => write carriage return as line feed and write next byte
						writeLineFeed()
						write(byte: nextByte)
					}
					else {
						// next byte does not exist or it is a line feed
						// => write a single line feed for the string-terminating \r or the \r\n sequence
						writeLineFeed()
					}
				case UInt8(ascii: "\n"):
					writeLineFeed()
				default:
					buffer.append(byte)
				}
			}
			
			while let byte = iterator.next() {
				write(byte: byte)
			}
			
			buffer.append(UInt8(ascii: "\""))
		}
	}
	
	@usableFromInline
	/* private */ static let hexadecimalASCIIDataEncodingMap: [(UInt8, UInt8)] = {
		var map: [(UInt8, UInt8)] = []
		
		var a: UInt8 = UInt8(ascii: "0")
		var b: UInt8 = UInt8(ascii: "0")
		
		func advance(_ x: inout UInt8) -> Bool {
			if x == UInt8(ascii: "9") {
				x = UInt8(ascii: "a")
				return false
			}
			else if x == UInt8(ascii: "f") {
				x = UInt8(ascii: "0")
				return true
			}
			else {
				x += 1
				return false
			}
		}
		
		for byte in 0 ... UInt8.max {
			map.append((a, b))
			
			if advance(&b) {
				_ = advance(&a)
			}
		}
		
		return map
	}()
	
	@inlinable
	public static func encodeData(
		_ data: [UInt8],
		to buffer: inout EncodingBuffer
	) {
		buffer.append(UInt8(ascii: "<"))
		
		for byte in data {
			let (a, b) = self.hexadecimalASCIIDataEncodingMap[Int(byte)]
			buffer.append(a)
			buffer.append(b)
		}
		
		buffer.append(UInt8(ascii: ">"))
	}
	
	@inlinable
	public static func encodeIndentation(
		for configuration: EncodingConfiguration,
		to buffer: inout EncodingBuffer
	) {
		guard let indentation = configuration.indentation else {
			return
		}
		for _ in 0 ..< configuration.level {
			buffer.append(contentsOf: indentation)
		}
	}
	
	@inlinable
	public static func encodeArray<T>(
		_ elements: some Sequence<T>,
		to buffer: inout EncodingBuffer,
		configuration: EncodingConfiguration,
		breakElementsOntoLines: Bool,
		trailingComma: Bool,
		spaceSeparator: Bool,
		encodeElement: (
			_ element: T,
			_ buffer: inout EncodingBuffer,
			_ configuration: EncodingConfiguration
		) -> ()
	) {
		buffer.append(UInt8(ascii: "("))
		
		var innerConfiguration = configuration
		innerConfiguration.level += 1
		
		if breakElementsOntoLines {
			buffer.append(UInt8(ascii: "\n"))
		}
		
		var isFirstElement = true
		
		for element in elements {
			if isFirstElement {
				isFirstElement = false
			}
			else {
				buffer.append(UInt8(ascii: ","))
				
				if breakElementsOntoLines {
					buffer.append(UInt8(ascii: "\n"))
				}
				else if spaceSeparator {
					buffer.append(UInt8(ascii: " "))
				}
			}
			
			if breakElementsOntoLines {
				self.encodeIndentation(for: innerConfiguration, to: &buffer)
			}
			encodeElement(element, &buffer, innerConfiguration)
		}
		
		if !isFirstElement {
			if trailingComma {
				buffer.append(UInt8(ascii: ","))
			}
			if breakElementsOntoLines {
				buffer.append(UInt8(ascii: "\n"))
			}
		}
		
		if breakElementsOntoLines {
			self.encodeIndentation(for: configuration, to: &buffer)
		}
		buffer.append(UInt8(ascii: ")"))
	}
	
	@inlinable
	public static func encodeDictionary<T>(
		_ dictionary: [Key: T],
		to buffer: inout EncodingBuffer,
		configuration: EncodingConfiguration,
		order: [ByteString]?,
		breakElementsOntoLines: Bool,
		encodeValue: (
			_ element: T,
			_ buffer: inout EncodingBuffer,
			_ configuration: EncodingConfiguration
		) -> ()
	) {
		buffer.append(UInt8(ascii: "{"))
		
		var innerConfiguration = configuration
		innerConfiguration.level += 1
		
		if breakElementsOntoLines {
			buffer.append(UInt8(ascii: "\n"))
		}
		
		func encodeElement(key: Key, value: T) {
			if breakElementsOntoLines {
				self.encodeIndentation(for: innerConfiguration, to: &buffer)
			}
			
			self.encodeString(
				key.string,
				to: &buffer,
				prefersUnquoted: key.options.contains(.unquoted),
				lineFeedEscaping: key.options.lineFeedEscaping,
				escapedHorizontalTabsOctal: key.options.contains(.escapedHorizontalTabsOctal))
			
			buffer.append(UInt8(ascii: " "))
			buffer.append(UInt8(ascii: "="))
			buffer.append(UInt8(ascii: " "))
			
			encodeValue(value, &buffer, innerConfiguration)
			
			buffer.append(UInt8(ascii: ";"))
			
			if breakElementsOntoLines {
				buffer.append(UInt8(ascii: "\n"))
			}
		}
		
		if let order {
			precondition(order.count == dictionary.count)
			
			for key in order {
				let index = dictionary.index(forKey: Key(string: key, options: []))!
				let element = dictionary[index]
				encodeElement(key: element.key, value: element.value)
			}
		}
		else {
			for (key, value) in dictionary.sorted(by: { $0.key.string < $1.key.string }) {
				encodeElement(key: key, value: value)
			}
		}
		
		if breakElementsOntoLines {
			self.encodeIndentation(for: configuration, to: &buffer)
		}
		buffer.append(UInt8(ascii: "}"))
	}
}
