extends CharacterBody2D


var speed = 150.00
var acceleration = 0.25

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")


func _physics_process(delta):
	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if direction:
		velocity = lerp(velocity, direction * speed, acceleration)
	else:
		velocity = lerp(velocity, Vector2.ZERO, acceleration)

	move_and_slide()
