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
public protocol PropertyListProtocol {
	func stringValue() -> ByteString?
	
	func dataValue() -> [UInt8]?
	
	func arrayElements() -> AnySequence<any PropertyListProtocol>?
	
	func dictionaryValue() -> (any PropertyListDictionaryProtocol)?
}

public protocol PropertyListDictionaryProtocol {
	subscript(key: ByteString) -> (any PropertyListProtocol)? { get }
}

// MARK: Implementation

extension PropertyList: PropertyListProtocol {
	public func stringValue() -> ByteString? {
		self.asString
	}
	
	public func dataValue() -> [UInt8]? {
		self.asData
	}
	
	public func arrayElements() -> AnySequence<any PropertyListProtocol>? {
		guard let array = self.asArray else {
			return nil
		}
		return AnySequence(array)
	}
	
	public func dictionaryValue() -> (any PropertyListDictionaryProtocol)? {
		guard let dictionary = self.asDictionary else {
			return nil
		}
		return PropertyListDictionary(dictionary)
	}
}

struct PropertyListDictionary: PropertyListDictionaryProtocol {
	private let dictionary: [PropertyList.Key: PropertyList]
	
	init(_ dictionary: [PropertyList.Key: PropertyList]) {
		self.dictionary = dictionary
	}
	
	public subscript(key: ByteString) -> (any PropertyListProtocol)? {
		self.dictionary[PropertyList.Key(string: key, options: [])]
	}
}
#endif
