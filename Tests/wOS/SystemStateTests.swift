import XCTest
@testable import wOS

final class SystemStateTests: XCTestCase {

    func testUserNameCombinesLastAndFirstName() {
        let state = SystemState()
        state.lastName = "Nguyen"
        state.firstName = "An"
        XCTAssertEqual(state.userName, "Nguyen An")

        state.lastName = " "
        state.firstName = "An"
        XCTAssertEqual(state.userName, "An")
    }

    func testFactoryResetClearsProfileAndReturnsToSetup() {
        let state = SystemState()
        state.firstName = "An"
        state.lastName = "Nguyen"
        state.age = "25"
        state.password = "abcd1234"
        state.hasSetup = true
        state.wallpaper = "blue"
        state.bootDriveMode = .adminBuilt

        state.factoryReset()

        XCTAssertEqual(state.firstName, "")
        XCTAssertEqual(state.lastName, "")
        XCTAssertEqual(state.age, "")
        XCTAssertEqual(state.password, "")
        XCTAssertFalse(state.hasSetup)
        XCTAssertEqual(state.wallpaper, "default")
        XCTAssertEqual(state.bootDriveMode, .none)
        XCTAssertEqual(state.screen, .setup)
        XCTAssertTrue(state.windows.isEmpty)
    }

    func testOpenAppCreatesWindowAndBringsToFront() {
        let state = SystemState()
        state.openApp("calculator")
        XCTAssertEqual(state.windows.count, 1)
        let id = state.windows[0].id
        XCTAssertEqual(state.frontWindowId, id)

        state.openApp("settings")
        XCTAssertEqual(state.windows.count, 2)
        state.bringToFront(id)
        XCTAssertEqual(state.frontWindowId, id)

        state.closeWindow(id)
        XCTAssertEqual(state.windows.count, 1)
        XCTAssertEqual(state.frontWindowId, state.windows.first?.id)
    }

    func testOpenAppAlreadyOpenFocusesInsteadOfDuplicating() {
        let state = SystemState()
        state.openApp("terminal")
        let id = state.windows[0].id
        state.openApp("terminal")
        XCTAssertEqual(state.windows.count, 1)
        XCTAssertEqual(state.frontWindowId, id)
        XCTAssertFalse(state.windows[0].minimized)
    }

    func testMinimizeAndMaximizeToggle() {
        let state = SystemState()
        state.openApp("browser")
        let id = state.windows[0].id
        state.minimizeWindow(id)
        XCTAssertTrue(state.windows[0].minimized)
        state.maximizeWindow(id)
        XCTAssertTrue(state.windows[0].maximized)
        state.maximizeWindow(id)
        XCTAssertFalse(state.windows[0].maximized)
    }

    func testInstallAndUninstallApp() {
        let state = SystemState()
        let app = RealApp(id: "test-app", name: "Test App", category: "Test", colorHex: "FF0000", iconSymbol: "app.fill", url: "https://example.com", scheme: nil, desc: "desc")
        XCTAssertFalse(state.isInstalled("test-app"))
        state.installApp(app)
        XCTAssertTrue(state.isInstalled("test-app"))
        state.uninstallApp(app)
        XCTAssertFalse(state.isInstalled("test-app"))
    }
}
