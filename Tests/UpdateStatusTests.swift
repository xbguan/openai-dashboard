import Foundation

@main
enum UpdateStatusTests {
    static func main() {
        precondition(UpdateStatus.idle.actionTitle == "检查更新")
        precondition(UpdateStatus.checking.actionTitle == "检查中…")
        precondition(UpdateStatus.current.actionTitle == "检查更新")
        precondition(UpdateStatus.available("1.18.0").actionTitle == "更新至 v1.18.0")
        precondition(UpdateStatus.failed.actionTitle == "检查更新")
        print("PASS UpdateStatusTests")
    }
}
