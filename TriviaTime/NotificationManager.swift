import Foundation
import UserNotifications
import AppKit

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    public var isInTriviaResultState = false
    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
    
    // Request notification permission
    func requestPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }
    
    // Register a dynamic notification category with answer actions
    private func registerCategory(for trivia: TriviaQuestion) {
        let decodedCorrect = decodeHtmlEntities(trivia.correct_answer)
        let decodedAnswers = trivia.allAnswers.shuffled().map { decodeHtmlEntities($0) }
        
        // Create actions
        let actions = decodedAnswers.map { answer in
            UNNotificationAction(
                identifier: answer, // use answer text as identifier
                title: answer,
                options: [.foreground]
            )
        }
        
        let category = UNNotificationCategory(
            identifier: trivia.question,
            actions: actions,
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
    
    // Decode HTML entities
    func decodeHtmlEntities(_ text: String) -> String {
        guard let data = text.data(using: .utf8) else { return text }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        
        do {
            let decodedString = try NSAttributedString(data: data, options: options, documentAttributes: nil).string
            return decodedString
        } catch {
            print("Error decoding HTML: \(error)")
            return text
        }
    }
    
    // Send a multiple-choice trivia notification
    func sendTriviaNotification(trivia: TriviaQuestion) {
        if isInTriviaResultState {
            print("⚠️ Skipping notification because we're in trivia result state.")
            return
        }

        // Existing code to send the notification
        TriviaCache.shared.store(trivia)
        let content = UNMutableNotificationContent()
        content.title = "Your scheduled trivia question:"
        
        let decodedQuestion = decodeHtmlEntities(trivia.question)
        content.body = """
        ❓ \(decodedQuestion)
        
        Choose your answer:
        """
        
        content.sound = .default

        // Register a category for this trivia question
        registerCategory(for: trivia)
        content.categoryIdentifier = trivia.question

        // Use 1-second trigger for immediate delivery
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            } else {
                print("Notification scheduled for trivia: \(trivia.question)")
            }
        }
    }

    
    // Send result notification with highlighted answers
    private func sendResultNotification(isCorrect: Bool, userAnswer: String, correctAnswer: String, question: String) {
        let content = UNMutableNotificationContent()
        
        if isCorrect {
            content.title = "✅ Correct!"
            content.body = """
            You got it right!
            
            Your answer: \(userAnswer)
            """
            content.sound = UNNotificationSound.default
        } else {
            content.title = "❌ Incorrect"
            content.body = """
            Your answer: \(userAnswer)
            Correct answer: \(correctAnswer)
            """
            content.sound = UNNotificationSound(named: UNNotificationSoundName(""))
        }
        
        // Use 0.5-second trigger for immediate delivery
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling result notification: \(error.localizedDescription)")
            }
        }
    }
    
    // Handle user response to the notification
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        // Set the flag to true to prevent new notifications while processing the result
        isInTriviaResultState = true
        
        // Process user answer and send result notification as before
        let questionIdentifier = response.notification.request.content.categoryIdentifier
        let selectedAnswer = response.actionIdentifier
        
        print("User selected answer: \(selectedAnswer) for question: \(questionIdentifier)")
        
        guard response.actionIdentifier != UNNotificationDefaultActionIdentifier else {
            completionHandler()
            return
        }
        
        // Get the stored trivia question
        if let triviaQuestion = TriviaCache.shared.question(for: questionIdentifier) {
            let correctAnswer = decodeHtmlEntities(triviaQuestion.correct_answer)
            let userAnswer = selectedAnswer
            
            print("Correct answer: \(correctAnswer), User answer: \(userAnswer)")
            
            let isCorrect = userAnswer == correctAnswer
            
            // Send result notification instead of showing popup
            self.sendResultNotification(
                isCorrect: isCorrect,
                userAnswer: userAnswer,
                correctAnswer: correctAnswer,
                question: self.decodeHtmlEntities(triviaQuestion.question)
            )
        } else {
            print("Could not find trivia question for identifier: \(questionIdentifier)")
        }
        
        completionHandler()
        
        // Set the flag back to false after handling the answer
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { // Delay before resetting flag
            self.isInTriviaResultState = false
        }
    }

    
    // Show a quick alert for immediate feedback
    /*
    private func showQuickAlert(isCorrect: Bool, correctAnswer: String) {
        let alert = NSAlert()
        alert.alertStyle = isCorrect ? .informational : .warning
        alert.addButton(withTitle: "OK")
        
        if isCorrect {
            alert.messageText = "✅ Correct!"
            alert.informativeText = "Well done! You got it right."
        } else {
            alert.messageText = "❌ Incorrect"
            alert.informativeText = "The correct answer was: \(correctAnswer)"
        }
        
        // Show alert but don't wait for response (non-modal)
        alert.beginSheetModal(for: NSApplication.shared.windows.first ?? NSWindow()) { _ in }
    }
     */
    
    // Ensure notifications are shown even when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
}

class TriviaCache {
    static let shared = TriviaCache()
    private var questions = [String: TriviaQuestion]()
    
    func store(_ trivia: TriviaQuestion) {
        questions[trivia.question] = trivia
    }
    
    func question(for key: String) -> TriviaQuestion? {
        questions[key]
    }
    
    func clear() {
        questions.removeAll()
    }
}
