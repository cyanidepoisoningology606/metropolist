import SwiftUI
import TransitModels

struct TravelReplayView: View {
    @State private var viewModel: TravelReplayViewModel

    init(
        travels: [Travel],
        segments: [TimelineViewModel.TravelMapSegment],
        lines: [String: TransitLine],
        stationNames: [String: String]
    ) {
        _viewModel = State(initialValue: TravelReplayViewModel(
            travels: travels,
            segments: segments,
            lines: lines,
            stationNames: stationNames
        ))
    }

    var body: some View {
        GeometryReader { geo in
            let topInset = geo.safeAreaInsets.top + 56
            let bottomInset = geo.safeAreaInsets.bottom + 100
            ZStack {
                ReplayMapView(
                    viewModel: viewModel,
                    topInset: topInset,
                    bottomInset: bottomInset,
                    mapHeight: geo.size.height
                )
                .ignoresSafeArea()

                ReplayControlsOverlay(viewModel: viewModel)
            }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .task {
            try? await Task.sleep(for: .milliseconds(500))
            viewModel.play()
        }
        .onDisappear {
            viewModel.pause()
        }
    }
}
