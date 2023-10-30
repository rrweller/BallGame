extends Label

var current_score = 0


func _ready() -> void:
	SignalBus.ball_removed.connect(update_score)


func update_score(ballsize: int):
	current_score += ballsize * ballsize
	text = "Score: %d" % current_score
	print("Score is now: ", current_score)
