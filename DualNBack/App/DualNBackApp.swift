import SwiftUI

@main
struct DualNBackApp: App {
    @StateObject private var storageManager = StorageManager.shared
    
    var body: some Scene {
        WindowGroup {
            HomeView(storage: storageManager)
                .preferredColorScheme(.dark)
        }
    }
}
