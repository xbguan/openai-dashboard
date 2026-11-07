import Foundation

enum UpdateCheckFailure {
    static func message(for error: Error) -> String {
        var current = error as NSError
        for _ in 0..<5 {
            if current.domain == NSURLErrorDomain {
                switch current.code {
                case NSURLErrorTimedOut:
                    return "检查更新超时，请稍后重试。"
                case NSURLErrorBadServerResponse:
                    return "更新服务器响应异常，请稍后重试。"
                case NSURLErrorNotConnectedToInternet:
                    return "当前网络不可用，请连接网络后重试。"
                default:
                    return "更新服务器连接失败，请稍后重试。"
                }
            }
            guard let underlying = current.userInfo[NSUnderlyingErrorKey] as? NSError else { break }
            current = underlying
        }
        return "检查更新失败，请稍后重试。"
    }
}
