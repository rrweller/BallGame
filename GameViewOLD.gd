extends Node2D

var ball_scenes = []
var ball_sizes = []
var is_dragging = false
var spawning_ball = null

var box_left
var box_right
var max_spawn_y

var spawn_delay = 1
var spawn_timer = Timer.new()

var ScoreLabel
var score = 0

var balls_in_bar = {}
var merging_balls = {}
var end_game = false

# Called when the node enters the scene tree for the first time.
func _ready():
	box_left = $Box/Line2D/LeftWall/LeftWallCollision.shape.a.x
	box_right = $Box/Line2D/RightWall/RightWallCollision.shape.a.x
	max_spawn_y = $Box/Line2D/LeftWall/LeftWallCollision.shape.a.y
	ScoreLabel = $UserInterface/ScoreLabel
	$Box/TopBar.connect("body_entered", Callable(self, "_on_TopBar_body_entered"))
	$Box/TopBar.connect("body_exited", Callable(self, "_on_TopBar_body_exited"))
	
	#initialize spawn timer
	add_child(spawn_timer)
	spawn_timer.wait_time = spawn_delay
	spawn_timer.connect("timeout", Callable(self, "_on_spawn_timer_timeout"))
	
	var directory = DirAccess.open("res://balls/")
	if directory:
		directory.list_dir_begin()
		var file_name = directory.get_next()
		while file_name != "":
			if file_name.ends_with(".tscn"):
				var BallScene = load("res://balls/" + file_name)
				var ball = BallScene.instantiate()
				var ball_collision = ball.get_node("BallCollision")
				
				if ball_collision and ball_collision.has_method("get_shape"):
					var ball_radius = ball_collision.shape.get_radius()
					ball_sizes.append({"scene": BallScene, "radius": ball_radius})
					ball.queue_free()
			file_name = directory.get_next()
		directory.list_dir_end()
	
	#sort balls by size and keep 5 smallest
	print("Ball sizes before: ", ball_sizes)
	ball_sizes.sort_custom(Callable(self, "compare_radii"))
	print("Ball sizes after: ", ball_sizes)
	for i in range(min(ball_sizes.size(), 5)):
		ball_scenes.append(ball_sizes[i]["scene"])
	
	spawn_timer.start()
	set_process_input(true)
	set_process(true)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _input(event):
	if event is InputEventMouseButton:
		if event.pressed:
			is_dragging = true
			if spawning_ball:
				set_ball_pos()
			
		elif not event.pressed and spawning_ball:
			is_dragging = false
			if spawning_ball is RigidBody2D:
				set_ball_pos()
				spawning_ball.freeze = false
			#Retrieve ball points and append to score
			var point = spawning_ball.get_meta("point")
			print("Balls points are: ", point)
			if point:
				ScoreLabel.addscore(point)
			spawn_timer.start()
			spawning_ball = null

	elif is_dragging and event is InputEventMouseMotion and spawning_ball:
		set_ball_pos()

func _process(delta):
	var keys_to_remove = []
	for ball1 in merging_balls.keys():
		print("in process")
		var ball2 = merging_balls[ball1]
		
		if ball1.is_queued_for_deletion() or ball2.is_queued_for_deletion():
			keys_to_remove.append(ball1)
			continue
			
		var distance = ball1.global_position.distance_to(ball2.global_position)
		var ball1_radius = ball1.get_node("BallCollision").shape.get_radius()
		
		# Check if centers are within a certain proportion (e.g., 0.5) of their original radii
		if distance <= ball1_radius * 0.9:
			replace_with_bigger(ball1, ball2)
			merging_balls.erase(ball1)
			
	for key in keys_to_remove:
		merging_balls.erase(key)
		
#sorts balls by size
func compare_radii(a,b):
	return a.radius < b.radius
	
#checks if mouse is inside box
func is_in_box(point, ball_radius):
	return point.x > (box_left) and point.x < (box_right)

func _on_Ball_merge_with_other_ball(emitting_ball, other_ball):
	if emitting_ball.is_in_group("Balls") and other_ball.is_in_group("Balls"):
		merging_balls[emitting_ball] = other_ball

func set_ball_pos():
	var mouse_position_in_world = get_global_mouse_position()
	var ball_radius = spawning_ball.get_node("BallCollision").shape.get_radius()
	
	if mouse_position_in_world.x <= box_left + ball_radius:
		mouse_position_in_world.x = box_left + ball_radius
	elif mouse_position_in_world.x >= box_right - ball_radius:
		mouse_position_in_world.x = box_right - ball_radius
	
	spawning_ball.global_position.x = mouse_position_in_world.x
	
#restricts placement of balls outside bounds
func adjust_ball_position(position, ball_radius):
	if position.x <= box_left + ball_radius:
		position.x = box_left + ball_radius
	elif position.x >= box_right - ball_radius:
		position.x = box_right - ball_radius
	return position
	
func spawn_ball():
	var BallScene = ball_scenes[randi() % ball_scenes.size()]
	spawning_ball = BallScene.instantiate()
	spawning_ball.connect("merge_with_other_ball", Callable(self, "_on_Ball_merge_with_other_ball"))
	
	#Add the ball to the balls group
	spawning_ball.add_to_group("Balls")
	
	if spawning_ball is RigidBody2D:
		spawning_ball.freeze = true
	
	add_child(spawning_ball)
	spawning_ball.global_position = Vector2((box_left + box_right) / 2, max_spawn_y)
	
func replace_with_bigger(ball1, ball2):
	print("Merging the two balls...")
	var next_size_index = -1
	var ball1_radius = ball1.get_node("BallCollision").shape.get_radius()
	
	# Find the index of the current ball size in ball_scenes
	for i in range(len(ball_sizes)):
		if ball_sizes[i]["radius"] > ball1_radius:
			next_size_index = i
			break
	
	# Check if there is a next size up
	if next_size_index >= 0:
		var BallScene = ball_sizes[next_size_index]["scene"]
		# Delete the original balls
		ball1.queue_free()
		ball2.queue_free()
		var new_ball = BallScene.instantiate()
		add_child(new_ball)
		
		# Position the new ball at the midpoint between the two merging balls
		new_ball.global_position = (ball1.global_position + ball2.global_position) / 2.0
		
		# Connect the new ball to the merge signal
		new_ball.connect("merge_with_other_ball", Callable(self, "_on_Ball_merge_with_other_ball"))
		print("Merging balls into size of: ", new_ball)
	else:
		print("Next size not found for ", ball1.name)
	
func _on_spawn_timer_timeout():
	if not spawning_ball:
		spawn_ball()
		spawn_timer.start()

func _on_TopBar_body_entered(body):
	if body is RigidBody2D and not end_game:
		#print("Body entered bar")
		var timer = Timer.new()
		timer.wait_time = 2
		timer.one_shot = true
		timer.set_meta("body",body)
		#print("Starting timer for body:", body)
		timer.connect("timeout", Callable(self, "_end_game"))
		add_child(timer)
		balls_in_bar[body] = timer
		timer.start()

func _on_TopBar_body_exited(body):
	#print("Body left bar")
	if body in balls_in_bar:
		var timer = balls_in_bar[body]
		timer.queue_free()
		balls_in_bar.erase(body)
		
func _end_game():
	print("Timer timed out!")
