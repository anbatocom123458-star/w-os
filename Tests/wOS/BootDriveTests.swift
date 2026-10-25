import XCTest
@testable import wOS

final class BootDriveTests: XCTestCase {

    func testBootDriveModeLabels() {
        XCTAssertEqual(BootDriveMode.none.label, "Chưa chọn")
        XCTAssertEqual(BootDriveMode.adminBuilt.label, "Drive do Admin build")
        XCTAssertEqual(
            BootDriveMode.selfBuild(source: "https://github.com/anbatocom123458-star/w-os").label,
            "Tự build từ: https://github.com/anbatocom123458-star/w-os"
        )
    }

    func testBootDriveModeCodableRoundTrip() throws {
        let original: BootDriveMode = .selfBuild(source: "https://example.com/repo.git")
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BootDriveMode.self, from: encoded)
        XCTAssertEqual(decoded, original)

        let admin = BootDriveMode.adminBuilt
        let adminDecoded = try JSONDecoder().decode(BootDriveMode.self, from: try JSONEncoder().encode(admin))
        XCTAssertEqual(adminDecoded, .adminBuilt)
    }

    func testBootDriveErrorDescriptions() {
        XCTAssertEqual(BootDriveError.invalidURL.errorDescription, "URL repo không hợp lệ.")
        XCTAssertEqual(BootDriveError.unreachable(404).errorDescription, "Không thể kết nối repo (mã lỗi 404).")
        XCTAssertEqual(BootDriveError.unreachable(0).errorDescription, "Không thể kết nối repo (mã lỗi 0).")
    }

    func testBuildFromRepoRejectsInvalidURL() {
        let service = BootDriveService()
        let expectation = XCTestExpectation(description: "invalid URL fails with BootDriveError.invalidURL")
        service.buildFromRepo("   ") { result in
            switch result {
            case .failure(BootDriveError.invalidURL):
                expectation.fulfill()
            default:
                break
            }
        }
        wait(for: [expectation], timeout: 2.0)
    }
}
