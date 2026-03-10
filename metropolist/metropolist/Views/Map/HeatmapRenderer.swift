import MapKit

private struct ColorStop {
    let position: Float
    let red: UInt8
    let green: UInt8
    let blue: UInt8
    let alpha: UInt8
}

final class HeatmapRenderer: MKOverlayRenderer {
    private nonisolated static let colorRamp: [UInt32] = buildColorRamp()

    override nonisolated init(overlay: any MKOverlay) {
        super.init(overlay: overlay)
    }

    override nonisolated func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        guard let heatmap = overlay as? HeatmapOverlay else { return }
        let points = heatmap.heatPoints
        guard !points.isEmpty else { return }

        let drawRect = rect(for: mapRect)
        guard drawRect.width > 0, drawRect.height > 0 else { return }

        // Blob radius in map points — fixed geographic area (~4% of overlay width)
        let blobRadius = heatmap.boundingMapRect.size.width / 25.0
        let expanded = mapRect.insetBy(dx: -blobRadius, dy: -blobRadius)

        let visible = points.filter { expanded.contains($0.mapPoint) }
        guard !visible.isEmpty else { return }

        // Determine bitmap size from the actual draw rect and zoom scale
        let pixelWidth = max(Int(drawRect.width * CGFloat(zoomScale)), 1)
        let pixelHeight = max(Int(drawRect.height * CGFloat(zoomScale)), 1)
        // Cap to reasonable size for performance
        let maxDim = 512
        let scale: CGFloat
        let bmpWidth: Int
        let bmpHeight: Int
        if pixelWidth > maxDim || pixelHeight > maxDim {
            let downscale = CGFloat(maxDim) / CGFloat(max(pixelWidth, pixelHeight))
            bmpWidth = max(Int(CGFloat(pixelWidth) * downscale), 1)
            bmpHeight = max(Int(CGFloat(pixelHeight) * downscale), 1)
            scale = downscale * CGFloat(zoomScale)
        } else {
            bmpWidth = max(pixelWidth, 1)
            bmpHeight = max(pixelHeight, 1)
            scale = CGFloat(zoomScale)
        }

        // Blob radius in bitmap pixels
        let blobPixels = Float(blobRadius * scale)
        guard blobPixels >= 1 else { return }

        var intensities = [Float](repeating: 0, count: bmpWidth * bmpHeight)

        for station in visible {
            let rendererPt = point(for: station.mapPoint)
            let centerX = Float((rendererPt.x - drawRect.origin.x) * scale)
            let centerY = Float((rendererPt.y - drawRect.origin.y) * scale)
            stampGaussian(
                into: &intensities, width: bmpWidth, height: bmpHeight,
                centerX: centerX, centerY: centerY,
                radius: blobPixels, weight: Float(station.weight)
            )
        }

        let ramp = Self.colorRamp
        let normFactor = 1.0 / heatmap.referenceIntensity
        var pixels = [UInt32](repeating: 0, count: bmpWidth * bmpHeight)
        for idx in 0 ..< pixels.count {
            let normalized = min(intensities[idx] * normFactor, 1.0)
            pixels[idx] = ramp[min(Int(normalized * 255), 255)]
        }

        guard let image = createImage(from: &pixels, width: bmpWidth, height: bmpHeight) else { return }

        // CGContext.draw uses bottom-left origin; flip to match renderer's top-left origin
        context.saveGState()
        context.translateBy(x: drawRect.origin.x, y: drawRect.origin.y + drawRect.height)
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: CGRect(x: 0, y: 0, width: drawRect.width, height: drawRect.height))
        context.restoreGState()
    }

    // MARK: - Gaussian Stamping

    // swiftlint:disable:next function_parameter_count
    private nonisolated func stampGaussian(
        into buffer: inout [Float], width: Int, height: Int,
        centerX: Float, centerY: Float, radius: Float, weight: Float
    ) {
        let sigma = radius / 3.0
        let twoSigmaSq = 2.0 * sigma * sigma
        let intRadius = Int(ceil(radius))

        let minX = max(0, Int(centerX) - intRadius)
        let maxX = min(width - 1, Int(centerX) + intRadius)
        let minY = max(0, Int(centerY) - intRadius)
        let maxY = min(height - 1, Int(centerY) + intRadius)

        guard minX <= maxX, minY <= maxY else { return }

        let radiusSq = radius * radius

        for pixelY in minY ... maxY {
            let deltaY = Float(pixelY) - centerY
            let deltaYSq = deltaY * deltaY
            let rowOffset = pixelY * width
            for pixelX in minX ... maxX {
                let deltaX = Float(pixelX) - centerX
                let distSq = deltaX * deltaX + deltaYSq
                guard distSq <= radiusSq else { continue }
                buffer[rowOffset + pixelX] += weight * exp(-distSq / twoSigmaSq)
            }
        }
    }

    // MARK: - Image Creation

    private nonisolated func createImage(from pixels: inout [UInt32], width: Int, height: Int) -> CGImage? {
        pixels.withUnsafeMutableBytes { buffer -> CGImage? in
            guard let baseAddress = buffer.baseAddress else { return nil }
            guard let ctx = CGContext(
                data: baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return nil }
            return ctx.makeImage()
        }
    }

    // MARK: - Color Ramp

    private nonisolated static func buildColorRamp() -> [UInt32] {
        let stops: [ColorStop] = [
            ColorStop(position: 0, red: 0, green: 0, blue: 0, alpha: 0),
            ColorStop(position: 0.01, red: 0, green: 0, blue: 0, alpha: 0),
            ColorStop(position: 0.15, red: 0, green: 0, blue: 255, alpha: 100),
            ColorStop(position: 0.35, red: 0, green: 200, blue: 255, alpha: 140),
            ColorStop(position: 0.55, red: 0, green: 255, blue: 100, alpha: 160),
            ColorStop(position: 0.75, red: 255, green: 255, blue: 0, alpha: 170),
            ColorStop(position: 1.0, red: 255, green: 50, blue: 0, alpha: 180),
        ]

        var ramp = [UInt32](repeating: 0, count: 256)

        for idx in 0 ..< 256 {
            let fraction = Float(idx) / 255.0
            var lowerIdx = 0
            for stopIdx in 0 ..< stops.count - 1 where stops[stopIdx + 1].position >= fraction {
                lowerIdx = stopIdx
                break
            }
            let lower = stops[lowerIdx]
            let upper = stops[min(lowerIdx + 1, stops.count - 1)]
            let range = upper.position - lower.position
            let interp = range > 0 ? (fraction - lower.position) / range : 0

            let red = UInt8(Float(lower.red) + interp * Float(Int(upper.red) - Int(lower.red)))
            let grn = UInt8(Float(lower.green) + interp * Float(Int(upper.green) - Int(lower.green)))
            let blu = UInt8(Float(lower.blue) + interp * Float(Int(upper.blue) - Int(lower.blue)))
            let alp = UInt8(Float(lower.alpha) + interp * Float(Int(upper.alpha) - Int(lower.alpha)))

            ramp[idx] = UInt32(red) | (UInt32(grn) << 8) | (UInt32(blu) << 16) | (UInt32(alp) << 24)
        }

        return ramp
    }
}
