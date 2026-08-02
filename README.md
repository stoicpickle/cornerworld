# Cornerworld

Cornerworld is a small macOS home for ambient simulations: a persistent,
fixed-resolution world in the corner of the desktop, with compact controls in
the menu bar.

The first scenario is **Overland**, a slow westward journey rendered with a
restrained, hard-edged pixel-art presentation. The project may later host other
self-contained scenarios, such as a farm, without forcing them into the same
setting.

## Run the desktop app

```sh
swift run TrailApp
```

Runs can be reproduced or accelerated for development:

```sh
swift run TrailApp --seed 7 --fast
```

## Run the command-line simulation

```sh
swift run trail-cli --seed 7 --fast
```

## Validate

```sh
swift test
swift test -c release
swift build -c release
```

## Current structure

- `GameCore` owns deterministic simulation state and daily events.
- `TrailApp` owns the macOS status item and 320×200 SpriteKit presentation.
- `GameCLI` provides a terminal runner for deterministic simulation checks.

Cornerworld is currently a single-scenario application rather than a generalized
plugin framework. Shared scenario boundaries will be extracted when a second
scenario supplies a real design case.
