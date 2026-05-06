import SwiftUI

struct LocalizedParagraphModifier: ViewModifier {
    let language: AppPreferences.Language

    func body(content: Content) -> some View {
        content
            .multilineTextAlignment(language == .hebrew ? .trailing : .leading)
            .environment(\.layoutDirection, language == .hebrew ? .rightToLeft : .leftToRight)
    }
}

struct LocalizedLayoutModifier: ViewModifier {
    let language: AppPreferences.Language

    func body(content: Content) -> some View {
        content
            .environment(\.layoutDirection, language == .hebrew ? .rightToLeft : .leftToRight)
    }
}

extension View {
    func localizedParagraph(_ language: AppPreferences.Language) -> some View {
        modifier(LocalizedParagraphModifier(language: language))
    }

    func localizedLayout(_ language: AppPreferences.Language) -> some View {
        modifier(LocalizedLayoutModifier(language: language))
    }
}
