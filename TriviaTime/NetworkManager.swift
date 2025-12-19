import Foundation
import Combine

class NetworkManager: ObservableObject {
    @Published var triviaQuestion: TriviaQuestion?

    private var cancellables = Set<AnyCancellable>()

    func fetchTrivia() {
        guard let url = URL(string: "https://opentdb.com/api.php?amount=1&type=multiple") else {
            print("⚠️ Invalid URL")
            return
        }

        // Start the network request
        URLSession.shared.dataTaskPublisher(for: url)
            .map { $0.data } // Extract data from the response
            .decode(type: TriviaResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main) // Ensure UI-related work happens on the main thread
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    print("⚠️ Error fetching trivia: \(error.localizedDescription)")
                case .finished:
                    break
                }
            }, receiveValue: { [weak self] response in
                guard let self = self else { return }
                
                // Ensure we have valid trivia data
                if let trivia = response.results.first {
                    print("🎉 Trivia fetched successfully: \(trivia.question)")
                    self.triviaQuestion = trivia
                } else {
                    print("⚠️ No trivia data found in response.")
                }
            })
            .store(in: &cancellables)
    }
}
