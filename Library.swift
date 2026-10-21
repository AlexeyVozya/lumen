import SwiftUI
import AVFoundation

enum Theme {
    static let bg = Color(red: 0.08, green: 0.06, blue: 0.12)
    static let surface = Color(red: 0.14, green: 0.10, blue: 0.21)
    static let accent = Color(red: 1.0, green: 0.71, blue: 0.33)
}

func fmt(_ s: Double) -> String {
    let t = Int(max(0, s)), h = t / 3600, m = (t % 3600) / 60, sec = t % 60
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%d:%02d", m, sec)
}

struct VideoItem: Identifiable, Hashable {
    let url: URL
    var id: String { url.lastPathComponent }
    var title: String { url.deletingPathExtension().lastPathComponent }
}

enum WatchStore {
    static func get(_ i: VideoItem) -> Double { UserDefaults.standard.double(forKey: "pos:" + i.id) }
    static func set(_ t: Double, for i: VideoItem) { UserDefaults.standard.set(t, forKey: "pos:" + i.id) }
}

@MainActor
final class Library: ObservableObject {
    @Published var items: [VideoItem] = []
    @Published var thumbs: [String: UIImage] = [:]
    @Published var durations: [String: Double] = [:]

    private let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    private let exts: Set<String> = ["mp4", "m4v", "mov"]

    init() { refresh() }

    func refresh() {
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        items = files.filter { exts.contains($0.pathExtension.lowercased()) }
            .map(VideoItem.init(url:))
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        items.forEach(loadMeta)
    }

    func add(_ urls: [URL]) {
        for u in urls {
            let access = u.startAccessingSecurityScopedResource()
            defer { if access { u.stopAccessingSecurityScopedResource() } }
            let dest = dir.appendingPathComponent(u.lastPathComponent)
            if !FileManager.default.fileExists(atPath: dest.path) {
                try? FileManager.default.copyItem(at: u, to: dest)
            }
        }
        refresh()
    }

    func delete(_ item: VideoItem) {
        try? FileManager.default.removeItem(at: item.url)
        WatchStore.set(0, for: item)
        thumbs[item.id] = nil
        refresh()
    }

    private func loadMeta(_ item: VideoItem) {
        guard thumbs[item.id] == nil else { return }
        Task.detached {
            let asset = AVURLAsset(url: item.url)
            let dur = (try? await asset.load(.duration).seconds) ?? 0
            let gen = AVAssetImageGenerator(asset: asset)
            gen.appliesPreferredTrackTransform = true
            gen.maximumSize = CGSize(width: 480, height: 270)
            let at = CMTime(seconds: min(10, dur * 0.1), preferredTimescale: 600)
            let cg = try? await gen.image(at: at).image
            await MainActor.run {
                if dur > 0 { self.durations[item.id] = dur }
                if let cg { self.thumbs[item.id] = UIImage(cgImage: cg) }
            }
        }
    }
}
