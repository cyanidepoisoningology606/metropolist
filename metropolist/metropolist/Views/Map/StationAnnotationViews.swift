import MapKit
import UIKit

// MARK: - Station Annotation View

final class StationAnnotationView: MKAnnotationView {
    static let reuseID = "StationPin"

    private static let dotSize: CGFloat = 18
    private var isVisited = false
    private var showsPin = false
    private var markerView: MKMarkerAnnotationView?

    override init(annotation: (any MKAnnotation)?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        frame = CGRect(origin: .zero, size: CGSize(width: Self.dotSize, height: Self.dotSize))
        backgroundColor = .clear
        isOpaque = false
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    func configure(isVisited: Bool) {
        let changed = self.isVisited != isVisited || alpha < 1
        self.isVisited = isVisited
        updateForSelection(false, animated: false)
        isAccessibilityElement = true
        if let station = annotation as? StationAnnotation {
            accessibilityLabel = station.stationName
            accessibilityHint = isVisited
                ? NSLocalizedString("Visited station, double tap to view details",
                                    comment: "Map accessibility: visited station hint")
                : NSLocalizedString("Unvisited station, double tap to view details",
                                    comment: "Map accessibility: unvisited station hint")
        }
        setNeedsDisplay()

        if changed {
            transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
            alpha = 0
            UIView.animate(
                withDuration: 0.25,
                delay: 0,
                usingSpringWithDamping: 0.7,
                initialSpringVelocity: 0.5
            ) {
                self.transform = .identity
                self.alpha = 1
            }
        }
    }

    func updateForSelection(_ selected: Bool, animated: Bool) {
        guard showsPin != selected else { return }
        showsPin = selected

        if selected {
            let marker = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: nil)
            marker.markerTintColor = isVisited ? .systemGreen : .systemGray
            marker.glyphImage = UIImage(systemName: "tram.fill")
            marker.isUserInteractionEnabled = false
            addSubview(marker)
            marker.center = CGPoint(x: bounds.midX, y: bounds.midY)
            markerView = marker

            if animated {
                marker.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
                marker.alpha = 0
                UIView.animate(
                    withDuration: 0.35,
                    delay: 0,
                    usingSpringWithDamping: 0.6,
                    initialSpringVelocity: 0.8
                ) {
                    marker.transform = .identity
                    marker.alpha = 1
                }
            }
        } else {
            markerView?.removeFromSuperview()
            markerView = nil
            setNeedsDisplay()
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        isVisited = false
        showsPin = false
        markerView?.removeFromSuperview()
        markerView = nil
    }

    override func draw(_ rect: CGRect) {
        guard !showsPin else { return }
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let inset = rect.insetBy(dx: 1, dy: 1)

        ctx.setFillColor(isVisited ? UIColor.systemGreen.cgColor : UIColor.systemGray.cgColor)
        ctx.fillEllipse(in: inset)

        ctx.setStrokeColor(UIColor.white.cgColor)
        ctx.setLineWidth(1.5)
        ctx.strokeEllipse(in: inset)
    }
}

// MARK: - Cluster Annotation View

final class ClusterAnnotationView: MKAnnotationView {
    static let reuseID = "ClusterPin"

    private let countLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.textColor = .white
        label.font = .systemFont(ofSize: 11, weight: .bold)
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
        return label
    }()

    private var visitedRatio: Double = 0

    override init(annotation: (any MKAnnotation)?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        frame = CGRect(origin: .zero, size: CGSize(width: 30, height: 30))
        backgroundColor = .clear
        isOpaque = false
        addSubview(countLabel)
        countLabel.frame = bounds
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    func configure(count: Int, visitedRatio: Double) {
        self.visitedRatio = visitedRatio
        isAccessibilityElement = true
        let visitedCount = Int(Double(count) * visitedRatio)
        accessibilityLabel = String(
            format: NSLocalizedString("%d stations, %d visited",
                                      comment: "Map accessibility: cluster annotation label"),
            count, visitedCount
        )
        accessibilityHint = NSLocalizedString("Double tap to zoom in",
                                              comment: "Map accessibility: cluster hint")
        let minSize: CGFloat = 28
        let maxSize: CGFloat = 64
        let logNorm = (log2(Double(max(count, 2))) - 1) / 12.3
        let size = minSize + (maxSize - minSize) * min(CGFloat(logNorm), 1)
        let newFrame = CGRect(origin: .zero, size: CGSize(width: size, height: size))
        let sizeChanged = frame.size != newFrame.size
        frame = newFrame
        countLabel.frame = bounds
        countLabel.text = count > 999 ? "\(count / 1000)k" : "\(count)"
        countLabel.font = .systemFont(ofSize: size > 44 ? 14 : (size > 36 ? 12 : 11), weight: .bold)
        setNeedsDisplay()

        if sizeChanged {
            transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
            alpha = 0
            UIView.animate(
                withDuration: 0.3,
                delay: 0,
                usingSpringWithDamping: 0.6,
                initialSpringVelocity: 0.8
            ) {
                self.transform = .identity
                self.alpha = 1
            }
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        countLabel.text = nil
        visitedRatio = 0
    }

    private var fillColor: UIColor {
        if visitedRatio <= 0 {
            .systemGray
        } else if visitedRatio >= 1 {
            .systemGreen
        } else {
            .systemOrange
        }
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let inset = rect.insetBy(dx: 1, dy: 1)

        ctx.setFillColor(fillColor.withAlphaComponent(0.85).cgColor)
        ctx.fillEllipse(in: inset)

        ctx.setStrokeColor(UIColor.white.cgColor)
        ctx.setLineWidth(1.5)
        ctx.strokeEllipse(in: inset)
    }
}
