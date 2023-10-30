extends RigidBody2D

var dir = "res://balls/"

var size
var max_size = 10
var ball_scenes = []
var ball_sizes = []
var BallScene

func _ready() -> void:
	size = self.get_meta("size")
	load_balls()
	body_entered.connect(handle_collision)

func handle_collision(body):
	if is_queued_for_deletion():
		return
	if not body.is_in_group('balls'):
		return
		
	var new_ball_position = (global_position + body.global_position) / 2
	SignalBus.collided.emit(new_ball_position.y)
	
	var thisball_radius = self.get_node("BallCollision").shape.get_radius()
	var otherball_radius = body.get_node("BallCollision").shape.get_radius()
	#print("COLLISION: Ball of size: ", thisball_radius, " collided with ball of size ", otherball_radius)
	
	if thisball_radius != otherball_radius:
		#print("Balls were not the same size, not merging")
		return
	
	body.queue_free()
	queue_free()
	
	if thisball_radius < ball_sizes[-1]["radius"]:
		var ball_index = -1
		for i in range(ball_sizes.size()):
			if is_equal_approx(ball_sizes[i]["radius"], thisball_radius):
				ball_index = i
				break
		if ball_index != -1 and ball_index < ball_sizes.size() - 1:
			var next_ball_scene = ball_sizes[ball_index + 1]["scene"]
			var next_ball = next_ball_scene.instantiate()
			next_ball.enable_physics()
			next_ball.global_position = new_ball_position
			next_ball.size = size + 1
			get_parent().add_child.call_deferred(next_ball)
			#print("\n=====MERGING=====\nCombining balls of radius ", thisball_radius, " and ", otherball_radius, " into ball of size: ", next_ball.size)

	SignalBus.ball_removed.emit(size)
	
func load_balls():
	var directory = DirAccess.open(dir)
	if directory:
		directory.list_dir_begin()
		var file_name = directory.get_next()
		while file_name != "":
			if file_name.ends_with(".tscn"):
				BallScene = load(dir + file_name)
				var ball = BallScene.instantiate()
				var ball_collision = ball.get_node("BallCollision")
				
				if ball_collision and ball_collision.has_method("get_shape"):
					var ball_radius = ball_collision.shape.get_radius()
					ball_sizes.append({"scene": BallScene, "radius": ball_radius})
					ball.queue_free()
			file_name = directory.get_next()
		directory.list_dir_end()
	
	#sort balls by size
	ball_sizes.sort_custom(Callable(self, "compare_radii"))

	for i in range(ball_sizes.size()):
		ball_scenes.append(ball_sizes[i]["scene"])		

func disable_physics():
	gravity_scale = 0
	collision_layer = 0
	collision_mask = 0

func enable_physics():
	gravity_scale = 0.5
	collision_layer = 1
	collision_mask = 1
	
func compare_radii(a,b):
	return a.radius < b.radius
