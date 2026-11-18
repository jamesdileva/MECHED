extends Node
## Balance sandbox (S24): loads the match-level tuning table at startup.
## Systems read Balance.config instead of hardcoded consts, so tuning changes
## land in data/balance/balance.tres without touching gameplay code.

const CONFIG_PATH := "res://data/balance/balance.tres"
const BalanceConfigScript := preload("res://scripts/core/balance_config.gd")

var config: Resource = BalanceConfigScript.new()


func _ready() -> void:
	if ResourceLoader.exists(CONFIG_PATH):
		var loaded: Resource = load(CONFIG_PATH)
		if loaded != null:
			config = loaded
