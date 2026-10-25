// Tokens.swift
// W OS design system (Phase 3).
//
// Centralized color, typography, and spacing tokens so the whole OS shares one
// visual language. Existing `Color.wos*` names from Colors.swift are kept for
// compatibility; this file adds the missing token layers (type, spacing,
// component styles) without changing any existing view.
import SwiftUI

// MARK: - Typography tokens

enum WOSFont {
    static let display: Font = .system(size: 32, weight: .bold)   // logotype, big numbers
    static let title: Font = .system(size: 20, weight: .semibold) // section headings
    static let body: Font = .system(size: 15, weight: .regular)   // primary text
    static let caption: Font = .system(size: 13, weight: .regular) // secondary text
    static let smallCaption: Font = .system(size: 11, weight: .regular) // hints, footers
    static let monospace: Font = .system(size: 13, design: .monospaced) // terminal, code
}

// MARK: - Spacing tokens

enum WOSGrid {
    static let xxxSmall: CGFloat = 4
    static let xxSmall: CGFloat = 6
    static let xSmall: CGFloat = 8
    static let small: CGFloat = 12
    static let medium: CGFloat = 16
    static let large: CGFloat = 24
    static let xLarge: CGFloat = 32
    static let xxLarge: CGFloat = 48
}

// MARK: - Reusable component styles

/// Primary filled button used across W OS chrome.
struct WOSButtonStyle: ButtonStyle {
    var ghost: Bool = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(ghost ? .wosAccent : .white)
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background(ghost ? Color(hex: "1a1a1a") : Color.wosAccent)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(ghost ? Color.wosBorder : .clear))
            .cornerRadius(10)
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// Card background used for panels, settings rows, and window chrome.
struct WOSCard<Content: View>: View {
    var elevated: Bool = false
    @ViewBuilder let content: Content
    var body: some View {
        content
            .padding(WOSGrid.medium)
            .background(Color(hex: "111111"))
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.wosBorder))
            .shadow(color: elevated ? .black.opacity(0.45) : .black.opacity(0.2), radius: elevated ? 24 : 12, y: elevated ? 12 : 6)
    }
}

/// Toast-style feedback states: loading / empty / error / success.
struct WOSStateView: View {
    enum Kind { case loading, empty, error, success }
    let kind: Kind
    let title: String
    let icon: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(kindColor)
            Text(title)
                .font(WOSFont.body)
                .foregroundColor(kind == .error ? .wosDanger : Color(hex: "cccccc"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var kindColor: Color {
        switch kind {
        case .loading, .empty: return Color(hex: "888888")
        case .error: return .wosDanger
        case .success: return .wosSuccess
        }
    }
}
