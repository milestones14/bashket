import Foundation

final class BrailleLoader {
    private var timer: DispatchSourceTimer?
    private var frameIndex = 0
    private let interval: TimeInterval
    private let message: String

    private static let orbit: [Int] = [1,2,3,7,8,6,5,4]

    init(message: String = "Loading", interval: TimeInterval = 0.08) {
        self.message = message
        self.interval = interval
    }

    func start() {
        guard timer == nil else { return }

        let t = DispatchSource.makeTimerSource(queue: .global(qos: .userInteractive))
        t.schedule(deadline: .now(), repeating: interval)

        t.setEventHandler { [weak self] in
            self?.render()
        }

        timer = t
        t.resume()
    }

    func stop(clearLine: Bool = true) {
        timer?.cancel()
        timer = nil

        if clearLine {
            FileHandle.standardOutput.write(Data("\r\u{001B}[K".utf8))
        }
    }

    private func render() {
        let dot = Self.orbit[frameIndex % Self.orbit.count]
        let cell = brailleCell(withDots: [dot])

        frameIndex += 1

        let out = "\r\(message) \(cell)"
        FileHandle.standardOutput.write(Data(out.utf8))
    }

    private func brailleCell(withDots dots: [Int]) -> Character {
        var mask = 0
        for d in dots where (1...8).contains(d) {
            mask |= (1 << (d - 1))
        }
        let inverted = (~mask) & 0xFF
        let scalar = 0x2800 + inverted
        return Character(UnicodeScalar(scalar)!)
    }
}

