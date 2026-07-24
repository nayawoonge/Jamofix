import Foundation
import CoreServices

/// FSEvents 기반 폴더 감시자. 등록된 폴더 트리에서 변경된 파일 경로를 콜백으로 전달.
/// CPU 부담이 거의 없는 커널 레벨 이벤트 스트림 사용.
public final class FolderWatcher {
    private var stream: FSEventStreamRef?
    private let paths: [String]
    private let queue = DispatchQueue(label: "jamofix.fsevents")
    private let onChange: ([String]) -> Void

    /// - Parameters:
    ///   - paths: 감시할 폴더 경로들
    ///   - onChange: 변경된 파일/폴더 경로 목록 (백그라운드 큐에서 호출됨)
    public init(paths: [String], onChange: @escaping ([String]) -> Void) {
        self.paths = paths
        self.onChange = onChange
    }

    public func start() {
        guard stream == nil, !paths.isEmpty else { return }

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let callback: FSEventStreamCallback = { _, info, numEvents, eventPaths, _, _ in
            guard let info else { return }
            let watcher = Unmanaged<FolderWatcher>.fromOpaque(info).takeUnretainedValue()
            let cfPaths = Unmanaged<NSArray>.fromOpaque(eventPaths).takeUnretainedValue()
            let changed = (cfPaths as? [String] ?? []).prefix(numEvents)
            watcher.onChange(Array(changed))
        }

        let flags = FSEventStreamCreateFlags(
            kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents
        )

        guard let created = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            paths as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5,  // latency: 0.5초 내 이벤트를 묶어서 전달
            flags
        ) else { return }

        stream = created
        FSEventStreamSetDispatchQueue(created, queue)
        FSEventStreamStart(created)
    }

    public func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    deinit { stop() }
}
