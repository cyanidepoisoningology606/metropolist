import SwiftUI

struct RecapPresentation: Identifiable, Equatable {
    let kind: RecapKind
    var id: String {
        switch kind {
        case let .monthly(month):
            "m-\(month.year ?? 0)-\(month.month ?? 0)"
        case let .yearly(year):
            "y-\(year)"
        }
    }
}

enum RecapStoryPage: Equatable {
    case hero
    case numbers
    case distance
    case leveledUp
    case topLine
    case discoveries
    case summary
}

struct MonthlyRecapView: View {
    @State var viewModel: MonthlyRecapViewModel
    @State private var currentPage = 0
    @State private var animationPhase = 0
    @State private var phaseTask: Task<Void, Never>?
    @State private var pages: [RecapStoryPage] = []
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(month: DateComponents, dataStore: DataStore) {
        _viewModel = State(initialValue: MonthlyRecapViewModel(month: month, dataStore: dataStore))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.isEmpty || pages.isEmpty {
                emptyStoryState
            } else {
                storyContent
            }
        }
        .background(Color.black.ignoresSafeArea())
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .task {
            await viewModel.load()
            pages = buildPages()
            triggerPageAnimation()
        }
    }
}

// MARK: - Story Content

private extension MonthlyRecapView {
    var storyContent: some View {
        StoryContainer(
            pageCount: pages.count,
            currentPage: $currentPage,
            onDismiss: { dismiss() },
            content: { pageIndex in
                storyPage(pages[pageIndex])
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        )
        .onChange(of: currentPage) {
            triggerPageAnimation()
        }
    }

    @ViewBuilder
    func storyPage(_ page: RecapStoryPage) -> some View {
        if let context = viewModel.context {
            switch page {
            case .hero:
                HeroStoryPage(
                    viewModel: viewModel,
                    snapshot: context.current,
                    animationPhase: animationPhase
                )
            case .numbers:
                NumbersStoryPage(
                    viewModel: viewModel,
                    snapshot: context.current,
                    previous: context.previous,
                    animationPhase: animationPhase
                )
            case .distance:
                DistanceStoryPage(
                    viewModel: viewModel,
                    animationPhase: animationPhase
                )
            case .leveledUp:
                LeveledUpStoryPage(
                    viewModel: viewModel,
                    animationPhase: animationPhase
                )
            case .topLine:
                TopLineStoryPage(
                    viewModel: viewModel,
                    snapshot: context.current,
                    animationPhase: animationPhase
                )
            case .discoveries:
                DiscoveriesStoryPage(
                    viewModel: viewModel,
                    animationPhase: animationPhase
                )
            case .summary:
                SummaryStoryPage(
                    viewModel: viewModel,
                    snapshot: context.current,
                    animationPhase: animationPhase,
                    onClose: { dismiss() }
                )
            }
        }
    }
}

// MARK: - Page Building

private extension MonthlyRecapView {
    func buildPages() -> [RecapStoryPage] {
        guard viewModel.context != nil else { return [] }
        var result: [RecapStoryPage] = [.hero, .numbers]
        if viewModel.totalDistance > 0 {
            result.append(.distance)
        }
        if !viewModel.resolvedBadgeUpgrades.isEmpty {
            result.append(.leveledUp)
        }
        if viewModel.resolvedTopLine != nil {
            result.append(.topLine)
        }
        let discoveries = viewModel.resolvedDiscoveries
        if !discoveries.newLines.isEmpty || !discoveries.newStations.isEmpty {
            result.append(.discoveries)
        }
        result.append(.summary)
        return result
    }
}

// MARK: - Animation

private extension MonthlyRecapView {
    func triggerPageAnimation() {
        phaseTask?.cancel()
        if reduceMotion {
            animationPhase = 4
            return
        }
        animationPhase = 0
        phaseTask = Task { @MainActor in
            let delays = [100, 250, 250, 300]
            for (index, delay) in delays.enumerated() {
                try? await Task.sleep(for: .milliseconds(delay))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.45)) {
                    animationPhase = index + 1
                }
            }
        }
    }
}

// MARK: - Empty State

private extension MonthlyRecapView {
    var emptyStoryState: some View {
        VStack(spacing: 16) {
            Text(viewModel.formattedMonth)
                .font(.title.bold())
                .foregroundStyle(.white)
            Text("No travels recorded this month", comment: "Story: empty state message")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
            Button(String(localized: "Close", comment: "Story: close button")) {
                dismiss()
            }
            .foregroundStyle(.white)
            .padding(.top, 24)
        }
    }
}
