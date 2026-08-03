# Cornerworld

**Small worlds that live quietly at the edge of your desktop.**

Cornerworld is an open-source macOS experiment in ambient simulation: a
persistent 320×200 world sits in the corner of the screen, advances at its own
pace, and exposes just enough control through the menu bar. It is designed to
feel present without asking to become the center of attention.

![The Overland scenario running in the desktop corner](docs/images/overland-window.png)

Version 1.1 ships with **Overland**, a deterministic westward journey about
distance, weather, supplies, health, and attrition. Overland is the first world,
not the limit of the idea. A lighthouse, railway, expedition, or other
slow-running scenario could eventually join it in the same desktop form.

The current development build also includes **Farm**, Cornerworld's first
experiment with a second world: a deterministic year of planting, weather,
harvest, and winter pressure rendered as a fixed seasonal homestead.

| Farm in summer | Farm in winter |
| --- | --- |
| ![A mature wheat field outside the Cornerworld farmhouse and barn](docs/images/farm-summer-mature.png) | ![The Cornerworld farm resting beneath winter snow](docs/images/farm-winter-snow.png) |

Farm's weekly story now appears in the field itself, including wildlife, crop
trouble, neighbor visits, repair work, harvest, and the year-end result.

| Deer at the field edge | A winter repair day |
| --- | --- |
| ![Deer watching from the edge of the Farm field](docs/images/farm-event-deer.png) | ![A worker repairing the Farm barn during winter](docs/images/farm-event-repair-day.png) |

Overland now gives important events their own deterministic pixel-art
vignettes instead of reporting every encounter through text alone.

| Wolves harry the herd | A rattler strikes |
| --- | --- |
| ![Wolves approaching the Overland wagon and ox](docs/images/overland-wolves.png) | ![A rattlesnake striking beside the Overland wagon](docs/images/overland-snakebite.png) |

## What is here in 1.1

- A borderless SpriteKit world pinned to a macOS desktop corner.
- A compact menu-bar readout for mileage and surviving travelers.
- Deterministic journeys that can be reproduced from a seed.
- Persistent weather fronts, terrain, landmarks, illness, trade, repairs, and
  supply opportunities.
- Deterministic pixel-art vignettes for crossings, hunts, breakdowns, encounters,
  weather, and quiet trail moments.
- Meaningful pace and ration choices.
- A trail journal and end-of-journey memorial summary.
- A terminal runner for development and simulation checks.

## Requirements

- macOS 13 or later
- Swift 6 toolchain (Xcode 16 or a compatible Swift installation)

Cornerworld 1.1 is a source-first release. It does not yet include a signed or
notarized `.app` bundle, an installer, or launch-at-login support.

## Run the desktop world

```sh
git clone https://github.com/stoicpickle/cornerworld.git
cd cornerworld
swift run cornerworld
```

The app appears in the upper-left corner and adds a wagon readout to the menu
bar. Use that menu to show or hide the world, start a new journey, change pace
or rations, and read recent journal entries.

For a reproducible or accelerated development run:

```sh
swift run cornerworld --seed 7
swift run cornerworld --seed 7 --fast
```

To open Farm instead, choose it at launch or start it while Overland continues
running from the **Worlds** submenu in either menu-bar item:

```sh
swift run cornerworld --world farm --seed 1848 --plan wheat
swift run cornerworld --world farm --seed 1848 --plan beans --fast
```

Each open world has its own corner window, simulation clock, and menu-bar item.
Opening another world from that submenu hides the current corner window to
prevent overlap; its clock keeps running, and its menu-bar item can show it
again. This supports multiple concurrent worlds without claiming a plugin
architecture or shared persistence layer yet.

## Choices

### Pace

Pace changes the terrain's base daily mileage:

| Setting | Daily adjustment |
| --- | ---: |
| Steady | +3 miles |
| Moderate | Standard terrain rate |
| Slow | −2 miles |
| Very slow | −6 miles |

### Rations

Rations trade food reserves for daily health:

| Setting | Food per traveler | Daily health |
| --- | ---: | ---: |
| Filling | 3 lbs | +2 |
| Meager | 2 lbs | 0 |
| Bare bones | 1 lb | −2 |

Running out of food overrides the ration setting with a larger health penalty.
Illness and harsh weather stack with these effects.

## Run the terminal simulation

```sh
swift run cornerworld-cli --seed 7
swift run cornerworld-cli --help
```

Farm also has a deterministic terminal proof:

```sh
swift run cornerworld-farm-cli --seed 1848 --plan wheat
swift run cornerworld-farm-cli --seed 1848 --plan beans --fast
swift run cornerworld-farm-cli --seed 1848 --plan fallow --fast
```

## Validate a checkout

```sh
swift test
swift test -c release
swift build -c release
```

Farm's process-owned seasonal and event visual proof does not require Screen
Recording permission:

```sh
swift run cornerworld --capture-farm-fixtures .build/visual-proof/farm
swift run cornerworld --capture-menu-bar-fixtures .build/visual-proof/menu-bar
```

The current menu-bar acceptance results and remaining accessibility checks are
recorded in [docs/TOP_BAR_ACCEPTANCE.md](docs/TOP_BAR_ACCEPTANCE.md).

## Project structure

- `GameCore` owns deterministic simulation state, daily events, and journey
  outcomes.
- `FarmCore` owns the Farm world's deterministic weekly year, field plans,
  harvest accounting, and winter outcome.
- `DesktopHostCore` owns testable desktop launch parsing and validation.
- `TrailApp` owns the macOS status items, world launcher, and fixed-resolution
  SpriteKit scenes.
- `GameCLI` provides a terminal presentation for seeded runs.
- `FarmCLI` provides a quick terminal proof for seeded Farm years.

Cornerworld now keeps two authored scenarios beside one another, but deliberately
does not extract a shared scenario interface yet. The project does not claim to
have a plugin system today.
See [the roadmap](docs/ROADMAP.md) for the intended direction.

## Contributing

Ideas, bug reports, documentation fixes, accessibility improvements, new event
tests, and carefully scoped pull requests are welcome. Please read
[CONTRIBUTING.md](CONTRIBUTING.md) before starting a larger change.

For a new scenario, begin with a proposal describing its slow-running loop,
corner-scale visual language, meaningful choices, and what it would teach us
about the future shared scenario boundary.

## Independence and historical scope

Cornerworld is an independent project and is not affiliated with or endorsed by
the creators or publishers of *The Oregon Trail*. It contains no copied game
code or original game assets. Overland is a compact fictional simulation, not a
comprehensive representation of westward migration or Indigenous history.
See the [historical-content note](docs/HISTORICAL_NOTE.md) for sources, framing,
and how to suggest corrections.

## License

Cornerworld is available under the [MIT License](LICENSE).
