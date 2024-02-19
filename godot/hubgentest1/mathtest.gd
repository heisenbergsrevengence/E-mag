extends Node2D

var pathDraw = []
var pathDraw1 = []
var pathPointDraw = []
var entryDraw = []
var connectorsDraw = []
var rectDraw3 = []
var isAnimationSkipped = false
# Called when the node enters the scene tree for the first time.
func _ready():
	var _gateway = load("res://gateways/gateway1.tscn").instantiate()
	_gateway.position = Vector2(300,300)
	add_child(_gateway)
	var tileMapCellSize = 16
	var entryWayDist = 128
	var gatewayOuterRectFactor = 1
	var gatewayInnerRectFactor = 1
	
	var gatewayTileMap: TileMap = _gateway.get_node("TileMap")
	var tileMapRectOffset: Vector2 = Vector2(tileMapCellSize, tileMapCellSize)
	var tileMapRectSize: Vector2 = Vector2(gatewayTileMap.get_used_rect().size) * tileMapCellSize 
	tileMapRectSize += tileMapRectOffset
	var tileMapRectPos: Vector2 = _gateway.global_position + gatewayTileMap.map_to_local(gatewayTileMap.get_used_rect().position)
	tileMapRectPos -= tileMapRectOffset/2
	
	var outerSize: Vector2 = tileMapRectSize + Vector2(entryWayDist, entryWayDist)
	var outerPosFactor: Vector2 = (outerSize * gatewayOuterRectFactor) - outerSize
	outerSize *= gatewayOuterRectFactor
	var outerPos =  tileMapRectPos - Vector2(entryWayDist, entryWayDist)/2 - outerPosFactor
	var outerCorners: Array =  	[outerPos, Vector2(outerPos.x + outerSize.x, outerPos.y), 
						 		outerPos + outerSize, Vector2(outerPos.x, outerPos.y + outerSize.y)]
	

	var innerSize: Vector2 = Vector2(	min(tileMapRectSize.x * gatewayInnerRectFactor, outerSize.x - tileMapRectOffset.x),
										min(tileMapRectSize.y * gatewayInnerRectFactor, outerSize.y - tileMapRectOffset.y))
	var innerPosFactor: Vector2 = innerSize - tileMapRectSize
	var innerPos: Vector2 = tileMapRectPos - innerPosFactor
	var innerCorners: Array =	[innerPos, Vector2(innerPos.x + innerSize.x, innerPos.y), 
								innerPos + innerSize, Vector2(innerPos.x, innerPos.y+innerSize.y)]
								
	var outerRect: Array = []
	var outerRectIncomplete: Array = []
	var innerRect: Array = []
	
	for c in outerCorners.size():
		outerRectIncomplete.append([outerCorners[c], outerCorners[(c+1) % outerCorners.size()]])
		
	var entryPoints: Array = []
	for e in _gateway.get_node("entry_points").get_children():
		var entryLine: Vector2 = e.global_position + (Vector2.RIGHT.rotated(_gateway.global_position.angle_to_point(e.global_position))*entryWayDist*4)

		for j in outerRectIncomplete:
			var entryPoint = Geometry2D.segment_intersects_segment(_gateway.global_position, entryLine, j[0], j[1])
			if entryPoint:
				entryPoints.append(round(entryPoint))

				
	var usedPoints = []
	for c in outerCorners.size():
		var start = outerCorners[c]
		var end = outerCorners[(c+1) % outerCorners.size()]
		entryPoints.sort_custom(func(a,b): return a.distance_to(start) < b.distance_to(start))
		while start != end:
			var is_intercepted = false
			for j in entryPoints:
				if !(j in usedPoints):
					if start.distance_to(j)+end.distance_to(j) == start.distance_to(end):
						print(j)
						outerRect.append([round(start), round(j)])
						usedPoints.append(j)
						start = j
						is_intercepted = true

			if !is_intercepted:
				outerRect.append([round(start), round(end)])
				start = end
	print(outerRect)
	print(entryPoints)
	print(usedPoints)
	rectDraw3.append(outerRect)
	queue_redraw()
	
	
	
#	var tileMapCellSize = Vector2(16,16)
#	var gatewayInnerRectFactor = 1
#	var gatewayOuterRectFactor = 1
#	var gatewayPos = Vector2(300,300)
#
#	var tileMapRectSize = Vector2(30,30) - 
#	tileMapRectSize *=
#	var tileMapRectPos = Vector2 (160,160)
#
#	var outerSize = Vector2(gatewayTileMap.get_used_rect().size) * tileMapCellSize + (Vector2(tileMapCellSize, tileMapCellSize)/2)
#	outerSize += Vector2(entryWayDist, entryWayDist)
#	outerSize *= gatewayOuterRectFactor
#
#	var gatewayPos = gateway.global_position + gatewayTileMap.map_to_local(gatewayTileMap.get_used_rect().position) - Vector2(tileMapCellSize/2,tileMapCellSize/2) - Vector2(entryWayDist/2, entryWayDist/2)
#
#
#	var innerSize: 
#	innerSize *= gatewayInnerRectFactor
#	var innerPos: Vector2 = _gateway.global_position + gatewayTileMap.map_to_local(gatewayTileMap.get_used_rect().position) - (Vector2(tileMapCellSize,tileMapCellSize)/2)
#
#	var gatewayCorners =  [gatewayPos, Vector2(gatewayPos.x + size.x, gatewayPos.y), gatewayPos + size, Vector2(gatewayPos.x, gatewayPos.y+size.y)]
#	var innerCorners = [innerPos, Vector2(innerPos.x + innerSize.x, innerPos.y), innerPos + innerSize, Vector2(innerPos.x, innerPos.y+innerSize.y)]
#	var gatewayRect = []
#	var innerRect = []
#	for c in gatewayCorners.size():
#		gatewayRect.append([gatewayCorners[c], gatewayCorners[(c+1) % gatewayCorners.size()]])
#	for c in innerCorners.size():
#		innerRect.append([innerCorners[c], innerCorners[(c+1) % innerCorners.size()]])
#	gatewayInnerRect[i] = innerRect


	
	
#	for i in 10:
#		print(i)
#		if !isAnimationSkipped:
#			await get_tree().create_timer(0.0001).timeout
#	isAnimationSkipped = false
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
	if rectDraw3:
		for i in rectDraw3:
			for j in i:
				draw_polyline(j, Color.YELLOW, 3, true)
				draw_circle(j[0], 10, Color.YELLOW)
#	draw_circle(gatewayPos, 5, Color.RED)
#	if pathDraw:
#		for i in pathDraw:
#			draw_polyline(i, Color.GREEN, 5, true)
#	if entryDraw:
#		for i in entryDraw:
#			draw_circle(i, 5, Color.YELLOW)
#	if pathDraw1:
#		for i in pathDraw1:
#			draw_polyline(i, Color.BLUE, 5, true)
#	if pathPointDraw:
#		for i in pathPointDraw:
#			draw_circle(i, 5, Color.RED)
#	if connectorsDraw:
#		for i in connectorsDraw:
#			draw_polyline(i, Color.BLUE_VIOLET, 5, true)
#

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Input.is_action_just_pressed("ui_select"):
		isAnimationSkipped = true
		print("skipped")
	pass
