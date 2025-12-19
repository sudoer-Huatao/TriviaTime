import SwiftUI


struct SettingsView: View {
    @Binding var interval: Double

    let availableIntervals: [Double] = [5, 10, 15, 30, 60] // in minutes

    // State for animations/feedback
    @State private var previousInterval: Double?
    @State private var showConfirmation: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text("Notification Settings")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.top, 10)
                .shadow(radius: 5)
            
            // Interval section
            Form {
                Section(header: Text("Choose Interval")
                    .font(.headline)
                    .foregroundColor(.secondary)
                ) {
                    Picker("Interval", selection: $interval) {
                        ForEach(availableIntervals, id: \.self) { interval in
                            Text("\(Int(interval)) minutes")
                                .tag(interval)
                        }
                    }
                    .pickerStyle(.segmented) // Cleaner, modern style
                    .onChange(of: interval) { oldValue, newValue in
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                            previousInterval = oldValue
                            showConfirmation = true
                        }
                        // Save the new interval to UserDefaults
                        UserDefaults.standard.set(newValue, forKey: "NotificationInterval")
                        
                        // Hide confirmation after delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                            withAnimation {
                                showConfirmation = false
                            }
                        }
                    }
                }
            }
            .frame(height: 120)
            .cornerRadius(12)
            .shadow(radius: 4)

            Spacer()
            
            // Animated confirmation label
            if showConfirmation {
                Label("Interval updated!", systemImage: "checkmark.circle.fill")
                    .font(.callout)
                    .foregroundColor(.green)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .shadow(radius: 6)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding()
        .frame(width: 340, height: 260)
    }
}
