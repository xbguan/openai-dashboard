import Foundation

@main
enum UpdateCheckTimeoutTests {
    static func main() {
        var manual = UpdateCheckTimeout()
        let generation = manual.begin(manual: true)
        precondition(manual.shouldTimeout(generation: generation, status: .checking))
        precondition(!manual.shouldTimeout(generation: generation - 1, status: .checking))
        precondition(!manual.shouldTimeout(generation: generation, status: .current))
        precondition(manual.timeoutToast == "检查更新超时，请稍后重试。")

        manual.finish()
        precondition(manual.timeoutToast == nil)

        var background = UpdateCheckTimeout()
        let backgroundGeneration = background.begin(manual: false)
        precondition(background.shouldTimeout(generation: backgroundGeneration, status: .checking))
        precondition(background.timeoutToast == nil)

        print("PASS UpdateCheckTimeoutTests")
    }
}
