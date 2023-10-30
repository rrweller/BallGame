extends Node2D
@onready var spawn_marker: Marker2D = $SpawnMarker
@onready var next_ball_marker: Marker2D = $NextBallMarker
@onready var full_marker: Marker2D = $FullMarker
@onready var game_over: Label = $CanvasLayer/GameOver
@onready var box_left = $Box/Line2D/LeftWall/LeftWallCollision.shape.a.x
@onready var box_right = $Box/Line2D/RightWall/RightWallCollision.shape.a.x
@onready var ScoreLabel = $UserInterface/ScoreLabel

var dir = "res://balls/"

var ball_scenes = []
var ball_sizes = []
var current_ball
var next_ball
var is_game_over = false

var score = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	var directory = DirAccess.open(dir)
	if directory:
		directory.list_dir_begin()
		var file_name = directory.get_next()
		while file_name != "":
			if file_name.ends_with(".tscn"):
				var BallScene = load(dir + file_name)
				var ball = BallScene.instantiate()
				var ball_collision = ball.get_node("BallCollision")
				
				if ball_collision and ball_collision.has_method("get_shape"):
					var ball_radius = ball_collision.shape.get_radius()
					ball_sizes.append({"scene": BallScene, "radius": ball_radius})
					ball.queue_free()
			file_name = directory.get_next()
		directory.list_dir_end()
	
	#sort balls by size and keep 5 smallest
	ball_sizes.sort_custom(Callable(self, "compare_radii"))

	for i in range(min(ball_sizes.size(), 5)):
		ball_scenes.append(ball_sizes[i]["scene"])
		print("ball_scenes.size() is: ", ball_scenes.size())
	
	current_ball = create_ball(spawn_marker.global_position)
	next_ball = create_ball(next_ball_marker.global_position)
	SignalBus.collided.connect(detect_game_over)
	
	set_process_input(true)
	set_process(true)


func _physics_process(delta: float) -> void:
	if is_game_over:
		return
	if current_ball != null:
		if current_ball.gravity_scale == 0:
			var ball_x = get_ball_x(current_ball.get_node("BallCollision").shape.get_radius())
			current_ball.global_position.x = ball_x
			current_ball.global_position.y = spawn_marker.global_position.y
		if Input.is_action_just_pressed('drop'):
			drop_ball()

func create_ball(position):
	if ball_scenes.size():
		var BallScene = ball_scenes[randi() % ball_scenes.size()]
		var ball = BallScene.instantiate()
		ball.disable_physics()
		ball.global_position = position
		add_child(ball)
		return ball
	else:
		print("Error with ball_scenes.size()")

func get_ball_x(ball_radius):
	return clamp(
		get_global_mouse_position().x,
		box_left + ball_radius,
		box_right - ball_radius
	)

func drop_ball():
	current_ball.enable_physics()
	current_ball = null
	await get_tree().create_timer(0.5).timeout
	current_ball = next_ball
	next_ball = create_ball(next_ball_marker.global_position)

func detect_game_over(height: float):
	if height < full_marker.global_position.y:
		is_game_over = true
		game_over.visible = true
		await get_tree().create_timer(5).timeout
		get_tree().reload_current_scene()

#sorts balls by size
func compare_radii(a,b):
	return a.radius < b.radius
