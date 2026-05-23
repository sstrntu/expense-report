import SwiftUI

/// Coach-marks-style guided tour that points at the bottom tab bar and
/// explains what each tab does. Triggered:
///   - automatically once, right after a fresh signup finishes onboarding
///     (gated by `@AppStorage("tour.completed")` in RootShell)
///   - manually from Profile → "Replay app tour"
///
/// The overlay dims the underlying app and intercepts touches so the user
/// can't accidentally tap a tab mid-tour. Each "tab" step also drops a
/// pulsing highlight ring at the computed tab center so it's obvious which
/// area the tooltip is talking about.
struct FeatureTour: View {
    let role: AppRole
    var onFinish: () -> Void

    @State private var stepIndex: Int = 0

    // MARK: – Step model

    /// A tour step is either a centered welcome/finish card or a
    /// tab-targeted tooltip with a highlight ring + downward chevron.
    private enum Step {
        case intro
        case tab(target: TabID, title: String, body: String)
        case done

        var isTabbed: Bool { if case .tab = self { return true }; return false }
    }

    private var steps: [Step] {
        var list: [Step] = [.intro]
        list.append(.tab(target: .home,
                         title: tr("tour.home.title"),
                         body: tr("tour.home.body")))
        list.append(.tab(target: .add,
                         title: tr("tour.add.title"),
                         body: tr("tour.add.body")))
        // Branch by role: employees see Activity in slot 3, managers/finance/admin
        // see Review instead. We mirror BottomTabBar's tab ordering exactly so
        // the highlight ring lands on the right spot.
        if role == .employee {
            list.append(.tab(target: .activity,
                             title: tr("tour.activity.title"),
                             body: tr("tour.activity.body")))
        } else {
            list.append(.tab(target: .review,
                             title: tr("tour.review.title"),
                             body: tr("tour.review.body")))
        }
        list.append(.tab(target: .profile,
                         title: tr("tour.profile.title"),
                         body: tr("tour.profile.body")))
        list.append(.done)
        return list
    }

    private var current: Step { steps[stepIndex] }
    private var lastIndex: Int { steps.count - 1 }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Dim everything underneath
                Color.black.opacity(0.55)
                    .ignoresSafeArea()
                    .allowsHitTesting(true)

                // Pulsing highlight ring at the targeted tab (for tab steps only)
                if case .tab(let target, _, _) = current,
                   let tabCenter = tabCenterPoint(for: target, in: geo.size) {
                    HighlightRing()
                        .position(tabCenter)
                }

                // Tooltip card
                VStack {
                    Spacer()
                    tooltipCard
                        .padding(.horizontal, 22)
                        // For tab-step, sit just above the tab bar. Center for intro/done.
                        .padding(.bottom, current.isTabbed ? 124 : geo.size.height / 2 - 110)
                }
            }
        }
        .transition(.opacity)
    }

    // MARK: – Tooltip card

    private var tooltipCard: some View {
        let (title, body): (String, String) = {
            switch current {
            case .intro:
                return (tr("tour.intro.title"), tr("tour.intro.body"))
            case .tab(_, let t, let b):
                return (t, b)
            case .done:
                return (tr("tour.done.title"), tr("tour.done.body"))
            }
        }()

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(tr("tour.step_label", stepIndex + 1, steps.count))
                    .font(.system(size: 10, weight: .bold)).tracking(0.8)
                    .foregroundStyle(.tertiary)
                Spacer()
                Button(tr("tour.skip")) { finish() }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Tokens.slate500)
                    .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.system(size: 18, weight: .bold))
                Text(body)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Progress dots so the user can see where they are.
            HStack(spacing: 5) {
                ForEach(0..<steps.count, id: \.self) { idx in
                    Capsule()
                        .fill(idx == stepIndex ? Tokens.slate500 : Color.primary.opacity(0.15))
                        .frame(width: idx == stepIndex ? 16 : 6, height: 4)
                        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: stepIndex)
                }
                Spacer()
            }

            HStack(spacing: 10) {
                if stepIndex > 0 {
                    Button { back() } label: {
                        Text(tr("tour.back"))
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(Color.primary)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.4), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                }

                Button { next() } label: {
                    Text(stepIndex == lastIndex ? tr("tour.finish") : tr("tour.next"))
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Tokens.slate500, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.white.opacity(0.3), lineWidth: 0.5))
        .shadow(color: Color.black.opacity(0.35), radius: 28, y: 18)
    }

    // MARK: – Navigation

    private func next() {
        if stepIndex == lastIndex {
            finish()
        } else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                stepIndex += 1
            }
        }
    }

    private func back() {
        guard stepIndex > 0 else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            stepIndex -= 1
        }
    }

    private func finish() {
        withAnimation(.easeOut(duration: 0.2)) {
            onFinish()
        }
    }

    // MARK: – Geometry: where does each tab sit on screen?

    /// Mirrors BottomTabBar's layout so the highlight ring lines up. The bar
    /// has 16pt outer horizontal padding and 8pt inner horizontal padding, then
    /// five equal-width tabs filling the rest. The bar's bottom edge sits at
    /// safeArea.bottom + 28 (the .padding(.bottom, 28) in RootShell).
    private func tabCenterPoint(for tab: TabID, in size: CGSize) -> CGPoint? {
        let tabsForRole: [TabID] = (role == .employee)
            ? [.home, .dashboard, .add, .activity, .profile]
            : [.home, .dashboard, .add, .review, .profile]
        guard let index = tabsForRole.firstIndex(of: tab) else { return nil }

        // Horizontal: inner = screenWidth - 2*16 (outer) - 2*8 (inner) = w - 48
        let outerPadding: CGFloat = 16
        let innerPadding: CGFloat = 8
        let innerWidth = size.width - 2 * (outerPadding + innerPadding)
        let tabWidth = innerWidth / CGFloat(tabsForRole.count)
        let x = outerPadding + innerPadding + (CGFloat(index) + 0.5) * tabWidth

        // Vertical: the tab bar's frame.height = 64; it sits .padding(.bottom, 28)
        // from the safe-area bottom. We don't have the safe-area inset directly
        // here so we approximate from the GeometryReader bounds. The numbers
        // are close enough that the highlight covers the tab even with a 10pt
        // discrepancy across device sizes.
        let barCenterFromBottom: CGFloat = 28 + 32
        let y = size.height - barCenterFromBottom

        return CGPoint(x: x, y: y)
    }
}

/// Pulsing ring used to call out the targeted tab. Two concentric circles —
/// a solid white ring and an outer "halo" that scales up and fades. Looks
/// like the standard system "look here" callout without bringing in any
/// extra dependencies.
private struct HighlightRing: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.9), lineWidth: 2)
                .frame(width: 52, height: 52)
            Circle()
                .stroke(Color.white.opacity(0.5), lineWidth: 1)
                .frame(width: 78, height: 78)
                .scaleEffect(animate ? 1.15 : 0.95)
                .opacity(animate ? 0 : 0.6)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) {
                animate = true
            }
        }
    }
}
