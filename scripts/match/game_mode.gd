extends Resource
## A game mode (S31): the rule the match is won by. Objectives (where) live on
## the map; the mode defines how they are scored and the win condition.

enum WinCondition { ELIMINATION, CONTROL, SIEGE, MOBILITY_RACE }

@export var mode_name := "Elimination"
@export var win_condition: WinCondition = WinCondition.ELIMINATION

## CONTROL: seconds a mech must accumulate inside a control zone.
@export var hold_time_to_win := 10.0

## SIEGE: the defender wins when this many turns pass without the target
## structure collapsing; the attacker wins by collapsing it.
@export var siege_turns := 10.0
