import SwiftUI

struct OnboardingView: View {
    @AppStorage(OnboardingKey.completed) private var completed = false
    @State private var pageIndex = 0

    private let pages: [Page] = [
        .init(
            icon: "shippingbox",
            title: "Welcome to pakt",
            body: "Move without the mess. Inventory every item in your home, triage what comes with you, and pack with confidence."
        ),
        .init(
            icon: "house",
            title: "Inventory by room",
            body: "Photograph and catalog every item where it lives today. Add closets, categories, and notes as you go."
        ),
        .init(
            icon: "shuffle",
            title: "Triage, one swipe at a time",
            body: "Decide the fate of each item: move with you, send to storage, donate, or toss. Not sure? Answer four quick questions and we'll suggest a call."
        ),
        .init(
            icon: "qrcode",
            title: "Pack into QR-coded boxes",
            body: "Create boxes, drop items in, and print labels. At the destination, scan a label to know exactly what's inside before you open it."
        ),
        .init(
            icon: "icloud.and.arrow.up",
            title: "Everything stays with you",
            body: "Your data lives on your iPhone and syncs privately across your devices with iCloud. No accounts to share, nothing sent anywhere else."
        ),
    ]

    var body: some View {
        ZStack {
            Color.paktBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("Skip", action: finish)
                        .font(.pakt(.body))
                        .foregroundStyle(Color.paktMutedForeground)
                        .padding(.horizontal, PaktSpace.s4)
                        .padding(.top, PaktSpace.s2)
                        .accessibilityHint("Skip the intro")
                }
                .opacity(pageIndex == pages.count - 1 ? 0 : 1)

                TabView(selection: $pageIndex) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        PageView(page: page).tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .never))

                controls
                    .padding(.horizontal, PaktSpace.s4)
                    .padding(.bottom, PaktSpace.s6)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var controls: some View {
        VStack(spacing: PaktSpace.s2) {
            PaktButton(ctaLabel, size: .lg, action: advance)
                .accessibilityIdentifier("onboarding.cta")
            Text("You'll sign in with Apple on the next screen.")
                .font(.pakt(.small))
                .foregroundStyle(Color.paktMutedForeground)
                .opacity(pageIndex == pages.count - 1 ? 1 : 0)
        }
    }

    private var ctaLabel: String {
        pageIndex == pages.count - 1 ? "Get started" : "Continue"
    }

    private func advance() {
        if pageIndex == pages.count - 1 {
            finish()
        } else {
            withAnimation { pageIndex += 1 }
        }
    }

    private func finish() {
        withAnimation { completed = true }
    }

    private struct Page: Hashable {
        let icon: String
        let title: String
        let body: String
    }

    private struct PageView: View {
        let page: Page

        var body: some View {
            VStack(spacing: PaktSpace.s6) {
                Spacer(minLength: 40)

                ZStack {
                    Circle()
                        .fill(Color.paktPrimary.opacity(0.15))
                        .frame(width: 160, height: 160)
                    Image(systemName: page.icon)
                        .font(.system(size: 72, weight: .medium))
                        .foregroundStyle(Color.paktPrimary)
                        .accessibilityHidden(true)
                }

                VStack(spacing: PaktSpace.s2) {
                    Text(page.title)
                        .font(.pakt(.title))
                        .foregroundStyle(Color.paktForeground)
                        .multilineTextAlignment(.center)
                    Text(page.body)
                        .font(.pakt(.body))
                        .foregroundStyle(Color.paktMutedForeground)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, PaktSpace.s6)
                }

                Spacer()
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(page.title). \(page.body)")
        }
    }
}

enum OnboardingKey {
    /// Bump the suffix to re-show onboarding after a redesign.
    static let completed = "onboarding.completed.v1"
}
