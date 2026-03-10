import CoreLocation
import MapKit

struct IndexedPoint {
    nonisolated let sourceID: String
    nonisolated let lng: Double
    nonisolated let lat: Double
    nonisolated let name: String
}

struct MapCluster: Identifiable {
    nonisolated let id: String
    nonisolated let coordinate: CLLocationCoordinate2D
    nonisolated let pointCount: Int
    nonisolated let stationSourceID: String?
    nonisolated let name: String
    nonisolated let sourceIDs: [String]
}

enum Mercator {
    nonisolated static func lngToX(_ lng: Double) -> Double {
        lng / 360 + 0.5
    }

    nonisolated static func latToY(_ lat: Double) -> Double {
        let sinLat = sin(lat * .pi / 180)
        let val = 0.5 - 0.25 * log((1 + sinLat) / (1 - sinLat)) / .pi
        return min(max(val, 0), 1)
    }

    nonisolated static func xToLng(_ xVal: Double) -> Double {
        (xVal - 0.5) * 360
    }

    nonisolated static func yToLat(_ yVal: Double) -> Double {
        let radians = (180 - yVal * 360) * .pi / 180
        return 360 * atan(exp(radians)) / .pi - 90
    }
}

final class SpatialIndex: Sendable {
    private nonisolated let trees: [Int: KDBush]
    private nonisolated let clusterData: [Int: [ClusterNode]]
    private nonisolated let minZoom: Int
    private nonisolated let maxZoom: Int
    nonisolated let boundingRegion: MKCoordinateRegion?

    struct ClusterNode {
        nonisolated let xCoord: Double
        nonisolated let yCoord: Double
        nonisolated let count: Int
        nonisolated let sourceID: String?
        nonisolated let name: String
        nonisolated let sourceIDs: [String]
    }

    nonisolated init(
        points: [IndexedPoint],
        radius: Double = 44,
        minZoom: Int = 2,
        maxZoom: Int = 19,
        extent: Double = 256
    ) {
        self.minZoom = minZoom
        self.maxZoom = maxZoom

        boundingRegion = Self.computeBounds(points)

        let projected: [ClusterNode] = points.map { point in
            ClusterNode(
                xCoord: Mercator.lngToX(point.lng),
                yCoord: Mercator.latToY(point.lat),
                count: 1,
                sourceID: point.sourceID,
                name: point.name,
                sourceIDs: [point.sourceID]
            )
        }

        var currentNodes = projected
        var builtTrees: [Int: KDBush] = [:]
        var builtData: [Int: [ClusterNode]] = [:]

        builtData[maxZoom + 1] = currentNodes
        builtTrees[maxZoom + 1] = KDBush(points: currentNodes.map { ($0.xCoord, $0.yCoord) })

        for zoom in stride(from: maxZoom, through: minZoom, by: -1) {
            currentNodes = Self.clusterAtZoom(
                nodes: currentNodes, zoom: zoom, radius: radius, extent: extent
            )
            builtData[zoom] = currentNodes
            builtTrees[zoom] = KDBush(points: currentNodes.map { ($0.xCoord, $0.yCoord) })
        }

        trees = builtTrees
        clusterData = builtData
    }

    nonisolated func getClusters(region: MKCoordinateRegion, zoom: Int) -> [MapCluster] {
        let clampedZoom = zoom >= 13 ? maxZoom + 1 : max(minZoom, min(zoom, maxZoom + 1))
        guard let tree = trees[clampedZoom], let nodes = clusterData[clampedZoom] else { return [] }

        let minLng = region.center.longitude - region.span.longitudeDelta / 2
        let maxLng = region.center.longitude + region.span.longitudeDelta / 2
        let minLat = region.center.latitude - region.span.latitudeDelta / 2
        let maxLat = region.center.latitude + region.span.latitudeDelta / 2

        let projMinX = Mercator.lngToX(minLng)
        let projMaxX = Mercator.lngToX(maxLng)
        let projMinY = Mercator.latToY(maxLat)
        let projMaxY = Mercator.latToY(minLat)

        let indices = tree.range(
            minX: min(projMinX, projMaxX), minY: min(projMinY, projMaxY),
            maxX: max(projMinX, projMaxX), maxY: max(projMinY, projMaxY)
        )

        return indices.map { idx in
            let node = nodes[idx]
            let lat = Mercator.yToLat(node.yCoord)
            let lng = Mercator.xToLng(node.xCoord)
            let clusterID = if let sid = node.sourceID {
                sid
            } else {
                "cluster_\(clampedZoom)_\(idx)"
            }
            return MapCluster(
                id: clusterID,
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                pointCount: node.count,
                stationSourceID: node.sourceID,
                name: node.name,
                sourceIDs: node.sourceIDs
            )
        }
    }

    nonisolated func boundingRegion(for stationIDs: Set<String>) -> MKCoordinateRegion? {
        guard let nodes = clusterData[maxZoom + 1] else { return nil }
        var minLat = Double.greatestFiniteMagnitude
        var maxLat = -Double.greatestFiniteMagnitude
        var minLng = Double.greatestFiniteMagnitude
        var maxLng = -Double.greatestFiniteMagnitude
        var found = false
        for node in nodes {
            guard let sid = node.sourceID, stationIDs.contains(sid) else { continue }
            let lat = Mercator.yToLat(node.yCoord)
            let lng = Mercator.xToLng(node.xCoord)
            minLat = min(minLat, lat); maxLat = max(maxLat, lat)
            minLng = min(minLng, lng); maxLng = max(maxLng, lng)
            found = true
        }
        guard found else { return nil }
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLng + maxLng) / 2),
            span: MKCoordinateSpan(latitudeDelta: maxLat - minLat, longitudeDelta: maxLng - minLng)
        )
    }

    private nonisolated static func computeBounds(_ points: [IndexedPoint]) -> MKCoordinateRegion? {
        guard let first = points.first else { return nil }
        var minLat = first.lat, maxLat = first.lat, minLng = first.lng, maxLng = first.lng
        for point in points.dropFirst() {
            minLat = min(minLat, point.lat); maxLat = max(maxLat, point.lat)
            minLng = min(minLng, point.lng); maxLng = max(maxLng, point.lng)
        }
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLng + maxLng) / 2),
            span: MKCoordinateSpan(latitudeDelta: maxLat - minLat, longitudeDelta: maxLng - minLng)
        )
    }

    // MARK: - Clustering Logic

    private nonisolated static func clusterAtZoom(
        nodes: [ClusterNode], zoom: Int, radius: Double, extent: Double
    ) -> [ClusterNode] {
        let clusterRadius = radius / (extent * pow(2, Double(zoom)))
        var clustered: [ClusterNode] = []
        var visited = [Bool](repeating: false, count: nodes.count)
        let tree = KDBush(points: nodes.map { ($0.xCoord, $0.yCoord) })

        for nodeIndex in 0 ..< nodes.count {
            guard !visited[nodeIndex] else { continue }
            let node = nodes[nodeIndex]
            let neighborIndices = tree.within(centerX: node.xCoord, centerY: node.yCoord, radius: clusterRadius)

            var totalX = node.xCoord * Double(node.count)
            var totalY = node.yCoord * Double(node.count)
            var totalCount = node.count
            var leafSourceID = node.sourceID
            var leafName = node.name
            var allSourceIDs = node.sourceIDs
            visited[nodeIndex] = true

            for neighborIdx in neighborIndices where neighborIdx != nodeIndex && !visited[neighborIdx] {
                let neighbor = nodes[neighborIdx]
                visited[neighborIdx] = true
                totalX += neighbor.xCoord * Double(neighbor.count)
                totalY += neighbor.yCoord * Double(neighbor.count)
                totalCount += neighbor.count
                allSourceIDs.append(contentsOf: neighbor.sourceIDs)
                leafSourceID = nil
                leafName = ""
            }

            if totalCount == node.count {
                clustered.append(node)
            } else {
                clustered.append(ClusterNode(
                    xCoord: totalX / Double(totalCount),
                    yCoord: totalY / Double(totalCount),
                    count: totalCount,
                    sourceID: leafSourceID,
                    name: leafName,
                    sourceIDs: allSourceIDs
                ))
            }
        }

        return clustered
    }
}
