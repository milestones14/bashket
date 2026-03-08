import Foundation

extension Array {
    func safeGetAtRange(_ index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

extension String {
    func confirmTrailingSlash() -> String {
        return self.hasSuffix("/") ? self : self + "/"
    }
}
