extends Node2D

@onready var tileMap = $TileMap

var gatewayScenes = [preload("res://gateways/gateway0.tscn"), preload("res://gateways/gateway1.tscn")]
var playerScene = preload("res://player.tscn")

var forestTiles = [Vector2i(0,0),Vector2i(0,1),Vector2i(0,2),Vector2i(0,3),Vector2i(0,4), Vector2i(0,5), Vector2i(0,5), Vector2i(0,5)]
var wallTiles = [Vector2i(1,0),Vector2i(1,1),Vector2i(1,2),Vector2i(1,3),Vector2i(1,4), Vector2i(1,5), Vector2i(1,5), Vector2i(1,5)]

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
@export var entryWayDist = 80+16	#default 80
@export var pathwayAvoidanceDist = 11	#default 11

var is_mapPreview = true

var gateways = []

var pathDraw = []

func _ready():
	
# this was a bit of a hacky way to block the player in, but it's waaaay too slow to even be functional
#	for x in range(-(gatewayAmount*gridScaleFactor)/2*gridCellSize, (gatewayAmount*gridScaleFactor)/2*gridCellSize):
#		for y in range(-(gatewayAmount*gridScaleFactor)/2*gridCellSize, (gatewayAmount*gridScaleFactor)/2*gridCellSize):
#			tileMap.set_cell(0,Vector2i(x,y),0,wallTile)
	

	
	var gatewayCoords = []
	var connections = []
	var pathWays = []
	var pathWayCoords = []
	var gatewayExtensions = []
	
	gateways = generate_gateways(gatewayAmount)
	
	for i in gateways:
#		add_child(i)
		gatewayCoords.append(tileMap.local_to_map(i.position))
	
	
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
		
	for i in pathWays:
		var point1 = Vector2.ZERO
		var point2 = Vector2.ZERO
		var startConnector = []
		var endConnector = []
		
		var minDist = INF
		var closest = Vector2.ZERO
		for j in i[0].get_node("entry_points").get_children():
			if j.global_position.distance_to(i[1].global_position) < minDist:
				minDist = j.global_position.distance_to(i[1].global_position)
				closest = j.global_position + (Vector2.RIGHT.rotated(i[0].global_position.angle_to_point(j.global_position))*entryWayDist)
				startConnector = [tileMap.local_to_map(j.global_position), tileMap.local_to_map(closest)]
		point1 = closest
		
		minDist = INF
		closest = Vector2.ZERO
		for j in i[1].get_node("entry_points").get_children():
			if j.global_position.distance_to(i[0].global_position) < minDist:
				minDist = j.global_position.distance_to(i[0].global_position)
				closest = j.global_position + (Vector2.RIGHT.rotated(i[1].global_position.angle_to_point(j.global_position))*entryWayDist)
				endConnector = [tileMap.local_to_map(closest), tileMap.local_to_map(j.global_position)]
		point2 = closest
		
		gatewayExtensions.append(startConnector)
		pathWayCoords.append([tileMap.local_to_map(point1), tileMap.local_to_map(point2)])
		gatewayExtensions.append(endConnector)
	
	
#	print("avoidance running")
	for i in pathWayCoords:
		var points = walker(i, gatewayCoords)
		for j in points:
			if tileMap.get_cell_atlas_coords(0, j) == Vector2i(-1,-1):
				tileMap.set_cell(0,j,0,forestTiles.pick_random())
	
	for i in gatewayExtensions:
		var points = walker(i, null)
		for j in points:
			if tileMap.get_cell_atlas_coords(0, j) == Vector2i(-1,-1):
				tileMap.set_cell(0,j,0,forestTiles.pick_random())

	for i in tileMap.get_used_cells(0):
		if tileMap.get_cell_tile_data(0, i).get_custom_data("floor"):
			for j in neighFour:
				if tileMap.get_cell_atlas_coords(0, i+j) == Vector2i(-1,-1):
					tileMap.set_cell(0,i+j,0,wallTiles.pick_random())
					
	for i in pathWayCoords:
		pathDraw.append([tileMap.map_to_local(i[0]),tileMap.map_to_local(i[1])])
#	queue_redraw()
	for x in range(-80, 80):
		for y in range(-80, 80):
			if !tileMap.get_used_cells(0).has(Vector2i(x,y)):
				tileMap.set_cell(1,Vector2i(x,y), 1, Vector2i.ZERO)
#func _draw():
#	if pathDraw:
#		for i in pathDraw:
#			draw_polyline(i, Color.GREEN, 5, true)
					
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
				tileMap.set_cell(0, tileMap.local_to_map(gatewayCentre)+i, 0, atlasCoord)
				
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
		var direction = Vector2.ZERO
		for i in range(weights.size()):
			
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
