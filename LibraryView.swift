import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @EnvironmentObject var lib: Library
    @State private var picking = false
    @State private var playing: VideoItem?
    private let cols = [GridItem(.adaptive(minimum: 170), spacing: 16)]

    var body: some View {
        NavigationStack {
            ScrollView {
                if lib.items.isEmpty {
                    ContentUnavailableView("Пока пусто", systemImage: "film",
                        description: Text("Нажмите «+» и выберите видео из приложения «Файлы»."))
                        .padding(.top, 120)
                }
                LazyVGrid(columns: cols, spacing: 18) {
                    ForEach(lib.items) { card($0) }
                }
                .padding()
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Lumen")
            .toolbar {
                Button { picking = true } label: { Image(systemName: "plus") }
                    .tint(Theme.accent)
            }
            .fileImporter(isPresented: $picking,
                          allowedContentTypes: [.movie, .mpeg4Movie, .quickTimeMovie],
                          allowsMultipleSelection: true) { result in
                if case .success(let urls) = result { lib.add(urls) }
            }
            .fullScreenCover(item: $playing, onDismiss: { lib.objectWillChange.send() }) {
                PlayerView(item: $0)
            }
        }
    }

    private func card(_ item: VideoItem) -> some View {
        let dur = lib.durations[item.id] ?? 0
        let progress = dur > 0 ? min(1, WatchStore.get(item) / dur) : 0
        return Button { playing = item } label: {
            VStack(alignment: .leading, spacing: 8) {
                Rectangle().fill(Theme.surface)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .overlay {
                        if let img = lib.thumbs[item.id] {
                            Image(uiImage: img).resizable().scaledToFill()
                        }
                    }
                    .overlay(alignment: .bottomLeading) {
                        GeometryReader { g in
                            Rectangle().fill(Theme.accent)
                                .frame(width: g.size.width * progress, height: 4)
                                .frame(maxHeight: .infinity, alignment: .bottom)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                Text(item.title).font(.subheadline.weight(.semibold)).lineLimit(1).foregroundStyle(.white)
                if dur > 0 { Text(fmt(dur)).font(.caption).foregroundStyle(.secondary) }
            }
        }
        .buttonStyle(.plain)
        .contextMenu { Button("Удалить", role: .destructive) { lib.delete(item) } }
    }
}
