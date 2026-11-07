import Foundation

@main
enum UpdateCheckFailureTests {
    static func main() {
        let timeout = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)
        let wrapped = NSError(domain: "SUSparkleErrorDomain", code: 1,
                              userInfo: [NSUnderlyingErrorKey: timeout])
        precondition(UpdateCheckFailure.message(for: wrapped) == "检查更新超时，请稍后重试。")

        let badResponse = NSError(domain: NSURLErrorDomain, code: NSURLErrorBadServerResponse)
        precondition(UpdateCheckFailure.message(for: badResponse) == "更新服务器响应异常，请稍后重试。")

        let other = NSError(domain: "SUSparkleErrorDomain", code: 2)
        precondition(UpdateCheckFailure.message(for: other) == "检查更新失败，请稍后重试。")
        print("PASS UpdateCheckFailureTests")
    }
}
