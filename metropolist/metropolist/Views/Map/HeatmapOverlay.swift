import MapKit

final class HeatmapOverlay: NSObject, MKOverlay {
    nonisolated let coordinate: CLLocationCoordinate2D
    nonisolated let boundingMapRect: MKMapRect
    nonisolated let heatPoints: [StationHeatPoint]
    /// Global peak intensity for consistent color mapping across tiles.
    nonisolated let referenceIntensity: Float

    nonisolated init(heatPoints: [StationHeatPoint]) {
        self.heatPoints = heatPoints

        guard let first = heatPoints.first else {
            coordinate = CLLocationCoordinate2D()
            boundingMapRect = MKMapRect.world
            referenceIntensity = 1
            super.init()
            return
        }

        var minX = first.mapPoint.x
        var maxX = minX
        var minY = first.mapPoint.y
        var maxY = minY

        for point in heatPoints.dropFirst() {
            minX = min(minX, point.mapPoint.x)
            maxX = max(maxX, point.mapPoint.x)
            minY = min(minY, point.mapPoint.y)
            maxY = max(maxY, point.mapPoint.y)
        }

        let paddingX = (maxX - minX) * 0.15
        let paddingY = (maxY - minY) * 0.15

        let bounds = MKMapRect(
            x: minX - paddingX,
            y: minY - paddingY,
            width: maxX - minX + paddingX * 2,
            height: maxY - minY + paddingY * 2
        )
        boundingMapRect = bounds
        let centerPoint = MKMapPoint(x: (minX + maxX) / 2, y: (minY + maxY) / 2)
        coordinate = centerPoint.coordinate

        // Compute global peak: for each point, sum Gaussian contributions from all neighbors
        let blobRadius = bounds.size.width / 25.0
        let sigma = blobRadius / 3.0
        let twoSigmaSq = Float(2.0 * sigma * sigma)
        let radiusSq = Float(blobRadius * blobRadius)
        var peak: Float = 0

        for idx in 0 ..< heatPoints.count {
            let point = heatPoints[idx]
            var accum: Float = 0
            for other in heatPoints {
                let deltaX = Float(other.mapPoint.x - point.mapPoint.x)
                let deltaY = Float(other.mapPoint.y - point.mapPoint.y)
                let distSq = deltaX * deltaX + deltaY * deltaY
                guard distSq <= radiusSq else { continue }
                accum += Float(other.weight) * exp(-distSq / twoSigmaSq)
            }
            peak = max(peak, accum)
        }

        referenceIntensity = max(peak, 0.001)
        super.init()
    }
}
