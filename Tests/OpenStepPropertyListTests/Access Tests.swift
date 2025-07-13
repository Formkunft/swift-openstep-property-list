import Testing
import OpenStepPropertyList

struct Access {
	@Test func keyPath() {
		let plist: PropertyList = [
			"config": [
				"names": [
					"Name 1",
					"Name 2",
					"Name 3",
				],
			],
		]
		#expect(plist["config"]?["names"] == ["Name 1", "Name 2", "Name 3"])
		#expect(plist["config"]?["names"]?[1] == "Name 2")
	}
}
