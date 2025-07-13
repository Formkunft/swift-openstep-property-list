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

extension PropertyList: Encodable {
	public func encode(to encoder: any Encoder) throws {
		switch self {
		case .string(let byteString, let options):
			var container = encoder.singleValueContainer()
			
			if options.contains(.unquoted), Self.isNumericString(byteString.value) {
				if let int = Int(byteString.value) {
					try container.encode(int)
				}
				else if let double = Double(byteString.value) {
					try container.encode(double)
				}
				else {
					try container.encode(byteString.value)
				}
			}
			else {
				try container.encode(byteString.value)
			}
		case .data(let bytes):
			var container = encoder.singleValueContainer()
			try container.encode(bytes)
		case .array(let array, options: _):
			var container = encoder.unkeyedContainer()
			
			for element in array {
				try container.encode(element)
			}
		case .dictionary(let dictionary, order: _, options: _):
			var container = encoder.container(keyedBy: CustomCodingKey.self)
			
			for (key, value) in dictionary {
				try container.encode(value, forKey: CustomCodingKey(stringValue: key.string.value).unsafelyUnwrapped)
			}
		}
	}
	
	struct CustomCodingKey: CodingKey {
		var stringValue: String
		var intValue: Int? { nil }
		
		init?(stringValue: String) {
			self.stringValue = stringValue
		}
		
		init?(intValue: Int) {
			nil
		}
	}
}

extension PropertyList.Key: Encodable {
	public func encode(to encoder: any Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode(self.string.value)
	}
}
