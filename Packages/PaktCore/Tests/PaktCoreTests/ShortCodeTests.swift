import XCTest
@testable import PaktCore

final class ShortCodeTests: XCTestCase {
    func testBoxShortCodeShape() {
        for _ in 0..<50 {
            let code = ShortCode.generateBoxShortCode()
            XCTAssertTrue(code.hasPrefix("B-"))
            XCTAssertEqual(code.count, 6)
            let body = code.dropFirst(2)
            for ch in body {
                XCTAssertTrue("23456789ABCDEFGHJKLMNPQRSTUVWXYZ".contains(ch),
                              "unsafe char \(ch) in \(code)")
            }
        }
    }

    func testIdShape() {
        let id = ShortCode.generateId(.item)
        XCTAssertTrue(id.hasPrefix("itm_"))
        let body = id.dropFirst(4)
        XCTAssertEqual(body.count, 10)
        let allowed = CharacterSet.alphanumerics
        XCTAssertTrue(body.unicodeScalars.allSatisfy { allowed.contains($0) })
    }

    func testInviteTokenLength() {
        let t = ShortCode.generateInviteToken()
        XCTAssertEqual(t.count, 32)
    }
}
