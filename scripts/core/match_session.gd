extends Node
## Cross-scene match configuration (S20 match flow): the menus write, the
## battle scene reads. Autoloaded as MatchSession.

const DEFAULT_CHASSIS := "res://data/mechs/standard_mech.tres"

var player_chassis := DEFAULT_CHASSIS
var ai_difficulty := "Normal"
var map_name := "standard"
