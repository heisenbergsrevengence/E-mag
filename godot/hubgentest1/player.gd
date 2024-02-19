extends CharacterBody2D

var speed = 150.00
var acceleration = 0.25
var sprites = [preload("res://testplayer.png"), preload("res://testplayer2.png")]


func _process(delta):
	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if direction:
		velocity = lerp(velocity, direction * speed, acceleration)
	else:
		velocity = lerp(velocity, Vector2.ZERO, acceleration)
	
	if Input.is_action_pressed("ui_select"):
		$Sprite2D.texture = sprites[1]
	else:
		$Sprite2D.texture = sprites[0]
	
	move_and_slide()
