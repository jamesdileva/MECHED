extends RigidBody3D
## An explosive barrel prop (S22): sits on the battlefield, detonates when a
## shell blast reaches it (see MatchController._resolve_impact), chains into
## other barrels, and is gone afterwards. The blast itself (damage, knockback,
## FX) is applied by the match layer — this node is payload, not rules.

## Blast stats, pushed in at spawn from the map's hazard data.
var explosion_radius := 3.0
var damage_max := 30.0
var knockback_force := 12.0

var detonated := false
