import Foundation

struct TermStylePresets {
    static let error: [TermStyle] = [.redText, .bold]
    static let success: [TermStyle] = [.greenText, .bold]
}

enum TermStyle: Hashable {
    case bold, dim, italic, underline, strikethrough
    case blackText, redText, greenText, yellowText, blueText, magentaText, cyanText, whiteText
    case blackBackground, redBackground, greenBackground, yellowBackground, blueBackground, magentaBackground, cyanBackground, whiteBackground

    fileprivate var ansiCode: String {
        switch self {
        case .bold: return "1"
        case .dim: return "2"
        case .italic: return "3"
        case .underline: return "4"
        case .strikethrough: return "9"
        case .blackText: return "30"
        case .redText: return "31"
        case .greenText: return "32"
        case .yellowText: return "33"
        case .blueText: return "34"
        case .magentaText: return "35"
        case .cyanText: return "36"
        case .whiteText: return "37"
        case .blackBackground: return "40"
        case .redBackground: return "41"
        case .greenBackground: return "42"
        case .yellowBackground: return "43"
        case .blueBackground: return "44"
        case .magentaBackground: return "45"
        case .cyanBackground: return "46"
        case .whiteBackground: return "47"
        }
    }
}

extension String {
    func termStyled(_ styles: [TermStyle]) -> String {
        guard !styles.isEmpty else { return self }
        var seen = Set<TermStyle>()
        let unique = styles.filter { seen.insert($0).inserted }
        let codes = unique.map { $0.ansiCode }.joined(separator: ";")
        let start = "\u{001B}[\(codes)m"
        let reset = "\u{001B}[0m"
        return start + self + reset
    }
}
