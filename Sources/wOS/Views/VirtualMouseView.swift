// VirtualMouseView.swift
// W Virtual Mouse overlay (Phase 4).
//
// Full-screen overlay shown on top of the desktop. The pointer moves only
// inside the W OS content rectangle; taps/clicks are delivered to the same
// window-management layer (focus, drag, close) via callbacks. The overlay
// itself does not forward events to SpringBoard or any other app.
import SwiftUI
import UIKit

struct VirtualMouseView: View {
    @ObservedObject var mouse: VirtualMouseService
    var onClose: () -> Void
    var onPointerAction: (() -> Void)?   // host may route a click to the front window

    @State private var showSettings = false
    @State private var gestureStart: CGPoint = .zero

    var body: some View {
        GeometryReader { geo in
            let contentRect = contentRect(in: geo)
            ZStack {
                Color.black.opacity(0.25).ignoresSafeArea()
                    .onTapGesture { onClose() }

                // Content area where the pointer is allowed to move.
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(mouse.isEnabled ? Color.wosAccent : Color.wosBorder, lineWidth: 2)
                    .frame(width: contentRect.width, height: contentRect.height)
                    .position(x: contentRect.midX, y: contentRect.midY)

                // Pointer — draggable, constrained to the content area.
                ZStack {
                    Circle().fill(.black.opacity(0.35)).frame(width: mouse.pointerSize + 4, height: mouse.pointerSize + 4)
                    Circle().fill(Color.wosAccent).frame(width: mouse.pointerSize, height: mouse.pointerSize)
                        .overlay(Circle().stroke(.white, lineWidth: 1.5))
                        .shadow(radius: 4)
                        .scaleEffect(mouse.isPrimaryPressed ? 0.85 : 1.0, anchor: .center)
                        .animation(.easeInOut(duration: 0.08), value: mouse.isPrimaryPressed)
                }
                .position(mouse.pointerPosition)
                .gesture(
                    DragGesture(minimumDistance: 2)
                        .onChanged { value in
                            let target = CGPoint(x: gestureStart.x + value.translation.width,
                                                 y: gestureStart.y + value.translation.height)
                            mouse.setPosition(target, within: contentRect)
                        }
                        .onEnded { value in
                            mouse.primaryClick()
                            onPointerAction?()
                        }
                )
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.35).onEnded { _ in
                        mouse.secondaryClick()
                    }
                )
                .onAppear {
                    gestureStart = mouse.pointerPosition
                    mouse.setPosition(CGPoint(x: contentRect.midX, y: contentRect.midY), within: contentRect)
                }
                // Controls: touchpad + buttons + settings.
                controlsPanel(contentRect: contentRect)
                    .position(x: contentRect.midX, y: contentRect.height / 2 + contentRect.height * 0.62)
            }
        }
        .background(Color.black.opacity(0.45).ignoresSafeArea())
    }

    private func contentRect(in geo: GeometryProxy) -> CGRect {
        let screen = geo.size
        let side = min(screen.width, screen.height) * 0.72
        let width = min(screen.width * 0.92, side * 1.55)
        let height = min(screen.height * 0.78, side)
        return CGRect(x: (screen.width - width) / 2, y: screen.height * 0.06, width: width, height: height)
    }

    @ViewBuilder
    private func controlsPanel(contentRect: CGRect) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Button(action: { mouse.primaryPressed(true); DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { mouse.primaryPressed(false) }; mouse.primaryClick(); onPointerAction?() }) {
                    Image(systemName: mouse.isLeftHanded ? "hand.point.right.fill" : "hand.point.left.fill")
                        .font(.system(size: 30)).foregroundColor(.white)
                }
                .frame(width: 62, height: 62)
                .background(Circle().fill(Color.wosAccent))

                Button(action: { mouse.secondaryClick() }) {
                    Image(systemName: mouse.isLeftHanded ? "hand.point.left.fill" : "hand.point.right.fill")
                        .font(.system(size: 30)).foregroundColor(.white)
                }
                .frame(width: 62, height: 62)
                .background(Circle().fill(mouse.isLeftHanded ? Color.wosAccent : Color(hex: "333333")))

                Button(action: { mouse.doubleClick() }) {
                    Image(systemName: "hand.tap.fill").font(.system(size: 30)).foregroundColor(.white)
                }
                .frame(width: 62, height: 62)
                .background(Circle().fill(Color(hex: "333333")))
            }

            HStack(spacing: 10) {
                Button(action: { showSettings.toggle() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "gearshape").font(.system(size: 14))
                        Text(showSettings ? "Ẩn cài đặt" : "Cài đặt chuột").font(.system(size: 13))
                    }
                    .foregroundColor(.wosAccent)
                }
                Button(action: { onClose() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 14))
                        Text("Đóng").font(.system(size: 13))
                    }
                    .foregroundColor(.white)
                }
            }

            if showSettings {
                settingsPanel
            }
        }
        .padding(14)
        .background(Color(hex: "1a1a1a"))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.wosBorder))
        .shadow(color: .black.opacity(0.6), radius: 24, y: 8)
    }

    @ViewBuilder
    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cài đặt chuột ảo").font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
            HStack {
                Text("Kích hoạt").font(.system(size: 13)).foregroundColor(Color(hex: "cccccc"))
                Spacer()
                Toggle("", isOn: Binding(
                    get: { mouse.isEnabled },
                    set: { mouse.setEnabled($0) }
                ))
                .labelsHidden()
            }
            HStack {
                Text("Bàn tay trái").font(.system(size: 13)).foregroundColor(Color(hex: "cccccc"))
                Spacer()
                Toggle("", isOn: Binding(
                    get: { mouse.isLeftHanded },
                    set: { mouse.setLeftHanded($0) }
                ))
                .labelsHidden()
            }
            HStack(spacing: 8) {
                Text("Tốc độ").font(.system(size: 13)).foregroundColor(Color(hex: "cccccc"))
                Slider(value: Binding(
                    get: { mouse.speed },
                    set: { mouse.setSpeed($0) }
                ), in: 0.25 ... 3.0, step: 0.25)
                .tint(.wosAccent)
                Text(String(format: "%.1f×", mouse.speed)).font(.system(size: 12, design: .monospaced)).foregroundColor(.wosAccent).frame(width: 32, alignment: .trailing)
            }
            Divider().background(Color.wosBorder)
            HStack {
                Text("Kích thước con trỏ").font(.system(size: 13)).foregroundColor(Color(hex: "cccccc"))
                Spacer()
                Slider(value: $mouse.pointerSize, in: 10 ... 34, step: 2)
                    .tint(.wosAccent)
            }
            Text("Con trỏ chỉ hoạt động trong vùng nội dung của W OS. Không điều khiển được hệ thống hoặc các ứng dụng khác.")
                .font(.system(size: 11)).foregroundColor(Color(hex: "777777"))
        }
        .padding(10)
        .background(Color(hex: "111111"))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.wosBorder))
    }
}
