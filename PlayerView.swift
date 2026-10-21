import SwiftUI
import AVKit

final class PlayerModel: ObservableObject {
    let player: AVPlayer
    let item: VideoItem
    @Published var time = 0.0
    @Published var duration = 0.0
    @Published var playing = false
    @Published var rate: Float = 1
    private var observer: Any?

    init(item: VideoItem) {
        self.item = item
        player = AVPlayer(url: item.url)
        observer = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self] t in
            guard let self else { return }
            self.time = t.seconds
            if let d = self.player.currentItem?.duration.seconds, d.isFinite { self.duration = d }
            if Int(t.seconds) % 3 == 0 { WatchStore.set(t.seconds, for: self.item) }
        }
        let saved = WatchStore.get(item)
        if saved > 5 { player.seek(to: CMTime(seconds: saved, preferredTimescale: 600)) }
        play()
    }

    deinit { if let observer { player.removeTimeObserver(observer) } }

    func play() { player.playImmediately(atRate: rate); playing = true }
    func pause() { player.pause(); playing = false }
    func toggle() { playing ? pause() : play() }
    func seek(to s: Double) { player.seek(to: CMTime(seconds: s, preferredTimescale: 600)) }
    func skip(_ d: Double) { seek(to: min(max(0, time + d), max(duration, 1))) }
    func setRate(_ r: Float) { rate = r; if playing { player.rate = r } }
    func save() { WatchStore.set(time, for: item) }
}

final class PlayerUIView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer
    let gravity: AVLayerVideoGravity
    func makeUIView(context: Context) -> PlayerUIView {
        let v = PlayerUIView(); v.playerLayer.player = player; return v
    }
    func updateUIView(_ v: PlayerUIView, context: Context) { v.playerLayer.videoGravity = gravity }
}

struct PlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var m: PlayerModel
    @State private var showUI = true
    @State private var zoom = 0
    @State private var hideTask: Task<Void, Never>?

    private let zooms: [(String, AVLayerVideoGravity)] = [
        ("Вписать", .resizeAspect), ("Заполнить", .resizeAspectFill), ("Растянуть", .resize)]

    init(item: VideoItem) { _m = StateObject(wrappedValue: PlayerModel(item: item)) }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            PlayerLayerView(player: m.player, gravity: zooms[zoom].1).ignoresSafeArea()

            // Двойной тап слева/справа — перемотка на 10 секунд, одиночный — показать/скрыть панель
            HStack(spacing: 0) {
                tapZone(-10)
                tapZone(10)
            }
            .ignoresSafeArea()

            if showUI { controls.transition(.opacity) }
        }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onAppear { scheduleHide() }
        .onDisappear { m.pause(); m.save() }
    }

    private func tapZone(_ seconds: Double) -> some View {
        Color.clear.contentShape(Rectangle())
            .onTapGesture(count: 2) { m.skip(seconds) }
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) { showUI.toggle() }
                scheduleHide()
            }
    }

    private func scheduleHide() {
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(3))
            if !Task.isCancelled && m.playing { withAnimation { showUI = false } }
        }
    }

    private var controls: some View {
        VStack {
            HStack(spacing: 12) {
                Button { dismiss() } label: { Image(systemName: "chevron.down") }
                Text(m.item.title).font(.headline).lineLimit(1)
                Spacer()
                Menu {
                    ForEach(0..<zooms.count, id: \.self) { i in
                        Button(zooms[i].0) { zoom = i }
                    }
                } label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }
                Menu {
                    ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { r in
                        Button("×\(r.formatted())") { m.setRate(Float(r)) }
                    }
                } label: { Image(systemName: "speedometer") }
            }
            .padding()
            .background(LinearGradient(colors: [.black.opacity(0.7), .clear], startPoint: .top, endPoint: .bottom))

            Spacer()

            VStack(spacing: 10) {
                HStack(spacing: 36) {
                    Button { m.skip(-10) } label: { Image(systemName: "gobackward.10").font(.title) }
                    Button { m.toggle(); scheduleHide() } label: {
                        Image(systemName: m.playing ? "pause.fill" : "play.fill").font(.system(size: 38))
                    }
                    Button { m.skip(10) } label: { Image(systemName: "goforward.10").font(.title) }
                }
                HStack {
                    Text(fmt(m.time)).monospacedDigit().font(.caption)
                    Slider(value: Binding(get: { m.time }, set: { m.seek(to: $0) }),
                           in: 0...max(m.duration, 1))
                        .tint(Theme.accent)
                    Text(fmt(m.duration)).monospacedDigit().font(.caption)
                }
            }
            .padding()
            .background(LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .top, endPoint: .bottom))
        }
        .foregroundStyle(.white)
    }
}
