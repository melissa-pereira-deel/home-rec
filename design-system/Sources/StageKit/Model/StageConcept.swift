import SwiftUI

/// A design a stage can host.
///
/// Concrete rather than a protocol: a stage's whole purpose is holding
/// *competing* designs, which are necessarily different types, so any protocol
/// version would need erasing at the array boundary anyway. Erasing once, here,
/// keeps the consumer's declaration to one line per concept.
///
/// The content closure receives a `Binding` to the shared model, so a concept
/// is fully interactive — pressing a control inside concept 3 moves the same
/// state the scrubber moves, and switching to concept 1 shows the result.
/// Continuity across concepts is the entire argument for a stage.
@available(macOS 15.0, *)
public struct StageConcept<Model>: Identifiable {
    public let id: String
    /// Shown in the tab bar. Uppercased at render time.
    public let title: String
    /// Optional one-line note about the direction, for gallery and docs use.
    public let subtitle: String?

    private let makeBody: (Binding<Model>) -> AnyView

    public init<Content: View>(
        id: String,
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: @escaping (Binding<Model>) -> Content
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.makeBody = { AnyView(content($0)) }
    }

    /// Title-derived id, for the common case where the title is already unique.
    public init<Content: View>(
        _ title: String,
        subtitle: String? = nil,
        @ViewBuilder content: @escaping (Binding<Model>) -> Content
    ) {
        self.init(id: stageSlug(title), title: title, subtitle: subtitle, content: content)
    }

    public func view(state: Binding<Model>) -> AnyView {
        makeBody(state)
    }
}

/// Opt-in conformance for concepts that prefer to declare their own identity
/// alongside their view code rather than at the call site.
///
/// ```swift
/// struct CardConcept: StageConceptView {
///     static let conceptTitle = "Card"
///     @Binding var state: AppState
///     init(state: Binding<AppState>) { self._state = state }
///     var body: some View { ... }
/// }
///
/// let concepts = [CardConcept.stageConcept(), ListConcept.stageConcept()]
/// ```
@available(macOS 15.0, *)
public protocol StageConceptView: View {
    associatedtype Model
    static var conceptID: String { get }
    static var conceptTitle: String { get }
    static var conceptSubtitle: String? { get }
    init(state: Binding<Model>)
}

@available(macOS 15.0, *)
extension StageConceptView {
    public static var conceptID: String { stageSlug(conceptTitle) }
    public static var conceptSubtitle: String? { nil }

    public static func stageConcept() -> StageConcept<Model> {
        StageConcept(
            id: conceptID,
            title: conceptTitle,
            subtitle: conceptSubtitle
        ) { Self(state: $0) }
    }
}
