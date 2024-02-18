extends Node2D

var pathDraw = []
var pathDraw1 = []
var pathPointDraw = []
var entryDraw = []
var connectorsDraw = []

var isAnimationSkipped = false
# Called when the node enters the scene tree for the first time.
func _ready():
	for i in 10:
		print(i)
		if !isAnimationSkipped:
			await get_tree().create_timer(0.0001).timeout
	isAnimationSkipped = false
#	var gatewayScene = preload("res://gateways/gateway1.tscn")
#	var gateway = gatewayScene.instantiate()
#	gateway.position = Vector2(600,600)
#	add_child(gateway)
#	var entrywaydist = 128
#	var gatewayTileMap = gateway.get_node("TileMap")
#	var size = Vector2(gateway.get_node("TileMap").get_used_rect().size)
#
#	size = size * 16#tile size
#	size.x += entrywaydist
#	size.y += entrywaydist
#
#	var gatewayPos = gateway.global_position + gatewayTileMap.map_to_local(gatewayTileMap.get_used_rect().position) - Vector2(8,8) - Vector2(entrywaydist/2, entrywaydist/2)
#
#	var gatewayCorners = [gatewayPos, Vector2(gatewayPos.x + size.x, gatewayPos.y), gatewayPos + size, Vector2(gatewayPos.x, gatewayPos.y+size.y)]
#	var gatewayRect = []
#	for i in gatewayCorners.size():
#		gatewayRect.append([gatewayCorners[i], gatewayCorners[(i+1) % gatewayCorners.size()]])
#
#	var entryPoints = []
#	var gatewayConnectors = []
#	for i in gateway.get_node("entry_points").get_children():
#		var entryLine = i.global_position + (Vector2.RIGHT.rotated(gateway.global_position.angle_to_point(i.global_position))*entrywaydist*1.75)
#		for j in gatewayRect:
#			var entryPoint = Geometry2D.segment_intersects_segment(gateway.global_position, entryLine, j[0], j[1])
#			if entryPoint:
#				entryPoints.append(round(entryPoint))
#				gatewayConnectors.append([gatewayPos, entryPoint])
#				connectorsDraw.append([i.global_position, entryPoint])
#
#	var gatewayPaths = []
#
#	var usedPoints = []
#	for i in gatewayCorners.size():
#		var start = gatewayCorners[i]
#		var end = gatewayCorners[(i+1) % gatewayCorners.size()]
#		while start != end:
#			pathPointDraw.append(start)
#			var is_intercepted = false
#			for j in entryPoints:
#				if !(j in usedPoints):
##					var line_vector = end - start
##					var point_vector = j - start
##					var dot_product = point_vector.dot(line_vector)
##					var line_length_squared = line_vector.length_squared()
##					var point_distance_squared = point_vector.length_squared()
##					if dot_product >= 0 and dot_product <= line_length_squared and point_distance_squared <= line_length_squared:
#					if start.distance_to(j)+end.distance_to(j) == start.distance_to(end):
#						gatewayPaths.append([start, j])
#						pathDraw1.append([start, j])
#						start = j
#						is_intercepted = true
#						usedPoints.append(j)
#						break
#
#			if !is_intercepted:
#				gatewayPaths.append([start, end])
#				pathDraw1.append([start, end])
#				start = end
#
#	print(gatewayPaths)
#	for i in gatewayRect:
#		pathDraw.append([i[0],i[1]])
#
#	entryDraw = entryPoints.duplicate()

func _draw():
	if pathDraw:
		for i in pathDraw:
			draw_polyline(i, Color.GREEN, 5, true)
	if entryDraw:
		for i in entryDraw:
			draw_circle(i, 5, Color.YELLOW)
	if pathDraw1:
		for i in pathDraw1:
			draw_polyline(i, Color.BLUE, 5, true)
	if pathPointDraw:
		for i in pathPointDraw:
			draw_circle(i, 5, Color.RED)
	if connectorsDraw:
		for i in connectorsDraw:
			draw_polyline(i, Color.BLUE_VIOLET, 5, true)
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Input.is_action_just_pressed("ui_select"):
		isAnimationSkipped = true
		print("skipped")
	pass
