import Foundation

enum PDFPageSelection: Equatable, Sendable {
    case all
    case pages([Int])

    func resolvedPages(totalPages: Int) -> [Int] {
        guard totalPages > 0 else { return [] }
        switch self {
        case .all:
            return Array(1...totalPages)
        case .pages(let pages):
            let validPages = pages.filter { (1...totalPages).contains($0) }
            return Array(Set(validPages)).sorted()
        }
    }
}

enum PDFPageRangeParser {
    static func parse(_ input: String) -> [Int]? {
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else { return nil }

        var pages: [Int] = []
        let parts = trimmedInput.split(separator: ",", omittingEmptySubsequences: false)
        guard !parts.isEmpty else { return nil }

        for rawPart in parts {
            let part = rawPart.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !part.isEmpty else { return nil }

            if part.contains("-") {
                let bounds = part.split(separator: "-", omittingEmptySubsequences: false)
                guard bounds.count == 2,
                      let start = Int(bounds[0].trimmingCharacters(in: .whitespacesAndNewlines)),
                      let end = Int(bounds[1].trimmingCharacters(in: .whitespacesAndNewlines)),
                      start > 0,
                      end >= start else {
                    return nil
                }
                pages.append(contentsOf: start...end)
            } else {
                guard let page = Int(part), page > 0 else {
                    return nil
                }
                pages.append(page)
            }
        }

        return Array(Set(pages)).sorted()
    }
}
