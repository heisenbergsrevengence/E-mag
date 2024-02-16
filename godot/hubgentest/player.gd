extends CharacterBody2D

var speed = 150.00
var acceleration = 0.25

func _process(delta):
	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if direction:
		velocity = lerp(velocity, direction * speed, acceleration)
	else:
		velocity = lerp(velocity, Vector2.ZERO, acceleration)

	move_and_slide()
