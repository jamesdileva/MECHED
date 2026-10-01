extends Node3D
## Brief expanding blast visual; self-expiring. Gameplay damage is applied by
## the match layer — this node is pure presentation.

@export var blast_radius := 2.5
@export var duration := 0.4


func _ready() -> void:
	var blast: MeshInstance3D = $Blast
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.62, 0.2, 0.85)
	blast.material_override = mat
	blast.scale = Vector3.ONE * 0.25
	# Blast mesh is a unit-diameter sphere, so the final scale is 2 * radius.
	var tween := create_tween()
	tween.tween_property(blast, "scale", Vector3.ONE * blast_radius * 2.0, duration * 0.6)
	tween.tween_property(mat, "albedo_color:a", 0.0, duration * 0.4)
	tween.tween_callback(queue_free)
