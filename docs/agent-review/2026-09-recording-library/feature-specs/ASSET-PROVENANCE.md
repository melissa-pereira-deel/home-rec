# Prototype artwork provenance

The assets in `assets/` were generated for the recording-library design studies with OpenAI's built-in image generation tool. They are prototype artwork and are not included in the native application target.

## Jewel-case asset

Files:

- `virgin-cd-master-v1.png` — 1254 × 1254, transparent RGBA
- `virgin-cd-thumbnail-v1.png` — 512 × 512, transparent RGBA

Prompt intent: create an original, front-facing clear jewel case containing a pristine silver CD-R with restrained spectral reflections. A user-supplied physical-media image informed only the general frontal composition and material language. The generated asset deliberately excludes album branding, text, labels and the reference image's red sticker.

The final edit removed the generated background and preserved genuine alpha around the complete case.

## Isolated-disc asset

Files:

- `virgin-disc-master-v1.png` — 1254 × 1254, transparent RGBA
- `virgin-disc-thumbnail-v1.png` — 512 × 512, transparent RGBA

Prompt intent: isolate and refine only the pristine silver compact disc from the generated jewel-case asset. Remove the case, tray, environment and shadow; retain a complete circular edge, transparent center hub, dark inner ring and restrained cyan, violet, green and rainbow diffraction on genuine transparent alpha.

The Color Disc prototype composites this single bitmap over code-driven gallery colors. It does not generate or store a separate image for each recording.

## Product-use constraints

- Treat both images as decorative; filenames and metadata remain the accessible identity.
- Preserve aspect ratio and alpha. Do not crop the case or disc edges.
- Review native 1×/2× rendering, Increase Contrast and Reduce Transparency before adoption.
- Keep production artwork selection separate from the Contact Sheet layout decision.
