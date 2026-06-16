import SwiftUI

/// Standardized scaffold for the app's bottom sheets.
///
/// Unifies the things that used to be hand-rolled (and drifted) per sheet:
/// - a **visible drag indicator** so swipe-to-dismiss is discoverable on
///   single-detent sheets (SwiftUI hides the grabber for those by default),
/// - a single **20pt horizontal gutter** applied once to header/content/footer
///   instead of being repeated on every child,
/// - a **scrollable body** so content can't clip at large detents / Dynamic
///   Type, and
/// - a **pinned footer** (primary action) with a uniform bottom inset.
///
/// Common sheets pass a `SheetHeader`; richer ones (an inline edit toggle, an
/// icon in the subtitle) supply a custom header view.
struct SheetScaffold<Header: View, Content: View, Footer: View>: View {
    var scrolls: Bool
    @ViewBuilder var header: () -> Header
    @ViewBuilder var content: () -> Content
    @ViewBuilder var footer: () -> Footer
    private let hasFooter: Bool

    init(
        scrolls: Bool = true,
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self.scrolls = scrolls
        self.header = header
        self.content = content
        self.footer = footer
        self.hasFooter = true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header()
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 14)

            if scrolls {
                ScrollView {
                    gutteredContent
                }
            } else {
                gutteredContent
                Spacer(minLength: 0)
            }

            if hasFooter {
                footer()
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
            }
        }
        .presentationDragIndicator(.visible)
    }

    private var gutteredContent: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
    }
}

/// Footer-less convenience: sheets whose only action lives inline (or that are
/// pure read-only lists) skip the pinned footer entirely — no empty bottom gap.
extension SheetScaffold where Footer == EmptyView {
    init(
        scrolls: Bool = true,
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.scrolls = scrolls
        self.header = header
        self.content = content
        self.footer = { EmptyView() }
        self.hasFooter = false
    }
}

/// The standard sheet header: bold title, optional secondary subtitle, and an
/// optional ✕ close button on the trailing edge.
struct SheetHeader: View {
    let title: String
    var subtitle: String? = nil
    var onClose: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 20, weight: .bold))
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            if let onClose {
                SheetCloseButton(action: onClose)
            }
        }
    }
}

/// Circular ✕ used in sheet headers. Extracted so the size/treatment stays
/// identical everywhere it appears.
struct SheetCloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .bold))
                .frame(width: 32, height: 32)
                .background(Color.primary.opacity(0.06), in: Circle())
        }
        .buttonStyle(.pressable)
    }
}
