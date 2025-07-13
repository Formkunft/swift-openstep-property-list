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
	/// A view of the property list value that defines is equality and resulting hash value from the underlying (“plain”) value, ignoring formatting.
	public struct PlainView: Hashable {
		@usableFromInline
		let _value: PropertyList
		
		@inlinable
		/* fileprivate */ init(_plist: PropertyList) {
			self._value = _plist
		}
		
		@inlinable
		public static func == (lhs: Self, rhs: Self) -> Bool {
			lhs._value.valueEquals(rhs._value)
		}
		
		@inlinable
		public func hash(into hasher: inout Hasher) {
			switch self._value {
			case .string(let string, options: _):
				hasher.combine(string)
			case .data(let data):
				hasher.combine(data)
			case .array(let array, options: _):
				hasher.combine(array)
			case .dictionary(let dictionary, order: _, options: _):
				hasher.combine(dictionary)
			}
		}
	}
	
	@inlinable @inline(__always)
	public var plain: PlainView {
		PlainView(_plist: self)
	}
	
	/// Whether two property list values are equal, comparing only the underlying (“plain”) value, ignoring formatting.
	@inlinable
	func valueEquals(_ other: PropertyList) -> Bool {
		switch (self, other) {
		case (.string(let s1, options: _), .string(let s2, options: _)):
			return s1 == s2
		case (.data(let d1), .data(let d2)):
			return d1 == d2
		case (.array(let a1, options: _), .array(let a2, options: _)):
			return a1.elementsEqual(a2) { $0.valueEquals($1) }
		case (.dictionary(let d1, order: _, options: _), .dictionary(let d2, order: _, options: _)):
			guard d1.count == d2.count else {
				return false
			}
			for (key, value1) in d1 {
				guard let value2 = d2[key], value1.valueEquals(value2) else {
					return false
				}
			}
			return true
		default:
			return false
		}
	}
}
