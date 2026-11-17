extends Resource
## A mech ability (S23, implementation-guide §8's common interface): data on
## the MechDefinition, mechanics interpreted by the mech via apply/hold.
##
## trigger: "toggle" (press flips a stance), "hold" (state persists while the
## input is held and resources last), "burst" (instant effect on press).
## input: the action name ("ability" = E/LT, "dash" = Shift/X).

@export var ability_name := "anchor"
@export var display_name := "Anchor"
@export_enum("ability", "dash") var input := "ability"
@export_enum("toggle", "hold", "burst") var trigger := "toggle"

## Flat movement-energy cost on trigger (0 = free).
@export var energy_cost := 0.0
## Per-second drain while holding (movement energy or fuel, per mechanic).
@export var energy_per_second := 0.0
@export var cooldown := 0.0
## Burst/hold duration in seconds (0 = instant or hold-driven).
@export var duration := 0.0
## Per-mechanic numeric: brace damage multiplier, climb speed, air-dash
## speed, hover fuel fraction — whatever the mechanic interprets.
@export var param := 1.0
