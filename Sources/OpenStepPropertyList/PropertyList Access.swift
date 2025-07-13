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
	public var asString: ByteString? {
		guard case .string(let string, _) = self else {
			return nil
		}
		return string
	}
	
	@inlinable
	public var asData: [UInt8]? {
		guard case .data(let data) = self else {
			return nil
		}
		return data
	}
	
	@inlinable
	public var asArray: [PropertyList]? {
		guard case .array(let array, _) = self else {
			return nil
		}
		return array
	}
	
	@inlinable
	public var asDictionary: [Key: PropertyList]? {
		guard case .dictionary(let dictionary, _, _) = self else {
			return nil
		}
		return dictionary
	}
}
