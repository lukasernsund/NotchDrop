import SwiftUI

struct NotchView: View {
    @StateObject var vm: NotchViewModel

    @State var dropTargeting: Bool = false
    @State private var isHovering: Bool = false

    var notchSize: CGSize {
        switch vm.status {
        case .closed:
            return CGSize(
                width: vm.deviceNotchRect.width - 4,
                height: vm.deviceNotchRect.height - 4
            )
        case .opened:
            return vm.notchOpenedSize
        case .popping:
            return .init(
                width: vm.deviceNotchRect.width,
                height: vm.deviceNotchRect.height + 4
            )
        }
    }

    var notchCornerRadius: CGFloat {
        switch vm.status {
        case .closed: 8
        case .opened: 32
        case .popping: 10
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            notch
                .zIndex(0)
                .disabled(true)
                .opacity(vm.notchVisible ? 1 : 0.0)
            Group {
                if vm.status == .opened {
                    VStack(spacing: vm.spacing) {
                        NotchHeaderView(vm: vm)
                        GeometryReader { geometry in
                            NotchContentView(vm: vm)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .onChange(of: geometry.size) { newSize in
                                    vm.updateContentHeight(newSize.height)
                                }
                        }
                    }
                    .padding(vm.spacing)
                    .frame(maxWidth: vm.notchOpenedSize.width, maxHeight: vm.notchOpenedSize.height)
                    .zIndex(1)
                }
            }
            .transition(
                .scale.combined(
                    with: .opacity
                ).combined(
                    with: .offset(y: -vm.notchOpenedSize.height / 2)
                ).animation(vm.animation)
            )
        }
        .background(dragDetecter)
        .animation(vm.animation, value: vm.status)
        .animation(vm.animation, value: vm.notchOpenedSize)
        .preferredColorScheme(.dark)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onHover { hovering in
            guard vm.status == .opened else {
                return  // Ensure logic runs only when notch is opened
            }
            isHovering = hovering
            if !hovering {
                // Check if the mouse is genuinely outside the notch's bounds
                let mouseLocation = NSEvent.mouseLocation
                if !NSPointInRect(mouseLocation, NSRect(origin: .zero, size: notchSize)) {
                    vm.notchPop()
                }
            }
        }
    }

    var notch: some View {
        Rectangle()
            .foregroundStyle(.black)
            .mask(notchBackgroundMaskGroup)
            .frame(
                width: notchSize.width + notchCornerRadius * 2,
                height: notchSize.height
            )
            .padding(.bottom, 20) // Added padding to avoid shadow cutoff
            .shadow(
                color: .black.opacity(([.opened, .popping].contains(vm.status)) ? 1 : 0),
                radius: 16
            )
            .animation(vm.animation, value: notchSize) // Add animation for size changes
    }

    var notchBackgroundMaskGroup: some View {
        Rectangle()
            .foregroundStyle(.black)
            .frame(
                width: notchSize.width,
                height: notchSize.height
            )
            .clipShape(.rect(
                bottomLeadingRadius: notchCornerRadius,
                bottomTrailingRadius: notchCornerRadius
            ))
            .overlay {
                ZStack(alignment: .topTrailing) {
                    Rectangle()
                        .frame(width: notchCornerRadius, height: notchCornerRadius)
                        .foregroundStyle(.black)
                    Rectangle()
                        .clipShape(.rect(topTrailingRadius: notchCornerRadius))
                        .foregroundStyle(.white)
                        .frame(
                            width: notchCornerRadius + vm.spacing,
                            height: notchCornerRadius + vm.spacing
                        )
                        .blendMode(.destinationOut)
                }
                .compositingGroup()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .offset(x: -notchCornerRadius - vm.spacing + 0.5, y: -0.5)
            }
            .overlay {
                ZStack(alignment: .topLeading) {
                    Rectangle()
                        .frame(width: notchCornerRadius, height: notchCornerRadius)
                        .foregroundStyle(.black)
                    Rectangle()
                        .clipShape(.rect(topLeadingRadius: notchCornerRadius))
                        .foregroundStyle(.white)
                        .frame(
                            width: notchCornerRadius + vm.spacing,
                            height: notchCornerRadius + vm.spacing
                        )
                        .blendMode(.destinationOut)
                }
                .compositingGroup()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .offset(x: notchCornerRadius + vm.spacing - 0.5, y: -0.5)
            }
    }

    var dragDetecter: some View {
        RoundedRectangle(cornerRadius: notchCornerRadius)
            .foregroundStyle(Color.black.opacity(0.001))
            .contentShape(Rectangle())
            .frame(width: vm.deviceNotchRect.width + vm.dropDetectorRange, height: vm.deviceNotchRect.height + vm.dropDetectorRange)
            .onDrop(of: [.data], isTargeted: $dropTargeting) { _ in true }
            .onChange(of: dropTargeting) { newValue in
                if newValue {
                    vm.showDropPage()
                    vm.hapticSender.send()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
