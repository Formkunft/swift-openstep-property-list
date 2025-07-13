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

extension PropertyList {
	@inlinable
	public subscript(key: ByteString) -> PropertyList? {
		guard let dictionary = self.asDictionary else {
			return nil
		}
		return dictionary[Key(string: key, options: [])]
	}
	
	@_disfavoredOverload
	@inlinable
	public subscript(key: Key) -> PropertyList? {
		guard let dictionary = self.asDictionary else {
			return nil
		}
		return dictionary[key]
	}
	
	@inlinable
	public subscript(index: Int) -> PropertyList? {
		guard let array = self.asArray else {
			return nil
		}
		return array.indices.contains(index) ? array[index] : nil
	}
}
