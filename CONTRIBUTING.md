# Contributing to Cornerworld

Thanks for helping make small ambient worlds better.

## Good first contributions

- Reproduce and fix a focused bug.
- Add a deterministic regression test for an uncovered event interaction.
- Improve accessibility, documentation, or setup instructions.
- Refine a pixel sprite without changing the 320×200 visual contract.
- Propose a small Overland event with clear mechanical and historical framing.

Please open an issue before beginning a large refactor, a new scenario, or a
change to the simulation's core balance.

## Development setup

Requirements are macOS 13+ and a Swift 6 toolchain.

```sh
git clone https://github.com/stoicpickle/cornerworld.git
cd cornerworld
swift test -c release
swift run cornerworld
```

## Pull requests

Keep pull requests narrow and explain:

1. What changed and why.
2. What player-visible behavior is different.
3. Which validation commands passed.
4. Which seed reproduces the behavior, when relevant.
5. Before-and-after screenshots for visual changes.

Run before submitting:

```sh
swift test
swift test -c release
swift build -c release
git diff --check
```

Do not commit `.build`, credentials, generated review output, or private source
material. New behavior should remain deterministic for a fixed seed.

## Scenario proposals

Cornerworld does not have a plugin API yet. A scenario proposal should first
describe:

- its slow-running daily or seasonal loop;
- the decisions available through a compact menu;
- how it remains legible in a tiny corner window;
- how failure, continuity, and replay work;
- what shared boundary it reveals that Overland alone cannot.

## Conduct

By participating, you agree to follow the project's
[Code of Conduct](CODE_OF_CONDUCT.md).
