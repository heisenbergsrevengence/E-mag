extends Node2D

@onready var tileMap = $TileMap

var gatewayScenes = [preload("res://gateways/gateway0.tscn"), preload("res://gateways/gateway1.tscn")]
var playerScene = preload("res://player.tscn")

var floorTile = Vector2i(0,0)
var blackTile = Vector2i(0,0)
var wallTile = Vector2i(1,0)

var neighFour = [Vector2i(1,0), Vector2i(0,1), Vector2i(-1,0), Vector2i(0,-1)]
var neighEight = [Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1), 
				Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)]

@export var gatewayAmount = 15
@export var gridScaleFactor = 0.55
@export var gridCellSize = 256-32
@export var extraPathwayFactor = 0.1

#these two variables affect the avoidance process... changing them can cause the map to load
#very fast, but have unreachable areas, or take a very long/infinite time to load
#
#The avoidance process can be monitored in the debugging output, if it stops printing out
#"avoidance running" for a long time, it's probably stuck and won't recover
@export var entryWayDist = 128	#default 80
@export var pathwayAvoidanceDist = 0	#default 11

var is_mapPreview = true

var gateways = []

var pathDraw = []
var pathDraw1 = []
var pathDraw2 = []
var pointDraw = []
var connectorsDraw = []

func _ready():
	var gatewayCoords = []
	var connections = []
	var pathWays = []
	var pathWayCoords = []
	var gatewayExtensions = []
	var gatewayPaths = {}
	var gatewayInnerRect = {}
	var gatewayConnectors = []
	
	gateways = generate_gateways(gatewayAmount)
	
	for i in gateways:
		gatewayCoords.append(tileMap.local_to_map(i.position))
		
		##NEW CODE HERE##
		var gateway = i
		var gatewayTileMap = gateway.get_node("TileMap")
		var size = Vector2(gatewayTileMap.get_used_rect().size)
		size = size * 16 #tile size
		var innerSize = Vector2(gatewayTileMap.get_used_rect().size) * 16
		size.x += entryWayDist
		size.y += entryWayDist
		var gatewayPos = gateway.global_position + gatewayTileMap.map_to_local(gatewayTileMap.get_used_rect().position) - Vector2(8,8) - Vector2(entryWayDist/2, entryWayDist/2)
		var innerPos = gateway.global_position + gatewayTileMap.map_to_local(gatewayTileMap.get_used_rect().position) - Vector2(8,8)
		
		var gatewayCorners =  [gatewayPos, Vector2(gatewayPos.x + size.x, gatewayPos.y), gatewayPos + size, Vector2(gatewayPos.x, gatewayPos.y+size.y)]
		var innerCorners = [innerPos, Vector2(innerPos.x + innerSize.x, innerPos.y), innerPos + innerSize, Vector2(innerPos.x, innerPos.y+innerSize.y)]
		var gatewayRect = []
		var innerRect = []
		for c in gatewayCorners.size():
			gatewayRect.append([gatewayCorners[c], gatewayCorners[(c+1) % gatewayCorners.size()]])
			pathDraw2.append([gatewayCorners[c], gatewayCorners[(c+1) % gatewayCorners.size()]])
		for c in innerCorners.size():
			innerRect.append([innerCorners[c], innerCorners[(c+1) % innerCorners.size()]])
		gatewayInnerRect[i] = innerRect
		var entryPoints = []
		for e in gateway.get_node("entry_points").get_children():
			var entryLine = e.global_position + (Vector2.RIGHT.rotated(gateway.global_position.angle_to_point(e.global_position))*entryWayDist*1.75)
			for j in gatewayRect:
				var entryPoint = Geometry2D.segment_intersects_segment(gateway.global_position, entryLine, j[0], j[1])
				if entryPoint:
					entryPoints.append(round(entryPoint))
					gatewayConnectors.append([e.global_position, entryPoint])
		var paths = []
		var usedPoints = []
		for c in gatewayCorners.size():
			var start = gatewayCorners[c]
			var end = gatewayCorners[(c+1) % gatewayCorners.size()]
			while start != end:
				var is_intercepted = false
				for j in entryPoints:
					if !(j in usedPoints):
						if start.distance_to(j)+end.distance_to(j) == start.distance_to(end):
							paths.append([start, j])
							usedPoints.append(j)
							start = j
							is_intercepted = true
							
				if !is_intercepted:
					paths.append([start, end])
					start = end
		gatewayPaths[i] = paths
	##NEW CODE END##
	
	for i in gateways:
		pathDraw.append(gatewayPaths[i])
	for i in gatewayConnectors:
		connectorsDraw.append(i)
	
	var mstEdges = find_mst(gatewayCoords.duplicate())
	for i in mstEdges:
		if !connections.has(i) and !connections.has([i[1],i[0]]):
			connections.append(i)
	
	var extraEdges = find_tri_edges(gatewayCoords.duplicate())
	
	for i in extraEdges:
		if !connections.has(i) and !connections.has([i[1],i[0]]):
			if randf() < extraPathwayFactor:
				connections.append(i)

	for i in connections:
		var gatewayIndex0 = gatewayCoords.find(Vector2i(i[0]))
		var gatewayIndex1 = gatewayCoords.find(Vector2i(i[1]))
		pathWays.append([gateways[gatewayIndex0], gateways[gatewayIndex1]])
	
	var gatewayInterconnect = []
	for i in pathWays:
#		##NEW CODE HERE1##
		var points1 = []
		var points2 = []
		for g in gatewayPaths[i[0]]:
			points1.append(g[0])
			
		for g in gatewayPaths[i[1]]:
			points2.append(g[0])
		
		var obstacles = []
		for j in gateways:
			var gatePos = j.global_position
#			if j != i[0] and j != i[1]:
			var closestPoint = Geometry2D.get_closest_point_to_segment(gatePos, i[0].global_position, i[1].global_position)
			if gatePos.distance_to(closestPoint) < 640: #40 tiles distance
				var rect = gatewayPaths[j]
				for r in rect:
					obstacles.append(r)
				rect = gatewayInnerRect[j]
				for r in rect:
					obstacles.append(r)
				
		for j in points1:
			for k in points2:
				var is_valid = true
				for o in obstacles:
					if j!= o[0] and j!= o[1] and k != o[0] and k != o[1]:
						if Geometry2D.segment_intersects_segment(j, k, o[0], o[1]):
							is_valid = false
				if is_valid:
					gatewayInterconnect.append([j, k])
					pathDraw.append([j, k])
		##NEW CODE ENDS1##
		
		##NEW CODE HERE##
#		var point1 = Vector2.ZERO
#		var point2 = Vector2.ZERO
#		var minDist = INF
#		var closest = Vector2.ZERO
#		for j in gatewayPaths[i[0]]:
#			var closestEntry = Vector2.ZERO
#			var testDist = j[0].distance_to(i[1].global_position)
#			if testDist < minDist:
#				minDist = testDist
#				closest = j[0]
#			point1 = closest
#
#		minDist = INF
#		closest = Vector2.ZERO
#		for j in gatewayPaths[i[1]]:
#			var testDist = j[0].distance_to(point1)
#			if testDist < minDist:
#				minDist = testDist
#				closest = j[0]
#			point2 = closest
#
#		pathWayCoords.append([tileMap.local_to_map(point1), tileMap.local_to_map(point2)])
#		pathDraw.append([point1,point2])
		##NEW CODE ENDS
		
#		var point1 = Vector2.ZERO
#		var point2 = Vector2.ZERO
#		var startConnector = []
#		var endConnector = []
#
#		var minDist = INF
#		var closest = Vector2.ZERO
#		for j in i[0].get_node("entry_points").get_children():
#			if j.global_position.distance_to(i[1].global_position) < minDist:
#				minDist = j.global_position.distance_to(i[1].global_position)
#				closest = j.global_position + (Vector2.RIGHT.rotated(i[0].global_position.angle_to_point(j.global_position))*entryWayDist)
#				startConnector = [tileMap.local_to_map(j.global_position), tileMap.local_to_map(closest)]
#		point1 = closest
#
#		minDist = INF
#		closest = Vector2.ZERO
#		for j in i[1].get_node("entry_points").get_children():
#			if j.global_position.distance_to(i[0].global_position) < minDist:
#				minDist = j.global_position.distance_to(i[0].global_position)
#				closest = j.global_position + (Vector2.RIGHT.rotated(i[1].global_position.angle_to_point(j.global_position))*entryWayDist)
#				endConnector = [tileMap.local_to_map(closest), tileMap.local_to_map(j.global_position)]
#		point2 = closest
#
#		gatewayExtensions.append(startConnector)
#		pathWayCoords.append([tileMap.local_to_map(point1), tileMap.local_to_map(point2)])
#		gatewayExtensions.append(endConnector)
	pathDraw.clear()
	var pathsCombined = []
	for i in gateways:
		for j in i.get_node("entry_points").get_children():
			pathsCombined.append([i.global_position, j.global_position])
		for j in gatewayPaths[i]:
			pathsCombined.append(j)
			
	for i in gatewayInterconnect:
		pathsCombined.append(i)
		
	for i in gatewayConnectors:
		pathsCombined.append(i)
		
	pathDraw = pathsCombined.duplicate()
	
	var pathWayPoints = []
	for i in pathWays:
		var point1 = Vector2.ZERO
		var point2 = Vector2.ZERO

		var minDist = INF
		var closest = Vector2.ZERO
		for j in i[0].get_node("entry_points").get_children():
			var dist = j.global_position.distance_to(i[1].global_position)
			if  dist < minDist:
				minDist = dist
				closest = j.global_position
		point1 = closest

		minDist = INF
		closest = Vector2.ZERO
		for j in i[1].get_node("entry_points").get_children():
			var dist = j.global_position.distance_to(point1)
			if dist < minDist:
				minDist = dist
				closest = j.global_position
		point2 = closest
		pathWayPoints.append([point1, point2])
		
	var aStarPath = AStar2D.new()
	var addedPoints = []
	for i in pathsCombined:
			if i[0] not in addedPoints:
				var id = aStarPath.get_available_point_id()
				aStarPath.add_point(id, i[0])
				addedPoints.append(i[0])
				
	for i in pathsCombined:
			var id1 = aStarPath.get_closest_point(i[0])
			var id2 = aStarPath.get_closest_point(i[1])
			if id1 != id2:
				aStarPath.connect_points(id1, id2)
			
#			var id1 = aStarPath.get_available_point_id()
#			if j[0] in addedPoints:
#				id1 = aStarPath.get_closest_point(j[0])
#			else:
#				aStarPath.add_point(id1, j[0])
#				addedPoints.append(j[0])
#
#			var id2 = aStarPath.get_available_point_id()
#			if j[1] in addedPoints:
#				id2 = aStarPath.get_closest_point(j[1])
#			else:
#				aStarPath.add_point(id1, j[1])
#				addedPoints.append(j[1])
#
#			aStarPath.connect_points(id1, id2)
#	for i in pathsCombined:
		
#		var id1 = aStarPath.get_available_point_id()
#		if i[0] in addedPoints:
#			id1 = aStarPath.get_closest_point(i[0])
#		else:		
#			aStarPath.add_point(id1, i[0])
#			addedPoints.append(i[0])
#
#		var id2 = aStarPath.get_available_point_id()
#		if i[1] in addedPoints:
#			id1 = aStarPath.get_closest_point(i[1])
#		else:
#			aStarPath.add_point(id2, i[1])
#			addedPoints.append(i[1])
#
#		aStarPath.connect_points(id1, id2)
		
	for i in pathWays:
		var id1 = aStarPath.get_closest_point(i[0].global_position)
		var id2 = aStarPath.get_closest_point(i[1].global_position)
		var pathIDs = aStarPath.get_id_path(id1, id2)
		
		for j in pathIDs.size()-1:
			var pointPos1 = aStarPath.get_point_position(pathIDs[j])
			var pointPos2 = aStarPath.get_point_position(pathIDs[j+1])
			pathWayCoords.append([pointPos1, pointPos2])
			
#	pathDraw2 = pathWayCoords.duplicate()

	for i in pathWayCoords:
		var points = walker([tileMap.local_to_map(i[0]), tileMap.local_to_map(i[1])], null)
		for j in points:
			if tileMap.get_cell_atlas_coords(0, j) == Vector2i(-1,-1):
				tileMap.set_cell(0,j,1,floorTile)

	for i in tileMap.get_used_cells(0):
		if tileMap.get_cell_tile_data(0, i).get_custom_data("floor"):
			for j in neighFour:
				if tileMap.get_cell_atlas_coords(0, i+j) == Vector2i(-1,-1):
					tileMap.set_cell(0,i+j,0,wallTile)
#					BetterTerrain.set_cell(tileMap, 0, i+j, 0)

	var tileMapSize = tileMap.get_used_rect().size + Vector2i(30,30)
	var tileMapPos = tileMap.get_used_rect().position - Vector2i(15,15)
	for x in range(tileMapPos.x, tileMapPos.x + tileMapSize.x):
		for y in range(tileMapPos.y, tileMapPos.y + tileMapSize.y):
			if tileMap.get_cell_source_id(0, Vector2i(x,y)) == -1:
				tileMap.set_cell(1,Vector2i(x,y), 2, blackTile)
	
	BetterTerrain.update_terrain_cells(tileMap, 0, tileMap.get_used_cells(0), true)
	
#	BetterTerrain.set_cells(tileMap, 1, unusedCells, 0) 
#func _draw():
#	if pathDraw:
#		for i in pathDraw:
#			draw_polyline(i, Color.GREEN, 3, true)
#	if pathDraw1:
#		for i in pathDraw1:
#			draw_polyline(i, Color.YELLOW, 3, true)
#	if pathDraw2:
#		for i in pathDraw2:
#			draw_polyline(i, Color.RED, 5, true)
#	if connectorsDraw:
#		for i in connectorsDraw:
#			draw_polyline(i, Color.BLUE, 5, true)
#	if pointDraw:
#		for i in pointDraw:
#			draw_circle(i, 5,Color.RED)
					
func generate_gateways(amount):
	var _gateways = []
	
	var grid = []
	for x in amount*gridScaleFactor:
		grid.append([])
		for y in amount*gridScaleFactor:
			grid[x].append(0)
	var gridSize = grid.size()
			
	while _gateways.size() < amount:
		var gatewayCentre = Vector2i(randi_range(0, gridSize-1),randi_range(0, gridSize-1))
		
		if !grid[gatewayCentre.x][gatewayCentre.y]:
			grid[gatewayCentre.x][gatewayCentre.y] = 1
			for i in neighEight:
				var neighbour = gatewayCentre + i
				if neighbour.x in range(0, gridSize) and neighbour.y in range(0, gridSize):
					grid[neighbour.x][neighbour.y] = 1
			
			gatewayCentre = (gatewayCentre * gridCellSize) - (Vector2i(1,1) * (gridCellSize*gridSize/2))
			
			var gateway = gatewayScenes.pick_random().instantiate()
			var gatewayTileMap = gateway.get_node("TileMap")
			var gatewayTiles = gatewayTileMap.get_used_cells(0)
			
			for i in gatewayTiles:
				var atlasCoord = gatewayTileMap.get_cell_atlas_coords(0, i)
				var sourceID = gatewayTileMap.get_cell_source_id(0, i)
				tileMap.set_cell(0, tileMap.local_to_map(gatewayCentre)+i, sourceID, atlasCoord)
			gateway.position = gatewayCentre 
			_gateways.append(gateway)
	return _gateways
	
func find_mst(points):
	var aStarPath = AStar2D.new()
	aStarPath.add_point(aStarPath.get_available_point_id(), points.pop_front())
	while points:
		var minDist = INF
		var minPos = null
		var pos = null
		
		for i in aStarPath.get_point_ids():
			var pos1 = aStarPath.get_point_position(i)
			
			for pos2 in points:
				if pos1.distance_to(pos2) < minDist:
					minDist = pos1.distance_to(pos2)
					minPos = pos2
					pos = pos1
					
		var id = aStarPath.get_available_point_id()
		aStarPath.add_point(id, minPos)
		aStarPath.connect_points(aStarPath.get_closest_point(pos), id)
		points.erase(minPos)
	
	var pathVectors = []
	for i in aStarPath.get_point_ids():
			for c in aStarPath.get_point_connections(i):
				pathVectors.append(	[aStarPath.get_point_position(i), 
									aStarPath.get_point_position(c)])
	
	return pathVectors

func find_tri_edges(points):
	var pointsTri = Geometry2D.triangulate_delaunay(points)
	var pathVectors = []
	for i in range(0, pointsTri.size(), 3):
		pathVectors.append([points[pointsTri[i]],
							points[pointsTri[i + 1]]])
		pathVectors.append([points[pointsTri[i + 1]],
							points[pointsTri[i + 2]]])
		pathVectors.append([points[pointsTri[i + 2]],
							points[pointsTri[i]]])
	return pathVectors

func walker(points, obstacles):
#	print("avoidance running")
	var start = Vector2(points[0])
	var end = Vector2(points[1])
	var walkerPoints = []
#	print(start, ", ", end)
#	obstacles.erase(obstacles.find(start))
	
	while start != end:
		var weights = []
		var totalWeight = 0
		
		var nearestObstacle = null
		
		if obstacles:
			var minDist = INF
			for i in obstacles:
				if start.distance_to(i) < minDist:
					minDist = start.distance_to(i)
					nearestObstacle = i
					
			for i in neighFour:
				var weight = 0
				if (start+Vector2(i)).distance_to(nearestObstacle) > pathwayAvoidanceDist:
					weight = (start+Vector2(i)).distance_to(end)
					weights.append((1/exp(weight)))
					totalWeight += (1/exp(weight))
				else:
					weight = (start+Vector2(i)).distance_to(nearestObstacle*-1)
					weights.append((1/exp(weight)))
					totalWeight += (1/exp(weight))
			
			if !totalWeight:
				weights.clear()
				weights = []
				totalWeight = 0
				for i in neighFour:
					var weight = (start+Vector2(i)).distance_to(end)
					weights.append((1/exp(weight)))
					totalWeight += (1/exp(weight))
		else:
			for i in neighFour:
					var weight = (start+Vector2(i)).distance_to(end)
					weights.append((1/exp(weight)))
					totalWeight += (1/exp(weight))
			
		for i in weights.size():
			if weights[i] != 0:
				weights[i] = (weights[i]/totalWeight)
		
		var randomValue = randf()
		var cumulativeWeight = 0.0
		var direction = Vector2.RIGHT
		for i in weights.size():
			cumulativeWeight += weights[i]
			if weights[i] != 0:
				if randomValue < cumulativeWeight:
					direction = Vector2(neighFour[i])
					break
				
		start += direction
		
		var rWidth = randi_range(2,4)
		var rHeight = randi_range(2,4)
		walkerPoints.append(start)
		for x in range(-rWidth, rWidth):
			for y in range(-rHeight, rHeight):
				walkerPoints.append(start+Vector2(x,y))
#	print("finished")
	return walkerPoints
	
func _process(delta):
	if is_mapPreview:
		if Input.is_action_just_released("ui_select"):
			is_mapPreview = false
			var player = playerScene.instantiate()
			player.position = gateways.pick_random().position
			$Camera2D.enabled = false
			$CanvasLayer.visible = false
			player.get_node("Camera2D").enabled = true
			add_child(player)
