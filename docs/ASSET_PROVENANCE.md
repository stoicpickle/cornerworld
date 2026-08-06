# Asset provenance

Cornerworld records the origin and review history of non-code assets so the
project can remain safe to share, modify, and redistribute. This ledger covers
AI-assisted assets as well as any future third-party material. It is a practical
project record, not legal advice.

## Routine for new assets

Before merging a generated or third-party asset:

1. Confirm that the source material, references, names, and prompts are original,
   licensed for this use, or in the public domain.
2. Review the provider's current terms and record the provider, tool or model,
   generation date, terms-review date, prompt or creative brief, seed when
   available, references, and meaningful human edits below. Use `Not available`
   for a missing seed and `None` when no external reference was used so every
   record remains structurally complete.
3. Do not add credentials, private source material, copied character designs,
   trademarks, sampled audio, or an unmodified asset whose redistribution rights
   are unclear.
4. Keep the asset inside Cornerworld's authored presentation instead of
   publishing it as a standalone stock-asset pack unless the provider's terms
   explicitly permit that use.
5. Verify the asset at its shipped size, run the normal test/build gates, and
   attach before-and-after screenshots for a visual change.
6. Update this ledger and check the asset-provenance item in the pull request.

If a provider's terms materially change or ownership is uncertain, leave the
asset out until the question is resolved. Attribution should be included when a
source license requires it, even though the current Retro Diffusion terms do not
state an attribution requirement.

## Retro Diffusion review

Retro Diffusion is operated by Astropulse LLC. Its
[Terms of Service](https://www.retrodiffusion.ai/terms) were reviewed on
August 5, 2026; the linked terms document was dated August 19, 2025. Section 7
states that Retro Diffusion does not claim ownership of customer designs or
materials and that customers retain their rights.

That does not guarantee that every generated image is copyrightable or free of
third-party rights. Prompts and references must therefore remain original, and
the shipped work should include meaningful human selection, editing,
compositing, palette treatment, animation, or code integration. See the
[U.S. Copyright Office guidance on AI-assisted works](https://www.copyright.gov/newsnet/2025/1060.html)
for the distinction between human-authored expression and purely generated
material.

The files below are included under Cornerworld's MIT license to the extent that
applicable rights exist. Retro Diffusion does not endorse or sponsor
Cornerworld.

## Current generated assets

### `canopy-lofi-background.png`

- **Path:** `Sources/TrailApp/Resources/canopy-lofi-background.png`
- **Provider/mode:** Retro Diffusion, RD Fast Retro
- **Generated:** August 5, 2026
- **Terms reviewed:** August 5, 2026
- **Introduced:** Commit [`9556828`](https://github.com/stoicpickle/cornerworld/commit/9556828)
- **Seed:** `80526`
- **Reference:** None; generated from the written creative brief.
- **Creative brief:** Subdued moonlit jungle background for a tiny corner
  desktop game; low-contrast navy and desaturated teal; layered distant canopy
  and tree trunks; sparse leaves and mist; open central airspace; coarse early-PC
  pixel clusters and a restrained palette; background scenery only.
- **Human-authored treatment:** Selected as a 320x144 background layer within
  the fixed 320x200 Canopy scene; removed the generated full moon with a
  neighboring sky patch; composited below the procedural crescent, vines,
  events, and atmosphere; applied the runtime navy tint and restrained opacity.
- **Visual proof:** [Native-size established Canopy fixture](images/canopy-established.png)
  showing the layer inside the shipped 320x200 acceptance surface.

### `canopy-wanderer-fall-sheet.png`

- **Path:** `Sources/TrailApp/Resources/canopy-wanderer-fall-sheet.png`
- **Provider/mode:** Retro Diffusion, advanced custom action, eight frames
- **Generated:** August 5, 2026
- **Terms reviewed:** August 5, 2026
- **Introduced:** Commit [`aaadd3b`](https://github.com/stoicpickle/cornerworld/commit/aaadd3b)
- **Seed:** `80528`
- **Reference:** Cornerworld's original procedural Wanderer sprite.
- **Creative brief:** A small orange jungle wanderer hanging from a brown rope
  hits a wall, compresses, recoils, loses grip, rotates, and slides down with a
  gentle comic squash-and-stretch treatment; no new objects or camera motion.
- **Human-authored treatment:** Selected and integrated into the authored wall
  impact sequence; frame timing, mirroring, caching, placement, fallback
  rendering, and the continuation into the edge slide are implemented in code.
- **Visual proof:** [Native-size wall-impact fixture](images/canopy-wall-impact.png)
  showing the sheet inside the shipped 320x200 acceptance surface.

### `canopy-jungle-midground.png`

- **Path:** `Sources/TrailApp/Resources/canopy-jungle-midground.png`
- **Provider/mode:** Retro Diffusion, RD Fast Retro, transparent background
- **Generated:** August 5, 2026
- **Terms reviewed:** August 5, 2026
- **Introduced:** Commit [`246a3a5`](https://github.com/stoicpickle/cornerworld/commit/246a3a5)
- **Seed:** `80529`
- **Reference:** None; generated from the written creative brief.
- **Creative brief:** A continuous low jungle silhouette with irregular bushes,
  fern clumps, a few slim side-weighted trunks, open central airspace, a gentle
  natural skyline, and a restrained deep-navy/desaturated-teal palette.
- **Human-authored treatment:** Selected to replace the old rectangular hedge;
  aligned and scaled for the fixed scene, then composited with authored canopy,
  vines, atmosphere, and runtime tint/opacity controls.
- **Visual proof:** [Native-size established Canopy fixture](images/canopy-established.png)
  showing the midground inside the shipped 320x200 acceptance surface.
