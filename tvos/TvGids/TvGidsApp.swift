import SwiftUI

@main
struct TvGidsApp: App {
    var body: some Scene {
        WindowGroup {
            GuideScreen()
                .preferredColorScheme(.dark)
        }
    }
}
