import SwiftUI
import UserNotifications

@main
struct TriviaApp: App {
    @StateObject private var coordinator = AppCoordinator()  // Ensure this is the only instance of AppCoordinator
    let notificationDelegate = NotificationDelegate()
    

    init() {
        // Initial setup for coordinator (so the first notification can be sent immediately)
        UNUserNotificationCenter.current().delegate = notificationDelegate
    }

    var body: some Scene {
        WindowGroup {
            SettingsView(interval: $coordinator.notificationInterval)
                .onAppear {
                    // Ensure the setup is called when the view appears (after coordinator initialization)
                    coordinator.setup()
                }
        }
        .commands {
            CommandMenu("Settings") {
                Button("Open Settings") {
                    // Settings window will open automatically by the system
                }
                .keyboardShortcut(",", modifiers: .command) // Command+, to open settings
            }
        }
    }
}
