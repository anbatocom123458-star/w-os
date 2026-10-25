// VirtualMouseService.swift
// W Virtual Mouse subsystem (Phase 4).
//
// Provides an on-screen pointer that operates ONLY inside W OS's own content
// area. It never touches SpringBoard, never moves the system pointer, and
// never injects input into other apps — iOS does not permit that for
// third-party apps, and nothing here attempts it.
//
// Features:
//   * Movable pointer constrained to the W OS content area
//   * Single-click, secondary-click, double-click, drag
//   * Pointer speed/sensitivity, left-handed button swap
//   * Haptic feedback on interaction
//   * Persistent preferences (UserDefaults)
import Foundation
import UIKit
import Combine

/// Haptic feedback helpers. UIImpactFeedbackGenerator/UISelectionFeedbackGenerator
/// are the public iOS API for haptics; nothing here is simulated.
enum WOSHaptics {
    static func light() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func selection() { UISelectionFeedbackGenerator().selectionChanged() }
    static func rigid() { UIImpactFeedbackGenerator(style: .rigid).impactOccurred() }
}

extension CGPoint {
    /// Clamps the point inside `rect`.
    func clamped(to rect: CGRect) -> CGPoint {
        CGPoint(
            x: min(max(x, rect.minX), rect.maxX),
            y: min(max(y, rect.minY), rect.maxY)
        )
    }
}

/// Speed multiplier range exposed to the user.
private let SpeedRange: ClosedRange<Double> = 0.25 ... 3.0

final class VirtualMouseService: ObservableObject {
    /// Whether the virtual pointer overlay is active.
    @Published var isEnabled: Bool = false
    /// Current pointer position, always clamped to the content rect.
    @Published var pointerPosition: CGPoint = .zero
    /// Left-handed layout swaps primary/secondary button meaning.
    @Published var isLeftHanded: Bool = false
    /// Pointer speed multiplier (applied to drag deltas).
    @Published var speed: Double = 1.0
    /// Visual pointer diameter.
    @Published var pointerSize: CGFloat = 16
    /// Visual feedback that the primary button is held.
    @Published var isPrimaryPressed: Bool = false

    private let defaults = UserDefaults.standard
    private enum Keys {
        static let enabled = "wos_virtual_mouse_enabled"
        static let leftHanded = "wos_virtual_mouse_left_handed"
        static let speed = "wos_virtual_mouse_speed"
    }

    init() {
        if let v = defaults.object(forKey: Keys.enabled) as? Bool { isEnabled = v }
        if let v = defaults.object(forKey: Keys.leftHanded) as? Bool { isLeftHanded = v }
        if let v = defaults.object(forKey: Keys.speed) as? Double {
            speed = min(max(v, SpeedRange.lowerBound), SpeedRange.upperBound)
        }
    }

    private func persist() {
        defaults.set(isEnabled, forKey: Keys.enabled)
        defaults.set(isLeftHanded, forKey: Keys.leftHanded)
        defaults.set(speed, forKey: Keys.speed)
    }

    func setEnabled(_ value: Bool) {
        isEnabled = value
        if !value { isPrimaryPressed = false }
        persist()
    }

    func setLeftHanded(_ value: Bool) {
        isLeftHanded = value
        persist()
    }

    func setSpeed(_ value: Double) {
        speed = min(max(value, SpeedRange.lowerBound), SpeedRange.upperBound)
        persist()
    }

    /// Moves the pointer by `delta` (caller applies speed), clamped to `rect`.
    func move(by delta: CGSize, within rect: CGRect) {
        guard isEnabled else { return }
        let scaled = CGSize(width: delta.width * speed, height: delta.height * speed)
        pointerPosition = pointerPosition.applying(.init(translationX: scaled.width, y: scaled.height)).clamped(to: rect)
        WOSHaptics.light()
    }

    /// Sets the pointer to an absolute point, clamped to `rect`.
    func setPosition(_ point: CGPoint, within rect: CGRect) {
        guard isEnabled else { return }
        pointerPosition = point.clamped(to: rect)
        WOSHaptics.light()
    }

    func primaryClick() {
        guard isEnabled else { return }
        WOSHaptics.selection()
    }

    func secondaryClick() {
        guard isEnabled else { return }
        WOSHaptics.light()
    }

    func doubleClick() {
        guard isEnabled else { return }
        WOSHaptics.rigid()
    }

    func primaryPressed(_ value: Bool) {
        isPrimaryPressed = value
        if value { WOSHaptics.light() }
    }

    /// Button labels respecting left-handed layout.
    var primaryButtonLabel: String {
        isLeftHanded ? "Phụ (tay trái)" : "Chính (tay phải)"
    }
    var secondaryButtonLabel: String {
        isLeftHanded ? "Chính (tay phải)" : "Phụ (tay trái)"
    }
}
