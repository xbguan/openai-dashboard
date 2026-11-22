import Foundation
import Combine
import Sparkle

@MainActor
final class UpdateManager: NSObject, ObservableObject, SPUUpdaterDelegate {
    @Published private(set) var status: UpdateStatus = .idle
    @Published private(set) var errorMessage = "检查更新失败，请稍后重试。"
    @Published private(set) var lastCheckWasManual = false
    @Published private(set) var noticeRevision = 0

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    private var updaterController: SPUStandardUpdaterController?
    private var checkTimer: Timer?
    private var watchdog: Timer?
    private var timeout = UpdateCheckTimeout()

    func start() {
        guard updaterController == nil else { return }
        let controller = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
        updaterController = controller
        controller.startUpdater()
        checkForUpdates()

        let timer = Timer(timeInterval: 8 * 60 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkForUpdates() }
        }
        RunLoop.main.add(timer, forMode: .common)
        checkTimer = timer
    }

    func performPrimaryAction() {
        switch status {
        case .available:
            updaterController?.updater.checkForUpdates()
        case .checking:
            break
        case .idle, .current, .failed:
            checkForUpdates(manual: true)
        }
    }

    private func checkForUpdates(manual: Bool = false) {
        guard let updater = updaterController?.updater else { return }
        guard !updater.sessionInProgress else {
            if manual {
                lastCheckWasManual = true
                errorMessage = "上一次检查仍在结束，请稍后重试。"
                status = .failed
                noticeRevision &+= 1
            }
            return
        }
        lastCheckWasManual = manual
        let generation = timeout.begin(manual: manual)
        status = .checking
        startWatchdog(generation: generation)
        updater.checkForUpdateInformation()
    }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        stopWatchdog()
        status = .available(item.displayVersionString)
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: any Error) {
        stopWatchdog()
        status = .current
    }

    func updater(_ updater: SPUUpdater,
                 didFinishUpdateCycleFor updateCheck: SPUUpdateCheck,
                 error: (any Error)?) {
        stopWatchdog()
        timeout.finish()
        if case .checking = status {
            if let error {
                errorMessage = UpdateCheckFailure.message(for: error)
                status = .failed
                noticeRevision &+= 1
            } else {
                status = .current
            }
        }
    }

    private func startWatchdog(generation: UInt) {
        stopWatchdog()
        let timer = Timer(timeInterval: UpdateCheckTimeout.interval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self,
                      self.timeout.shouldTimeout(generation: generation, status: self.status) else { return }
                self.errorMessage = UpdateCheckTimeout.message
                self.status = .failed
                self.noticeRevision &+= 1
                self.watchdog = nil
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        watchdog = timer
    }

    private func stopWatchdog() {
        watchdog?.invalidate()
        watchdog = nil
    }

    deinit {
        watchdog?.invalidate()
        checkTimer?.invalidate()
    }
}
