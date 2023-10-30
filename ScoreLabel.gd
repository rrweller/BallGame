extends Label

var current_score = 0


func _ready() -> void:
	SignalBus.ball_removed.connect(update_score)


func update_score(size: int):
	current_score += size * size
	text = "Score: %d" % current_score
	print("Score is now: ", current_score)
