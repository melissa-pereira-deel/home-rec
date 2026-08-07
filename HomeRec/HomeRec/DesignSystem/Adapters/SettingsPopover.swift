//
//  SettingsPopover.swift
//  HomeRec
//
//  The settings shelf's two pop-up menus, rebuilt as one popover.
//
//  The design system deliberately ships no picker component — a settings layout
//  is a product decision, not a design-system one — so this is composed from its
//  primitives: an eyebrow per section, chips for a choice among knowns, nav links
//  for a command.
//
//  The two controls differ on purpose. Format is a *choice* among three short,
//  fixed options, so the chips show the alternatives as well as the current
//  value: picking one is a single click, where the old menu took two, and the
//  fact that other formats exist is visible at rest. Save location is a
//  *command* — it opens a system file picker — so it stays a link.
//
//  Visibility is unchanged: the caller still gates this on `showsSettingsShelf`,
//  so the whole control disappears for the length of a take exactly as the shelf
//  did. Settings are captured at start and cannot change until it ends, and
//  hiding the control says that more plainly than disabling it would.
//

import SwiftUI

struct SettingsPopover: View {

    @EnvironmentObject var viewModel: RecorderViewModel

    @State private var isPresented = false

    var body: some View {
        GlassIconButton(
            systemImage: "slider.horizontal.3",
            accessibilityLabel: "Settings",
            accessibilityHint: "Recording format and save location"
        ) {
            isPresented.toggle()
        }
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: GlassSpacing.l) {
                formatSection
                saveLocationSection
            }
            .padding(GlassSpacing.xl)
            .frame(minWidth: 250, alignment: .leading)
            // This had no ground at all and fell back to the system popover
            // material, which is why it did not match anything. It gets the same
            // glass as every other surface.
            //
            // A popover is hosted in its own window, so both the ground and the
            // theme have to be applied here: neither is inherited from the view
            // that presented it.
            .background(GlassWindowGround())
            .glassThemeAdaptingToContrast()
        }
    }

    private var formatSection: some View {
        VStack(alignment: .leading, spacing: GlassSpacing.s) {
            GlassEyebrow("format")

            HStack(spacing: GlassSpacing.sm) {
                ForEach(AudioFormat.available, id: \.self) { format in
                    GlassChip(
                        format.shortName,
                        isSelected: format == viewModel.selectedFormat,
                        help: "New recordings are saved as \(format.displayName). This can't change while recording."
                    ) {
                        viewModel.setFormat(format)
                    }
                }
            }
        }
        // VoiceOver reads what the control changes and what it is currently set
        // to as separate things, so the value is not baked into the label.
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Recording format")
        .accessibilityValue(viewModel.selectedFormat.displayName)
    }

    private var saveLocationSection: some View {
        VStack(alignment: .leading, spacing: GlassSpacing.s) {
            GlassEyebrow("saving to")

            HStack(spacing: GlassSpacing.m) {
                // Truncated in the middle: the leading path component and the
                // folder's own name are the two parts that identify it, and a
                // tail truncation would drop the half that matters.
                Text(viewModel.saveLocationName)
                    .glassText(.caption, color: .textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                GlassNavLink("Choose folder…") {
                    viewModel.chooseSaveLocation()
                }

                if viewModel.hasCustomSaveLocation {
                    GlassNavLink("Reset to Desktop") {
                        viewModel.resetSaveLocation()
                    }
                }
            }
        }
        .help(viewModel.saveLocationPath)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Save location")
        .accessibilityValue(viewModel.saveLocationName)
    }
}
