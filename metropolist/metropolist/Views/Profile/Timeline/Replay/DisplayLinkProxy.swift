import QuartzCore

final class DisplayLinkProxy: NSObject {
    nonisolated(unsafe) var onFrame: ((TimeInterval) -> Void)?
    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0

    func start() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(step))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        lastTimestamp = 0
    }

    @objc private func step(_ link: CADisplayLink) {
        let delta: TimeInterval = if lastTimestamp == 0 {
            link.duration
        } else {
            link.timestamp - lastTimestamp
        }
        lastTimestamp = link.timestamp
        onFrame?(delta)
    }
}
