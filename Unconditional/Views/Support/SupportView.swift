import SwiftUI

/// Where to turn when an app isn't enough.
struct SupportView: View {
    var body: some View {
        List {
            Section {
                Text("If you're thinking about harming yourself or feel unsafe, please reach out to a person right now. You deserve support, and you don't have to earn it.")
            }

            Section("In the US, any time") {
                Link(destination: URL(string: "tel:988")!) {
                    Label("Call 988 Suicide & Crisis Lifeline", systemImage: "phone")
                }
                Link(destination: URL(string: "sms:988")!) {
                    Label("Text 988", systemImage: "message")
                }
                Link(destination: URL(string: "sms:741741&body=HOME")!) {
                    Label("Text HOME to 741741 (Crisis Text Line)", systemImage: "message")
                }
            }

            Section("Outside the US") {
                Link(destination: URL(string: "https://findahelpline.com")!) {
                    Label("Find a helpline in your country", systemImage: "globe")
                }
            }

            Section {
                Text("Unconditional is a place to practice, not a replacement for care. A therapist trained in CBT or ACT can go much deeper with loops like these, and needing help is not a failure.")
                    .foregroundStyle(.secondary)
                Link(destination: URL(string: "https://www.psychologytoday.com/us/therapists")!) {
                    Label("Find a therapist", systemImage: "person.2")
                }
            } header: {
                Text("Going further")
            }
        }
        .navigationTitle("Support")
        .themedBackground()
        .paperList()
    }
}
