extends Node2D

#Debug settings
enum gameModes		{DEBUGMAPSETUP,
					DEBUGMAPGEN,
					PLAY
					}
@export var isDebug: bool = true
@export var defaultGameMode: int = gameModes.DEBUGMAPSETUP
var isAnimationSkipped: bool = false
var isSkipAllAnimations: bool = false
var debugLog: PackedStringArray = []

#Camera and window settings
@export var screenTransitionMargin: Vector2 = Vector2(8,8)
@export var playerCameraZoom: Vector2 = Vector2(4,4)
var screenTransitionPoint: Vector2
var cameraMode: int = defaultGameMode
@onready var camera = $Camera

#Map Generation Settings:
@export var mapSeed: int = 69420
@export var gatewayAmount: int = 15
@export var attemptsPerGateway: int = 20
@export var gridScaleFactor: float = 0.55
@export var gridCellSize: int = 224
@export var extraPathwayFactor: float = 0.1
@export var gatewayScenePath: String = "res://gateways/"
@onready var tileMap = $TileMap
var floorSource: int = 1
var blackSource: int = 2
var wallSource: int = 4
var floorTile: Vector2i = Vector2i(0,0)
var blackTile: Vector2i = Vector2i(2,1)
var wallTile: Vector2i = Vector2i(0,0)

var gatewayScenes: Array
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var rngState: int = 0
var tileMapCellSize = 16

var playerScene = preload("res://player.tscn")

var neighFour: Array = [Vector2i(1,0), Vector2i(0,1), Vector2i(-1,0), Vector2i(0,-1)]
var neighEight: Array = [Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1), 
				Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)]



#these two variables affect the avoidance process... changing them can cause the map to load
#very fast, but have unreachable areas, or take a very long/infinite time to load
#
#The avoidance process can be monitored in the debugging output, if it stops printing out
#"avoidance running" for a long time, it's probably stuck and won't recover
@export var entryWayDist = 128	#default 80
@export var pathwayAvoidanceDist = 0	#default 11

var is_mapPreview = true
var player
var screenBuffer
var cameraTarget
var instantCamera = true

var gateways = []

var pathDraw = []
var pathDraw1 = []
var pathDraw2 = []
var pointDraw = []
var connectorsDraw = []

func _ready():
	get_tree().get_root().size_changed.connect(_on_screen_resize)
	camera_setup()
	gatewayScenes = gateway_scene_load(gatewayScenePath)
	
	#Generate map
	await generate_map()
	
func generate_gateways(amount : int) -> Array:
	var attempts: int = 0
	var maxAttempts: int = amount * attemptsPerGateway
	var _gateways: Array = []
	var grid: Array = []
	for x in amount*gridScaleFactor:
		grid.append([])
		for y in amount*gridScaleFactor:
			grid[x].append(0)
	var gridSize: int = grid.size()
			
	while _gateways.size() < amount:
		attempts += 1
		if attempts > maxAttempts:
			debugLog.append("Failed to place " + str(amount) + " after " + str(attempts) + " attempts. Consider increasing grid scale or cell size.")
			break
		var gatewayCentre: Vector2i = Vector2i(rng.randi_range(0, gridSize-1),rng.randi_range(0, gridSize-1))
		
		if !grid[gatewayCentre.x][gatewayCentre.y]:
			grid[gatewayCentre.x][gatewayCentre.y] = 1
			for i in neighEight:
				var neighbour: Vector2i = gatewayCentre + i
				if neighbour.x in range(0, gridSize) and neighbour.y in range(0, gridSize):
					grid[neighbour.x][neighbour.y] = 1
			
			gatewayCentre = (gatewayCentre * gridCellSize) - (Vector2i(1,1) * (gridCellSize*gridSize/2))
			
			var gateway: Node2D = gatewayScenes[rng.randi_range(0, gatewayScenes.size()-1)].instantiate()
			var gatewayTileMap: TileMap = gateway.get_node("TileMap")
			var gatewayTiles: Array = gatewayTileMap.get_used_cells(0)
			
			for i in gatewayTiles:
				var atlasCoord: Vector2i = gatewayTileMap.get_cell_atlas_coords(0, i)
				var sourceID: int = gatewayTileMap.get_cell_source_id(0, i)
				tileMap.set_cell(0, tileMap.local_to_map(gatewayCentre)+i, sourceID, atlasCoord)
				
			gateway.position = gatewayCentre 
			_gateways.append(gateway)
			if isDebug and !isAnimationSkipped and !isSkipAllAnimations:
				await get_tree().create_timer(0.01).timeout
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
			player = playerScene.instantiate()
			player.position = gateways.pick_random().position
			$Camera2D.global_position = player.global_position
			cameraTarget = $Camera2D.global_position
			$CanvasLayer.visible = false
			$Camera2D.zoom = Vector2(4,4)
			add_child(player)
	else:
		if Input.is_action_just_released("ui_accept"):
			instantCamera = !instantCamera
		var playerOffset = (cameraTarget - player.global_position)
		if playerOffset.x > screenBuffer.x/2 -16 and Input.is_action_pressed("ui_left"):
			cameraTarget.x = cameraTarget.x - screenBuffer.x
		if playerOffset.x < -screenBuffer.x/2 + 16 and Input.is_action_pressed("ui_right"):
			cameraTarget.x = cameraTarget.x + screenBuffer.x
		if playerOffset.y > screenBuffer.y/2 - 16 and Input.is_action_pressed("ui_up"):
			cameraTarget.y = cameraTarget.y - screenBuffer.y
		if playerOffset.y < -screenBuffer.y/2 + 16 and Input.is_action_pressed("ui_down"):
			cameraTarget.y = cameraTarget.y + screenBuffer.y
		if $Camera2D.global_position != cameraTarget:
			if instantCamera:
				$Camera2D.global_position = cameraTarget
			else:
				$Camera2D.global_position = $Camera2D.global_position.move_toward(cameraTarget, 32)

func generate_map() -> void:
	if !gatewayScenes.size():
		debugLog.append("Failed to load any gateway scenes. Aborting map generation.")
		return
	
	rng.seed = mapSeed
	
	var gatewayCoords = []
	var connections = []
	var pathWays = []
	var pathWayCoords = []
	var gatewayExtensions = []
	var gatewayPaths = {}
	var gatewayInnerRect = {}
	var gatewayConnectors = []
	
	debugLog.append("Starting map generation...")
	
	if !isSkipAllAnimations:
		debugLog.append("Press space to skip the current animation, press enter to skip all. This does not affect generation, only animation.")
	debugLog.append("Placing " + str(gatewayAmount) + "gateways... ")
	
	gateways = await generate_gateways(gatewayAmount)
	
	if gateways.size() < gatewayAmount:
		debugLog.append("Failed to place all gateways. Aborting map generation.")
		return
		
	for i in gateways:
		gatewayCoords.append(tileMap.local_to_map(i.position))

		var gateway = i
		var gatewayTileMap = gateway.get_node("TileMap")
		var size = Vector2(gatewayTileMap.get_used_rect().size)
		size = size * tileMapCellSize #tile size
		var innerSize = Vector2(gatewayTileMap.get_used_rect().size) * tileMapCellSize
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
		var points1 = []
		var points2 = []
		for g in gatewayPaths[i[0]]:
			points1.append(g[0])
			
		for g in gatewayPaths[i[1]]:
			points2.append(g[0])
		
		var obstacles = []
		for j in gateways:
			var gatePos = j.global_position
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
					tileMap.set_cell(0,i+j,4,wallTile)

#	for i in tileMap.get_used_cells(0):
##		if tileMap.get_cell_tile_data(0, i).get_custom_data("floor"):
#		for j in neighFour:
#			if tileMap.get_cell_atlas_coords(0, i+j) == Vector2i(-1,-1):
#				tileMap.set_cell(0,i+j,4,wallTile)

	var tileMapSize = tileMap.get_used_rect().size + Vector2i(30,30)
	var tileMapPos = tileMap.get_used_rect().position - Vector2i(15,15)
	for x in range(tileMapPos.x, tileMapPos.x + tileMapSize.x):
		for y in range(tileMapPos.y, tileMapPos.y + tileMapSize.y):
			if tileMap.get_cell_source_id(0, Vector2i(x,y)) == -1:
				tileMap.set_cell(1,Vector2i(x,y), 2, blackTile)
	
	BetterTerrain.update_terrain_cells(tileMap, 0, tileMap.get_used_cells(0), true)
	
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
	
func gateway_scene_load(path: String) -> Array:
	var _gatewayScenes: Array = []
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file: String = dir.get_next()
		while file != "":
			if file.get_extension() == "tscn":
				var _gatewayScene: PackedScene = load(path + file)
				var sceneState: SceneState = _gatewayScene.get_state()
				if sceneState.get_node_name(1) != "TileMap":
					debugLog.append(str(path+file) + " was not loaded: Improper configuration/no tile map.")
				elif sceneState.get_node_name(2) != "entry_points":
					debugLog.append(str(path+file) + " was not loaded: Improper configuration/no entry points.")
				else:
					_gatewayScenes.append(_gatewayScene)
			file = dir.get_next()
	else:
		debugLog.append("Error loading the gateway directory. Supplied path does not exist.")
		
	if !_gatewayScenes.size():
		debugLog.append("No scenes found in the gateway directory. Map generation will not proceed.")
	
	return _gatewayScenes

func camera_setup() -> void:
	set_screen_transition_point()
	if !isDebug:
		camera.zoom = playerCameraZoom

func set_screen_transition_point() -> void:
	screenTransitionPoint = (get_viewport_rect().size/playerCameraZoom) - screenTransitionMargin
	
func _on_screen_resize() -> void:
	set_screen_transition_point()
