extends "res://scripts/match/match_action.gd"
## Fires the active mech's weapon. `power` is the charge amount at release
## (0–1) and scales projectile speed through the ballistics module.
## Submission is only valid during the move phase; acceptance puts the turn
## into projectile resolution.

var power := 0.0
