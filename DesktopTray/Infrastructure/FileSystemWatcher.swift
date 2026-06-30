import CoreServices
import Foundation

/// `~/Desktop` を FSEvents で監視し、変更をデバウンス付きで通知する
/// （アーキテクチャ v0.1 §3.5 / 技術スタック v0.1 §5）。
/// 500 件規模でも UI thread を塞がないよう、コールバックは呼び出し元でバックグラウンドキュー処理を想定。
final class FileSystemWatcher: @unchecked Sendable {
    private let urlToWatch: URL
    private var stream: FSEventStreamRef?
    private var pendingWorkItem: DispatchWorkItem?
    private let debounceInterval: TimeInterval
    private let queue: DispatchQueue

    /// 変更検出時に呼ばれる。デバウンス済み。
    var onChange: (() -> Void)?

    init(
        urlToWatch: URL? = nil,
        debounceInterval: TimeInterval = 0.4,
        queue: DispatchQueue = .global(qos: .utility)
    ) {
        self.urlToWatch = urlToWatch ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop")
        self.debounceInterval = debounceInterval
        self.queue = queue
    }

    /// 監視を開始する。
    func start() {
        guard stream == nil else { return }

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let pathsToWatch: [CFString] = [urlToWatch.path as CFString]
        let flags: FSEventStreamCreateFlags = FSEventStreamCreateFlags(
            kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagWatchRoot
        )

        let callback: FSEventStreamCallback = { _, clientCallBackInfo, _, _, _, _ in
            guard let info = clientCallBackInfo else { return }
            let watcher = Unmanaged<FileSystemWatcher>.fromOpaque(info)
                .takeUnretainedValue()
            watcher.scheduleDebouncedNotify()
        }

        guard let streamRef = FSEventStreamCreate(
            nil,
            callback,
            &context,
            pathsToWatch as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5,
            flags
        ) else {
            return
        }

        FSEventStreamSetDispatchQueue(streamRef, queue)
        FSEventStreamStart(streamRef)
        self.stream = streamRef
    }

    /// 監視を停止する。
    func stop() {
        guard let streamRef = stream else { return }
        FSEventStreamStop(streamRef)
        FSEventStreamInvalidate(streamRef)
        FSEventStreamRelease(streamRef)
        self.stream = nil
        pendingWorkItem?.cancel()
        pendingWorkItem = nil
    }

    private func scheduleDebouncedNotify() {
        pendingWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.onChange?()
        }
        pendingWorkItem = work
        queue.asyncAfter(deadline: .now() + debounceInterval, execute: work)
    }
}
