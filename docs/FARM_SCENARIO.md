# Farm scenario proposal

Farm is Cornerworld's second-world test: a small place that changes with the
seasons, rewards occasional decisions, and continues living when left alone.
It should prove which parts of Cornerworld are shared product behavior without
turning the repository into a general-purpose game engine first.

## Design promise

One deterministic farm year should tell a legible story at a glance. The field
is planted in spring, reacts visibly to weather and stewardship through summer,
is harvested in autumn, and rests under winter snow. A choice made early in the
year should have a consequence the player can see months later.

Farm is not an idle-game economy, a farming RPG, or Overland with different
nouns. It has a fixed home, a repeating seasonal clock, gradual improvement and
decline, and no constant clicking.

## First playable year

The first slice uses one field and one weekly simulation tick. Thirteen weeks
make a season and four seasons make a year. Normal play should take roughly
five minutes per year, with a fast mode for development and deterministic
captures.

At the start of spring, choose one field plan:

- **Wheat** — strongest cash harvest, but draws down soil.
- **Beans** — smaller harvest, but restores some soil.
- **Fallow** — no harvest and a real debt risk, but meaningfully restores soil.

The world then advances mostly on its own. Weekly weather changes moisture and
growth. A few authored events create texture without interrupting every tick:
gentle rain, a dry spell, late frost, weeds, wind damage, a useful repair day,
and wildlife at the field edge.

The first-year state stays deliberately small:

- field plan and crop stage;
- soil quality and moisture;
- stored food and cash;
- farmhouse or barn condition;
- season, week, and year.

Harvest yield should be explainable from those values. Winter consumes stores,
then year-end taxes and provisions test whether the farm enters the next spring
stable, strained, or in debt.

## Corner-scale visual language

The scene remains a hard-edged 320x200 pixel world. It uses a fixed farm view
rather than horizontal travel:

- farmhouse on the left and barn on the right;
- one broad field occupying the middle ground;
- a fence, tree, and distant horizon for seasonal silhouettes;
- crop rows that visibly move from bare soil to shoots, mature plants, stubble,
  and snow cover;
- short event animations inside the world area, with the existing message strip
  and compact status panel remaining readable.

Spring begins dark and wet, summer becomes green and full, autumn shifts toward
orange and gold, and winter reduces the scene to black, white, and blue. Weather
and crop stages should change the actual scene rather than appearing only as
status text.

## Controls

The first playable version adds a world choice at launch and in the status
menu. Farm needs only three direct controls:

- start a new farm with a selected field plan;
- choose normal, slow, or paused time;
- start a new deterministic farm from a seed.

Additional animals, buildings, markets, and field plots come later. They should
not enter the first slice unless the one-field year is already interesting.

## Implementation boundary

Farm should initially sit beside Overland:

- `FarmCore` owns its deterministic weekly simulation and tests;
- `FarmScene` owns its fixed-resolution SpriteKit presentation;
- the desktop host selects which world to run and supplies the appropriate
  controls;
- Overland's simulation types remain unchanged.

Do not extract a shared scenario protocol before both worlds run. Once Farm is
playable, compare the two implementations and extract only the lifecycle,
snapshot, menu, fixed-resolution, persistence, and ending behavior that is
actually duplicated.

## Delivery slices

1. **Deterministic year — implemented:** implement the weekly clock, field
   plans, weather, growth, harvest, winter costs, event log, seeded tests, and a
   terminal proof.
2. **Visible farm — implemented:** add the fixed farm scene with crop and
   seasonal stages, plus deterministic screenshot fixtures.
3. **World selection — implemented:** launch either Overland or Farm, open
   independent worlds concurrently, and expose only each world's controls.
4. **First balancing pass — implemented:** run seeded years, tune explainable
   outcomes, and prove stable, strained, and debt years are all reachable.
5. **Shared-host extraction:** compare both working worlds and refactor only
   proven duplication.

## Acceptance criteria

The first playable farm is successful when:

- the same seed and field plan produce the same year and event log;
- wheat, beans, and fallow lead to materially different harvest and soil states;
- the crop and season are recognizable without reading the status panel;
- the player can explain why the harvest was strong or weak;
- a full year completes without intervention, while one spring decision still
  matters at harvest;
- Overland behavior and deterministic tests remain unchanged.
