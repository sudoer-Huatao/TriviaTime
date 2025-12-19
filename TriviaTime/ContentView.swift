import SwiftUI

struct ContentView: View {
    var triviaQuestion: TriviaQuestion?

    var body: some View {
        VStack(spacing: 16) {
            if let trivia = triviaQuestion {
                Text(trivia.question)
                    .font(.headline)
                ForEach(trivia.allAnswers.shuffled(), id: \.self) { answer in
                    Text(answer)
                }
            } else {
                Text("Loading trivia...")
            }
        }
        .padding()
        .frame(width: 300)
    }
}
