# Menu-bar acceptance matrix

This checklist keeps Cornerworld's smallest UI surface readable, private, and
operable as additional worlds are added. Component captures are process-owned:
they render only Cornerworld's status items and never capture unrelated desktop
icons.

## Automated component proof

Run:

```sh
swift run cornerworld --capture-menu-bar-fixtures .build/visual-proof/menu-bar
```

The command writes four Retina PNGs using the same icon and attributed-title
renderer as the live status items:

- `menu-bar-light-normal.png`
- `menu-bar-dark-normal.png`
- `menu-bar-light-warning.png`
- `menu-bar-dark-warning.png`

The byte-identical result below was verified on one machine and one macOS
environment. The capture path now requests an explicit 2x bitmap, but font and
AppKit rendering can still vary across operating-system versions.

## Acceptance results

| Surface | State | Acceptance condition | 2026-08-03 result |
| --- | --- | --- | --- |
| Overland | Light, healthy | Wagon, health light, mileage, separator, and `5/5` are distinct | Pass |
| Overland | Dark, healthy | Silhouette and secondary text retain contrast | Pass |
| Overland | Warning | Orange state light and `2/5` read as one warning without crowding | Pass |
| Farm | Light and dark | Barn/sprout remains distinct from the wagon; `W20 · $28` fits | Pass |
| Farm | Terminal pressure | Red accent and `W52 · $0` fit without clipping | Pass |
| Two worlds | Representative maximum widths | `1894 mi · 2/5` and `W52 · $0` do not overlap | Pass |
| Determinism | Repeat capture | A second run produces byte-identical PNGs | Pass |
| Farm live item | Accessibility | AX description is `Cornerworld Farm status`; title updates as `Wn · $cash` | Pass |
| Farm live menu | Structure | Show/Hide, New Farm, Worlds, Field Plan, Time, journal, and Quit are reachable | Pass |
| Farm live menu | World/time submenus | World launch choices and Normal/Slow/Paused are exposed | Pass |
| Farm live window | Show/hide | On-screen 320x200 window count transitions `1 → 0 → 1` | Pass |
| Concurrent launch | Runtime creation | Overland and Farm each report a 320x200 window and status item; two processes run | Pass |
| Appearance change while paused | Live system transition | Paused icon redraws immediately after macOS changes appearance | Not yet proved |
| Assistive technology | Full navigation | VoiceOver can announce and activate every submenu and state | Not yet proved |

## Evidence boundary

The light/dark PNGs prove the actual component renderer, spacing, colors, and
representative values in controlled appearances. The live smoke proves AppKit
creates the status item, exposes the expected menus through Accessibility, and
shows or hides the world window. It does not yet constitute a full VoiceOver
audit or prove a live appearance transition while Farm is paused.
