extends RefCounted
## Base class for discrete match actions (implementation-guide §5).
##
## Actions are plain data: anything that can generate them (the player input
## shim today, the AI planner in S15+, replay playback in S37+) submits them
## through TurnManager.submit_action(). Continuous movement is NOT an action —
## it flows through TurnManager.apply_movement() as per-tick intent, which
## keeps replay history compact; burst movement (dash, S08) may revisit this.

var actor_index := -1
