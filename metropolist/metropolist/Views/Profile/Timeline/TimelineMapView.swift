import MapKit
import SwiftUI

struct TimelineMapView: View {
    let segments: [TimelineViewModel.TravelMapSegment]
    let highlightedTravelID: String?
    @Binding var cameraPosition: MapCameraPosition
    let onAnnotationTap: (String) -> Void
    let onBackgroundTap: () -> Void

    @AppStorage("mapStyle") private var mapStyle: String = "standard"

    var body: some View {
        Map(position: $cameraPosition) {
            ForEach(segments) { segment in
                let isHighlighted = highlightedTravelID == nil || highlightedTravelID == segment.id
                let opacity = isHighlighted ? 1.0 : 0.25
                let lineWidth: CGFloat = isHighlighted && highlightedTravelID != nil ? 5 : 3

                MapPolyline(coordinates: segment.coordinates)
                    .stroke(segment.lineColor.opacity(opacity), lineWidth: lineWidth)

                Annotation("", coordinate: segment.originCoordinate, anchor: .center) {
                    stationDot(color: segment.lineColor, opacity: opacity)
                        .onTapGesture { onAnnotationTap(segment.id) }
                }

                Annotation("", coordinate: segment.destinationCoordinate, anchor: .center) {
                    stationDot(color: segment.lineColor, opacity: opacity)
                        .onTapGesture { onAnnotationTap(segment.id) }
                }
            }
        }
        .mapStyle(mapStyle == "satellite" ? .imagery : mapStyle == "hybrid" ? .hybrid : .standard)
        .onTapGesture { onBackgroundTap() }
    }

    private func stationDot(color: Color, opacity: Double) -> some View {
        Circle()
            .fill(.white)
            .stroke(color.opacity(opacity), lineWidth: 2)
            .frame(width: 10, height: 10)
    }
}
