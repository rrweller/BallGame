extends RigidBody2D

# Signal to notify the main scene when a merge is happening
signal merge_with_other_ball

var is_merging = false

func _ready():
	connect("body_entered", Callable(self, "_on_Ball_body_entered"))

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _on_Ball_body_entered(body):
	if body is RigidBody2D and not is_merging:
		var ball1_radius = self.get_node("BallCollision").shape.get_radius()
		var ball2_radius = body.get_node("BallCollision").shape.get_radius()
		
		if ball1_radius == ball2_radius:
			print("Hit ball of equal radius, merging...")
			add_collision_exception_with(body)
			body.add_collision_exception_with(self)
			
			# Notify the main scene that a merge is happening
			emit_signal("merge_with_other_ball", self, body)
			
			# Apply a force to pull them together (you can adjust the force value)
			var force = 2.0
			apply_central_impulse((body.global_position - global_position) * force)
			body.apply_central_impulse((global_position - body.global_position) * force)
			is_merging = true
