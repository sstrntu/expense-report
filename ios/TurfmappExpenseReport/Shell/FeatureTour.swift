import SwiftUI

// MARK: – Tour targets (the UI elements the tour can spotlight)

/// Strongly typed catalog of UI elements the tour can highlight. Each app
/// screen that participates in the tour tags one or more elements with
/// `.tourTarget(.someCase)`; the modifier writes the element's global frame
/// into a preference, and the overlay reads it to draw a cutout + tooltip.
enum TourTarget: String, Hashable {
    case homeHero
    case homeRecent
    case submitScan
    case submitForm
    case activitySearch
    case activityFilters
    case reviewQueues
    case profileWorkspace
    case profileTourReplay
}

/// Per-target → CGRect mapping built by the .tourTarget modifier. We merge
/// with `latest wins` so a target that re-emits (e.g. on scroll) updates
/// its frame rather than clobbering itself with a stale rect.
extension View {
    /// Tags this view as a tour target. Its global frame is reported into
    /// `TourTargetPreference` so the overlay can spotlight it.
    ///
    /// We use `.onGeometryChange` instead of the older
    /// `.background(GeometryReader)` pattern: that pattern can over-report a
    /// view's size when it's inside a `ViewBuilder`-style `if/else if/else`
    /// computed property (the captured background ends up sized for the
    /// containing layout group, not the conditional view that returned).
    func tourTarget(_ target: TourTarget) -> some View {
        onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .global)
        } action: { rect in
            // Re-publish through a preference so the parent can collect across
            // many target sites in a single onPreferenceChange.
            TourTargetCollector.shared.publish(target: target, rect: rect)
        }
    }
}

/// Bridge between the `.tourTarget` modifier and the coordinator. The
/// onGeometryChange action closure runs outside the SwiftUI view tree, so
/// we can't directly write a `PreferenceKey` from it. Instead we route
/// through a shared @Observable-style collector that the coordinator subscribes
/// to via NotificationCenter.
@MainActor
final class TourTargetCollector {
    static let shared = TourTargetCollector()
    private var rects: [TourTarget: CGRect] = [:]

    func publish(target: TourTarget, rect: CGRect) {
        // Skip zero-size emits and identical re-emits.
        guard rect.width > 4, rect.height > 4 else { return }
        if let existing = rects[target], existing == rect { return }
        rects[target] = rect
        NotificationCenter.default.post(
            name: .tourTargetFrameChanged,
            object: nil,
            userInfo: ["target": target, "rect": rect]
        )
    }

    func snapshot() -> [TourTarget: CGRect] { rects }
}

extension Notification.Name {
    static let tourTargetFrameChanged = Notification.Name("com.turfmapp.tourTargetFrameChanged")
}

// MARK: – Step model

struct TourStep: Identifiable {
    let id = UUID()
    /// Tab to switch to before showing this step. Nil means "stay on current".
    let tab: TabID?
    /// UI element to spotlight. Nil means a centered intro/outro card.
    let target: TourTarget?
    let title: String
    let body: String
}

// MARK: – Coordinator

@MainActor
final class TourCoordinator: ObservableObject {
    @Published var isActive: Bool = false
    @Published var currentStepIndex: Int = 0
    /// Frames captured from the live UI via the .tourTarget modifier.
    @Published var frames: [TourTarget: CGRect] = [:]
    /// Set when the tour wants to switch tabs; RootShell observes this and
    /// updates the bound selectedTab. We use a side-channel rather than
    /// passing a binding into the coordinator to keep it free of SwiftUI types.
    @Published var requestedTab: TabID? = nil

    private(set) var steps: [TourStep] = []

    var current: TourStep? {
        guard isActive, steps.indices.contains(currentStepIndex) else { return nil }
        return steps[currentStepIndex]
    }

    var isFirst: Bool { currentStepIndex == 0 }
    var isLast: Bool { currentStepIndex == steps.count - 1 }
    var stepNumber: Int { currentStepIndex + 1 }
    var totalSteps: Int { steps.count }

    func start(for role: AppRole) {
        steps = Self.buildSteps(for: role)
        currentStepIndex = 0
        if let tab = steps.first?.tab { requestedTab = tab }
        isActive = true
    }

    func next() {
        guard isActive else { return }
        if currentStepIndex >= steps.count - 1 {
            stop()
            return
        }
        currentStepIndex += 1
        if let tab = current?.tab { requestedTab = tab }
    }

    func back() {
        guard currentStepIndex > 0 else { return }
        currentStepIndex -= 1
        if let tab = current?.tab { requestedTab = tab }
    }

    func stop() {
        isActive = false
        requestedTab = nil
    }

    /// Per-role step list. Employees route through Activity; managers/finance/
    /// admin route through Review (the role-tabbed queues we built earlier).
    private static func buildSteps(for role: AppRole) -> [TourStep] {
        var list: [TourStep] = []
        list.append(.init(tab: nil, target: nil,
                          title: tr("tour.intro.title"),
                          body: tr("tour.intro.body")))

        list.append(.init(tab: .home, target: .homeHero,
                          title: tr("tour.home.hero.title"),
                          body: tr("tour.home.hero.body")))
        list.append(.init(tab: .home, target: .homeRecent,
                          title: tr("tour.home.recent.title"),
                          body: tr("tour.home.recent.body")))

        list.append(.init(tab: .add, target: .submitScan,
                          title: tr("tour.submit.scan.title"),
                          body: tr("tour.submit.scan.body")))
        list.append(.init(tab: .add, target: .submitForm,
                          title: tr("tour.submit.form.title"),
                          body: tr("tour.submit.form.body")))

        if role == .employee {
            list.append(.init(tab: .activity, target: .activitySearch,
                              title: tr("tour.activity.search.title"),
                              body: tr("tour.activity.search.body")))
            list.append(.init(tab: .activity, target: .activityFilters,
                              title: tr("tour.activity.filters.title"),
                              body: tr("tour.activity.filters.body")))
        } else {
            list.append(.init(tab: .review, target: .reviewQueues,
                              title: tr("tour.review.title"),
                              body: tr("tour.review.body")))
        }

        list.append(.init(tab: .profile, target: .profileWorkspace,
                          title: tr("tour.profile.workspace.title"),
                          body: tr("tour.profile.workspace.body")))
        list.append(.init(tab: .profile, target: .profileTourReplay,
                          title: tr("tour.profile.replay.title"),
                          body: tr("tour.profile.replay.body")))

        list.append(.init(tab: nil, target: nil,
                          title: tr("tour.done.title"),
                          body: tr("tour.done.body")))
        return list
    }
}

// MARK: – Overlay view

/// Full-screen overlay that dims the app, cuts a "spotlight" hole around the
/// currently-targeted UI element, and floats a tooltip card next to it. The
/// underlying UI is visible inside the spotlight so users can see exactly
/// what's being described.
struct FeatureTour: View {
    @ObservedObject var coordinator: TourCoordinator

    // 12pt of breathing room around the highlighted element.
    private let spotlightPadding: CGFloat = 12
    private let spotlightCorner: CGFloat = 16

    var body: some View {
        // The outer GeometryReader needs to span the full window so its
        // coordinate space matches the global frames we captured with
        // `.frame(in: .global)`. Without `.ignoresSafeArea()` the reader's
        // origin sits at the safe-area top, which means a target at window-y
        // 540 would get drawn at y 540 + safe-area-top — visibly mis-aligned.
        GeometryReader { geo in
            let step = coordinator.current
            let target = step?.target
            let rect: CGRect? = {
                guard let t = target,
                      let r = coordinator.frames[t],
                      r.width > 4, r.height > 4 else { return nil }
                return r
            }()

            ZStack {
                dimLayer(spotlightRect: rect, screenSize: geo.size)
                    .allowsHitTesting(true)

                if let rect {
                    RoundedRectangle(cornerRadius: spotlightCorner)
                        .stroke(Color.white.opacity(0.85), lineWidth: 2)
                        .frame(
                            width: rect.width + spotlightPadding * 2,
                            height: rect.height + spotlightPadding * 2
                        )
                        .position(x: rect.midX, y: rect.midY)
                        .shadow(color: Color.white.opacity(0.5), radius: 12)
                        .allowsHitTesting(false)
                }

                tooltipPosition(rect: rect, screenSize: geo.size)
            }
        }
        .ignoresSafeArea()
        .animation(.spring(response: 0.32, dampingFraction: 0.85),
                   value: coordinator.currentStepIndex)
    }

    // MARK: – Dim with cutout

    @ViewBuilder
    private func dimLayer(spotlightRect: CGRect?, screenSize: CGSize) -> some View {
        if let rect = spotlightRect {
            // SwiftUI cutout via the destination-out blend mode + compositing
            // group: draw the full dim, then knock out a rounded rect over the
            // target so the live UI underneath shows through.
            Color.black.opacity(0.62)
                .overlay(
                    RoundedRectangle(cornerRadius: spotlightCorner)
                        .frame(
                            width: rect.width + spotlightPadding * 2,
                            height: rect.height + spotlightPadding * 2
                        )
                        .position(x: rect.midX, y: rect.midY)
                        .blendMode(.destinationOut)
                )
                .compositingGroup()
        } else {
            Color.black.opacity(0.55)
        }
    }

    // MARK: – Tooltip placement

    @ViewBuilder
    private func tooltipPosition(rect: CGRect?, screenSize: CGSize) -> some View {
        if let rect {
            let aboveTarget = rect.midY > screenSize.height * 0.55
            VStack(spacing: 0) {
                if aboveTarget {
                    Spacer()
                    tooltipCard
                        .padding(.horizontal, 22)
                        .padding(.bottom, max(20, screenSize.height - rect.minY + spotlightPadding + 12))
                } else {
                    Spacer().frame(height: rect.maxY + spotlightPadding + 16)
                    tooltipCard
                        .padding(.horizontal, 22)
                    Spacer()
                }
            }
        } else {
            // Centered for intro/outro steps
            VStack {
                Spacer()
                tooltipCard
                    .padding(.horizontal, 22)
                Spacer()
            }
        }
    }

    // MARK: – Tooltip card

    private var tooltipCard: some View {
        let step = coordinator.current
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(tr("tour.step_label", coordinator.stepNumber, coordinator.totalSteps))
                    .font(.system(size: 10, weight: .bold)).tracking(0.8)
                    .foregroundStyle(.tertiary)
                Spacer()
                Button(tr("tour.skip")) { coordinator.stop() }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Tokens.slate500)
                    .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(step?.title ?? "")
                    .font(.system(size: 18, weight: .bold))
                Text(step?.body ?? "")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 5) {
                ForEach(0..<coordinator.totalSteps, id: \.self) { idx in
                    Capsule()
                        .fill(idx == coordinator.currentStepIndex ? Tokens.slate500 : Color.primary.opacity(0.15))
                        .frame(width: idx == coordinator.currentStepIndex ? 16 : 6, height: 4)
                }
                Spacer()
            }

            HStack(spacing: 10) {
                if !coordinator.isFirst {
                    Button { coordinator.back() } label: {
                        Text(tr("tour.back"))
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(Color.primary)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.4), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                }

                Button { coordinator.next() } label: {
                    Text(coordinator.isLast ? tr("tour.finish") : tr("tour.next"))
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
}
