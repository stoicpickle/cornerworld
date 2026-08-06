# Canopy scenario

Canopy is Cornerworld's third small world: a moonlit jungle slowly fills with
climbing vines. Rain accelerates the green, flowers open, birds stop by,
and an original pixel wanderer occasionally swings across the growth. Most
crossings are clean; every few passes end in a comic collision and slide down
one edge of the world.

## Why this world exists

The prompt came from a vague childhood memory of an early desktop animation.
Contemporary descriptions strongly resemble **Jungleman**, one of the modules
in Bit Jugglers' 1990s Macintosh utility *UnderWare*: the jungle grew across
the desktop and its swinging character could collide with desktop objects.
The identification is useful historical context, not source material for this
implementation.

Canopy is an independent reimagining. It uses original code, procedural pixel
art, a differently named and drawn character, and a locally synthesized whoop.
It includes no sampled audio, code, names, or artwork from *UnderWare*.

Sources used to identify the remembered program:

- [Mini'app'les newsletter, February 1994](https://mirrors.apple2.org.za/ftp.apple.asimov.net/documentation/magazines/miniapples/Mini%27App%27LesNewsletter1994-02.pdf)
- [The Mac Attic: UnderWare 2.0](https://www.themacattic.com/title/41319027cd3b40cb-underware-20)

## First playable loop

- Three vines begin at the foot of a fixed 320x200 jungle and grow vertically.
- Seeded growth can branch into as many as nine vines.
- Rain, blooms, and visiting birds create readable visual moments.
- Swings occur at irregular deterministic intervals; roughly every fourth
  swing ends at a screen edge and slides downward.
- Pruning cuts the oldest growth back without resetting the world.
- Gentle, active, wild, and paused clock modes control the ambient pace;
  Gentle is the default so the world develops without demanding attention.
- Sound is off by default and can be enabled from the Canopy menu.
- A muted nocturne palette, persistent mist, sparse fireflies, and twinkling
  stars keep the live world moving gently between growth events.
- The wanderer follows a curved, eased pendulum path instead of stepping
  through a sequence of straight lines.

The simulation and atmosphere layout are deterministic for a displayed seed.
Live atmosphere phases animate continuously, while fixture mode freezes their
seeded starting composition. Eleven fixtures cover
young, established, overgrown, weather, bloom, bird, mirrored swing and impact
poses, and pruning without recording the user's desktop.

## What Canopy teaches the host

Unlike Overland and Farm, Canopy has no campaign ending or economic result. Its
reward is accumulation and the occasional recurring gag. That tests whether
Cornerworld can host a low-intervention, open-ended screensaver-like world while
keeping its clock, controls, status item, and presentation independently owned.
