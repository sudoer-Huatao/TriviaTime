import Foundation
import Combine
import AppKit

class AppCoordinator: ObservableObject {
    private var cancellables = Set<AnyCancellable>()
    private var timer: AnyCancellable?
    public let defaultInterval: Double = 30 // Default interval in minutes
    
    @Published var notificationInterval: Double {
        didSet {
            restartNotifications()
        }
    }
    
    let notificationManager = NotificationManager()
    let networkManager = NetworkManager()
    
    private var isFetchingTrivia = false
    
    // Cache for sent questions to avoid duplicates
    private var sentQuestions = [String]() // keep as array to manage order
    private let maxCacheSize = 20
    
    init() {
        let savedInterval = UserDefaults.standard.double(forKey: "NotificationInterval")
        self.notificationInterval = savedInterval > 0 ? savedInterval : defaultInterval
    }
    
    func setup() {
        print("🔧 Coordinator setup started")
        notificationManager.requestPermission { granted in
            if granted {
                // Only send notifications if allowed
                self.fetchTriviaAndNotify()
                self.startNotifications()
            } else {
                print("⚠️ Notifications not granted")
            }
        }
    }

    
    private func restartNotifications() {
        timer?.cancel()
        isFetchingTrivia = false
        sentQuestions.removeAll() // optional: clear cache when interval changes
        startNotifications()
    }
    
    private func startNotifications() {
        timer = Timer.publish(every: notificationInterval * 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.fetchTriviaAndNotify()
            }
    }
    
    private func fetchTriviaAndNotify() {
        if isFetchingTrivia { return }
        
        print("🌐 Fetching trivia...")
        
        isFetchingTrivia = true
        
        networkManager.fetchTrivia()
        
        networkManager.$triviaQuestion
            .dropFirst()
            .sink { [weak self] trivia in
                guard let self = self else { return }
                
                guard let trivia = trivia else {
                    print("⚠️ No trivia fetched")
                    self.isFetchingTrivia = false
                    return
                }
                
                // Check if question was sent before
                if self.sentQuestions.contains(trivia.question) {
                    self.isFetchingTrivia = false
                    return
                }
                
                print("📨 Sending notification for: \(trivia.question)")
                
                DispatchQueue.main.async {
                    self.notificationManager.sendTriviaNotification(trivia: trivia)
                }
                
                // Add question to cache
                self.sentQuestions.append(trivia.question)
                // Maintain cache size
                if self.sentQuestions.count > self.maxCacheSize {
                    self.sentQuestions.removeFirst()
                }
                
                self.isFetchingTrivia = false
            }
            .store(in: &cancellables)
    }
    
    deinit {
        timer?.cancel()
    }
}
