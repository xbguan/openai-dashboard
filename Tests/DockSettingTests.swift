import Foundation

@main
enum DockSettingTests {
    static func main() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: base) }
        let store = ConfigStore(base: base)

        let oldConfig = try JSONDecoder().decode(AppConfig.self, from: Data("{\"refreshMinutes\":15}".utf8))
        precondition(oldConfig.showInDock, "Existing installs should keep showing in the Dock")

        var config = oldConfig
        config.showInDock = false
        precondition(store.save(config))
        precondition(!store.load().showInDock, "Disabled Dock setting should survive restart")

        config.showInDock = true
        precondition(store.save(config))
        precondition(store.load().showInDock, "Re-enabled Dock setting should survive restart")
        print("PASS DockSettingTests")
    }
}
