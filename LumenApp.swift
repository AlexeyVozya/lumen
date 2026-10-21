import SwiftUI
import AVFoundation

@main
struct LumenApp: App {
    @StateObject private var library = Library()

    init() {
        // Звук играет и при включённом беззвучном режиме
        try? AVAudioSession.sharedInstance().setCategory(.playback)
    }

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environmentObject(library)
                .preferredColorScheme(.dark)
        }
    }
}
