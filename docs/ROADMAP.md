# Cornerworld roadmap

Cornerworld 1.0 proves the form: a small autonomous world, a compact menu-bar
surface, deterministic continuity, and occasional meaningful intervention.

## Near term

- Package Cornerworld as a signed and notarized macOS `.app`.
- Add persistence so a world can continue across launches.
- Improve accessibility and keyboard operation of menu controls.
- Expand Overland's event variety without increasing interruption frequency.
- Add deterministic visual fixtures for ordinary, landmark, weather, and ending
  states.

## The multi-world test

Farm and Canopy are now working second and third scenarios. Farm changes the
time scale, resources, visual grammar, and meaning of continuity; Canopy adds
an open-ended ambient animation without an economy or terminal outcome. Their
design boundaries are captured in the [Farm scenario proposal](FARM_SCENARIO.md)
and [Canopy scenario note](CANOPY_SCENARIO.md).

With three concrete worlds to compare, shared abstractions should be extracted
only where all three demonstrate the same responsibility, including:

- simulation clocks and snapshots;
- compact controls and journal entries;
- fixed-resolution rendering;
- lifecycle, persistence, and endings.

The goal is a small, understandable host for authored worlds—not a general game
engine or a speculative plugin framework.

Farm and Canopy should remain concrete host clients while persistence and
lifecycle needs become clearer.
