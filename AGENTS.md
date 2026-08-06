# Cornerworld agent notes

## Scope

- Preserve unrelated work and keep changes narrow.
- Keep simulation behavior deterministic for a fixed seed.
- Treat the 320x200 desktop presentation as the visual acceptance surface.

## Validation

Run the relevant focused tests while iterating, then use the full local gate
before shipping:

```sh
swift test
swift test -c release
swift build -c release
scripts/check-asset-provenance.sh
git diff --check
```

For visual work, capture the relevant native-size fixtures and inspect the
result. Available fixture commands are documented in `README.md`.

## Asset provenance gate

Before adding or changing a generated or third-party asset:

1. Review the provider's current terms rather than relying on a prior review.
2. Use only original, appropriately licensed, or public-domain source material.
3. Never commit credentials, private references, copied characters or marks, or
   material with unclear redistribution rights.
4. Update `docs/ASSET_PROVENANCE.md` with the provider, tool or model, date,
   terms-review date, prompt or brief, seed when available, references, and
   meaningful human-authored treatment.
5. Verify the asset at shipped size and include screenshot proof for the visual
   change.

Do not publish generated art as a standalone stock-asset pack unless the
provider's terms explicitly permit that use.
