# MECHED Playtest — S08–S18 Batch

Date of build: after S18 (AI Difficulty). Everything below is in the game unless marked **not built yet**.

## How to run

- Open the repo root in Godot and press F5, or run `godot --path .` from the repo folder — you land on the **main menu**.
- Flow: FIGHT → pick your mech (stats panel updates on focus) → set AI DIFFICULTY → CANYON → battle. **REMATCH** / **MAIN MENU** appear on the victory overlay.
- Controller: dpad/left stick walks the menus, A/Cross selects.
- Read the debug HUD (top-left) for dev detail — or press **F3** to hide it and play off the combat UI alone.

## Two config swaps before playing (both one-liners)

- **Change the AI's chassis**: `scenes/main/main.tscn` → DummyMech node → `definition = ExtResource(...)`.
- **Change your mech / AI difficulty**: in-game now — mech select screen. (Defaults: you = Standard, AI = Standard on Normal.)

## Not built yet — don't report as bugs

- Map select now lists three battlefields, but they share one tileset/visual style (S22 hazards and S45 visuals differentiate them further).
- No dedicated victory screen beyond the overlay ("VICTORY/DEFEAT" + rematch/menu).
- No ability cooldown display yet — current abilities are stance/energy-gated (the ANCHORED badge shows state); cooldowns arrive with S23 abilities.
- No sound, no tutorial.
- The AI always pilots a Standard chassis (AI chassis choice is a later concern).

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

### 11. Match flow (S20/S21) — the full loop, controller-navigable
- [ ] F5 boots to the **main menu**; FIGHT and QUIT both work (QUIT closes the game).
- [ ] **Mech select**: all four chassis listed; the stats/detail panel updates as you move focus; picking **Standard for both sides** works (the AI shows as "Standard 2" — no shared HP).
- [ ] **AI DIFFICULTY** button cycles Easy → Normal → Hard → Expert and sticks into the battle.
- [ ] **Map select lists three battlefields**: CANYON (the classic layout), **FLOATING ISLANDS** (islands over the void — falls respawn you, strong wind, mind the gaps), **INDUSTRIAL RUINS** (tower + steps, broken-floor pit, a 4m-high scaffold deck you can shell off its anchors).
- [ ] In battle: the chosen map is what loads — spawns differ per map (islands drop you onto slabs, ruins spread you wide).
- [ ] In battle: your chosen chassis is what you're driving (HUD name + bars match).
- [ ] **Victory/defeat**: end the AI (or die) → VICTORY/DEFEAT overlay with focus on REMATCH; REMATCH restarts with the same setup AND map; MAIN MENU returns to the menu.

## Notes

(write findings here)
