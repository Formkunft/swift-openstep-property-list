//
//  Copyright 2024 Florian Pircher
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

extension PropertyList: ExpressibleByStringLiteral {
	@inlinable
	public init(stringLiteral value: StringLiteralType) {
		self = .string(ByteString(value), options: [])
	}
}

extension PropertyList: ExpressibleByIntegerLiteral {
	@inlinable
	public init(integerLiteral value: Int) {
		self = .number(value)
	}
}

extension PropertyList: ExpressibleByFloatLiteral {
	@inlinable
	public init(floatLiteral value: Double) {
		self = .number(value)!
	}
}

extension PropertyList: ExpressibleByArrayLiteral {
	public typealias ArrayLiteralElement = PropertyList
	
	@inlinable
	public init(arrayLiteral elements: ArrayLiteralElement...) {
		self = .array(elements, options: [])
	}
}

extension PropertyList: ExpressibleByDictionaryLiteral {
	public typealias Value = PropertyList
	
	@inlinable
	public init(dictionaryLiteral elements: (Key, Value)...) {
		var dictionary = [Key: Value](minimumCapacity: elements.count)
		var isSorted = true
		var previousKey: ByteString?
		
		for (key, value) in elements {
			dictionary[key] = value
			
			if isSorted {
				if let previousKey, previousKey >= key.string {
					isSorted = false
				}
				previousKey = key.string
			}
		}
		
		let order = isSorted ? nil : elements.map { $0.0.string }
		
		self = .dictionary(dictionary, order: order, options: [])
	}
}
