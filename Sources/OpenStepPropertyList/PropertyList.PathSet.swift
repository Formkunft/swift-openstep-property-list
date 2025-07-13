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

extension PropertyList {
	public struct PathSet {
		public enum Component: Hashable {
			case key(ByteString)
			case index(Int)
		}
		
		public let branches: [Component: PathSet]
		
		@inlinable
		public init(_ branches: [Component: PathSet]) {
			self.branches = branches
		}
	}
}

extension PropertyList.PathSet {
	@inlinable
	public init() {
		self.branches = [:]
	}
	
	@inlinable
	public var isEmpty: Bool {
		self.branches.isEmpty
	}
	
	@inlinable
	public var keys: Dictionary<Component, Self>.Keys {
		self.branches.keys
	}
	
	@inlinable
	public subscript(component: Component) -> Self? {
		self.branches[component]
	}
	
	@inlinable
	public subscript(key: ByteString) -> Self? {
		self.branches[.key(key)]
	}
	
	@inlinable
	public subscript(index: Int) -> Self? {
		self.branches[.index(index)]
	}
}
