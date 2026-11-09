# MECHED Playtest — S08–S18 Batch

Date of build: after S18 (AI Difficulty). Everything below is in the game unless marked **not built yet**.

## How to run

- Open the repo root in Godot and press F5, or run `godot --path .` from the repo folder.
- **You pilot the Bastion by default.** The AI pilots a Standard chassis.
- Read the debug HUD (top-left): match line (turn / active mech / energy / timer / wind), mech line (position / velocity / floor), combat line (both mechs' HP + fuel + armed weapon), input line.

## Two config swaps before playing (both one-liners)

- **Change your mech**: `scenes/main/main.tscn` → Mech node → `definition = ExtResource("7_strider")` (or `"9_wraith"` / `"10_bastion"`). F5 again.
- **Change AI difficulty**: `scripts/match/match_controller.gd` → `@export var ai_difficulty := "Hard"` → `"Easy"` / `"Normal"` / `"Expert"`.

## Not built yet — don't report as bugs

- No main menu / mech select / map select / rematch — that's S20 (Match Flow). Restart = F5.
- No dedicated victory screen beyond the HUD result line ("X wins the match" + freeze).
- No ability cooldown display yet — current abilities are stance/energy-gated (the ANCHORED badge shows state); cooldowns arrive with S23 abilities.
- No sound, no tutorial.
- AI difficulty is config-only right now (menu knob comes with S20+).

## Checklist

### 1. Match basics
- [ ] Turns alternate you ↔ AI; energy refills each turn; timer counts down and re-rolls **wind** (arrow + strength in the match line).

### 2. Movement per chassis (swap the definition line to compare)
- [ ] Bastion: heavy, slow (5 m/s), jump feels weak; **E anchors** — blast-immune but immobile; toggles off with E or turn end.
- [ ] Strider: fast (11 m/s), light — knockback shoves it far; **Shift/X dash** (25 energy).
- [ ] Wraith: **hold Space in the air to fly** — fuel drains, refills next turn; fire mid-flight.

### 3. Weapons (Tab / LB / RB cycles — HUD badge shows the armed weapon)
- [ ] Rocket: baseline arc.
- [ ] Grenade: slower, **bounces twice** off terrain, digs bigger craters.
- [ ] Energy Shot: fast, flat (low gravity), small blast, barely scratches terrain.
- [ ] Transformations: Bastion fires **Siege Rocket** (slow, heavy, huge crater), Strider **Split Rocket** (3 shells), Wraith **Guided Rocket** (curves toward you) — check the HUD name changes.

### 4. Terrain (S13)
- [ ] Tiered hill west: ramps are **walkable** (45° slopes); high ground changes your angles.
- [ ] **Tunnel** through the hill: walk through it; shoot its roof to collapse passages.
- [ ] **Cover wall** mid-field: blocks low shots.
- [ ] **Ravine + bridge** (east): shell the **pillar under the bridge** → the deck drops; crossing then needs the jetpack or a leap.
- [ ] **Plateau + cliff** over the ravine: knock enemies off the edge.

### 5. Knockback & explosions
- [ ] Blasts push mechs (away from the blast; airborne = full force; grounded = half).
- [ ] Blast near an edge = shove-off kills; anchored Bastion ignores it.

### 6. Wind (S14)
- [ ] Fire into a headwind → falls short; tailwind → sails long; wind re-rolls every turn.

### 7. AI (S15–S18) — the main event
- [ ] **S15**: AI walks to range, aims, fires, damages you, and can finish the match (0 HP → result line + freeze).
- [ ] **S16**: it *repositions* — walks to the hill / cover instead of firing from the flats, avoids standing at the ravine edge.
- [ ] **S17**: stand on the bridge — it **shells the pillar** instead of you; stand at the plateau edge — it blasts the ground behind you to shove you off.
- [ ] **S18**: try Easy → Normal → Hard → Expert (config swap). Expect: Easy is sloppy and static; Normal positions and anchors; Hard starts targeting the bridge/edges; Expert rarely misses and repositions finely.

### 8. Match end
- [ ] Reduce a mech to 0 HP → HUD shows "X wins the match" and the match freezes.

### 9. Performance
- [ ] FPS in the debug HUD — report the number if it dips below 60 (esp. during/after explosions).

### 10. Combat UI (S19) — the main HUD
Press **F3** first to hide the debug HUD — then, per the roadmap verification, everything below should be readable from the combat UI alone:
- [ ] Turn banner (top-center): turn number + YOUR TURN / ENEMY TURN / RESOLVING; timer bar drains under it.
- [ ] Your panel (bottom-left): name + HP numbers and bar; **energy bar** drains as you walk/jump/dash and refills; **fuel bar** appears for the Wraith and drains in flight; armed weapon badge updates on Tab (incl. transformation names like [Siege Rocket]).
- [ ] **Aim readout**: angle + power % while holding fire.
- [ ] **ANCHORED badge** appears with E (Bastion) and vanishes on toggle/turn end.
- [ ] Wind indicator (top-right): arrow + strength, changes each turn.
- [ ] Enemy panel (top-right): name + HP bar tracks damage you deal.
- [ ] Match end: the banner shows the result line.
- [ ] F3 brings the debug HUD back (dev tool).

## Notes

(write findings here)
