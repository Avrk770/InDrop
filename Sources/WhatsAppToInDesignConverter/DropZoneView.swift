import SwiftUI

struct DropZoneView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var settings = AppSettingsStore.shared
    let state: DropConversionViewModel.ViewState
    let isTargeted: Bool
    let onPickFiles: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 13) {
            ZStack {
                Circle()
                    .fill(iconBackground)
                    .frame(width: 42, height: 42)

                Image(systemName: isTargeted ? "square.and.arrow.down.fill" : "tray.and.arrow.down.fill")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)
                    .localizedParagraph(settings.language)

                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(subtitleColor)
                    .lineLimit(2)
                    .localizedParagraph(settings.language)
            }

            Spacer(minLength: 8)

            if state == .processing {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 54, height: 28)
            } else {
                Button(action: onPickFiles) {
                    Label(AppStrings.chooseFiles(), systemImage: "folder")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(AppStrings.chooseImages())
            }
        }
        .frame(maxWidth: .infinity, minHeight: 86, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(background)
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(borderColor, lineWidth: isTargeted ? 1.5 : 1)
        }
        .shadow(color: shadowColor, radius: isTargeted ? 10 : 0, y: 0)
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture(perform: onPickFiles)
        .onHover { hovered in
            isHovered = hovered
            if hovered {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }

    private var title: String {
        switch state {
        case .dragging:
            return AppStrings.dropZoneDraggingTitle()
        case .processing:
            return AppStrings.dropZoneProcessingTitle()
        case .queued:
            return AppStrings.dropZoneQueuedTitle()
        case .finished:
            return AppStrings.dropZoneFinishedTitle()
        case .idle:
            return AppStrings.dropZoneIdleTitle()
        }
    }

    private var subtitle: String {
        switch state {
        case .dragging:
            return AppStrings.dropZoneDraggingSubtitle()
        case .processing:
            return AppStrings.dropZoneProcessingSubtitle()
        case .queued, .finished, .idle:
            return AppStrings.dropZoneDefaultSubtitle()
        }
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(backgroundFill)
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(innerGlow)
            }
    }

    private var borderColor: Color {
        if isTargeted {
            return colorScheme == .dark
                ? Color(red: 0.45, green: 0.6, blue: 0.82).opacity(0.95)
                : Color.accentColor.opacity(0.8)
        }
        return colorScheme == .dark
            ? Color.white.opacity(isHovered ? 0.16 : 0.11)
            : Color.primary.opacity(isHovered ? 0.2 : 0.14)
    }

    private var iconBackground: Color {
        if isTargeted {
            return colorScheme == .dark
                ? Color(red: 0.35, green: 0.48, blue: 0.7).opacity(0.32)
                : Color.accentColor.opacity(0.16)
        }
        return colorScheme == .dark
            ? Color.white.opacity(isHovered ? 0.11 : 0.085)
            : Color.white.opacity(isHovered ? 0.78 : 0.7)
    }

    private var iconColor: Color {
        if isTargeted {
            return colorScheme == .dark
                ? Color(red: 0.78, green: 0.86, blue: 0.96)
                : .accentColor
        }
        return .primary
    }

    private var shadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.24) : Color.accentColor.opacity(0.18)
    }

    private var subtitleColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.62) : .secondary
    }

    private var backgroundFill: LinearGradient {
        if isTargeted {
            if colorScheme == .dark {
                return LinearGradient(
                    colors: [
                        Color(red: 0.15, green: 0.2, blue: 0.28),
                        Color(red: 0.11, green: 0.15, blue: 0.22)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            return LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.16),
                    Color.accentColor.opacity(0.09)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        if colorScheme == .dark {
            return LinearGradient(
                colors: [
                    Color.white.opacity(isHovered ? 0.06 : 0.045),
                    Color.white.opacity(isHovered ? 0.035 : 0.025)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }

        return LinearGradient(
            colors: [
                Color.black.opacity(isHovered ? 0.07 : 0.055),
                Color.black.opacity(isHovered ? 0.05 : 0.04)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var innerGlow: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [
                    Color.white.opacity(isTargeted ? 0.05 : 0.03),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .center
            )
        }

        return LinearGradient(
            colors: [
                Color.white.opacity(isTargeted ? 0.18 : 0.1),
                Color.clear
            ],
            startPoint: .top,
            endPoint: .center
        )
    }
}
