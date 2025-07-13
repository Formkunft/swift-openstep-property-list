import Testing
import OpenStepPropertyList

struct ByteString_Tests {
	@Test(
		arguments: [
			("alpha", "beta"),
			("Alpha", "Beta"),
			("Alpha", "alpha"),
			(".name", "name"),
			(".name", "Name"),
		]
	) func comparable(testCase: (lhs: ByteString, rhs: ByteString)) throws {
		#expect(testCase.lhs < testCase.rhs)
	}
}
