import XCTest
@testable import CrossBluetooth

final class CrossBluetoothTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(CrossBluetooth().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
