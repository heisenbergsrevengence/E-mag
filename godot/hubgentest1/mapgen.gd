extends Node2D

#Debug settings
enum gameModes		{DEBUGMAPSETUP,
					DEBUGMAPGEN,
					PLAY
					}
@export var isDebug: bool = true
@export var defaultGameMode: int = gameModes.DEBUGMAPSETUP
@onready var debugDraw = $DebugDraw
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
@export var attemptsPerGateway: int = 2000
@export var gridScaleFactor: float = 0.85
@export var gridCellSize: int = 196
@export var extraPathwayFactor: float = 0.1
@export var entryWayDist = 128
@export var gatewayOuterRectFactor: float = 1.0
@export var gatewayInnerRectFactor: float = 1.0
@export var pathfindAvoidanceDist: = 640
@export var maxWalkerAttempts = 60000
@export var outerWallThickness = 2
@export var gatewayScenePath: String = "res://gateways/"
@onready var tileMap = $TileMap
var floorSource: int = 1
var blackSource: int = 2
var wallSource: int = 4
var floorTile: Vector2i = Vector2i(0,0)
var blackTile: Vector2i = Vector2i(0,0)
var wallTile: Vector2i = Vector2i(0,0)
var pathfindingGraph: Array = []
var gatewayScenes: Array

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var rngState: int = 0
var tileMapCellSize = 16

var playerScene = preload("res://player.tscn")

var neighFour: Array = [Vector2i(1,0), Vector2i(0,1), Vector2i(-1,0), Vector2i(0,-1)]
var neighEight: Array = [Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1), 
				Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)]

var is_mapPreview = true
var isMapGen = true
var player
var screenBuffer
var cameraTarget
var instantCamera = true

var gateways = []

func _ready():
	get_tree().get_root().size_changed.connect(_on_screen_resize)
	camera_setup()
	gatewayScenes = gateway_scene_load(gatewayScenePath)
	
	#Generate map
	await generate_map()
	isMapGen = false
	
func _process(delta):
	$CanvasLayer/Label.text = debugLog[-1]
	if is_mapPreview and !isMapGen:
		if Input.is_action_just_released("ui_select"):
			is_mapPreview = false
			player = playerScene.instantiate()
			player.position = gateways.pick_random().position
			$Camera.global_position = player.global_position
			cameraTarget = $Camera.global_position
			$CanvasLayer.visible = false
			$Camera.zoom = Vector2(4,4)
			add_child(player)
			
	elif !isMapGen:
		if Input.is_action_just_released("ui_accept"):
			instantCamera = !instantCamera
		var playerOffset = (cameraTarget - player.global_position)
		if playerOffset.x > screenTransitionPoint.x/2 -16 and Input.is_action_pressed("ui_left"):
			cameraTarget.x = cameraTarget.x - screenTransitionPoint.x
		if playerOffset.x < -screenTransitionPoint.x/2 + 16 and Input.is_action_pressed("ui_right"):
			cameraTarget.x = cameraTarget.x + screenTransitionPoint.x
		if playerOffset.y > screenTransitionPoint.y/2 - 16 and Input.is_action_pressed("ui_up"):
			cameraTarget.y = cameraTarget.y -screenTransitionPoint.y
		if playerOffset.y < -screenTransitionPoint.y/2 + 16 and Input.is_action_pressed("ui_down"):
			cameraTarget.y = cameraTarget.y + screenTransitionPoint.y
		if $Camera.global_position != cameraTarget:
			if instantCamera:
				$Camera.global_position = cameraTarget
			else:
				$Camera.global_position = $Camera.global_position.move_toward(cameraTarget, 32)

func generate_map() -> void:
	if !gatewayScenes.size():
		debugLog.append("Failed to load any gateway scenes. Aborting map generation.")
		return
		
	rng.seed = mapSeed
	
	debugLog.append("Starting map generation...")
	
	if !isSkipAllAnimations:
		debugLog.append("Press space to skip the current animation, press enter to skip all. This does not affect generation, only animation.")
	
	debugLog.append("Placing " + str(gatewayAmount) + "gateways... ")
	gateways = await generate_gateways(gatewayAmount)
	debugDraw.rectDraw2.clear()
	debugDraw.rectDraw.clear()
	debugDraw.queue_redraw()
	
	if gateways.size() < gatewayAmount:
		debugLog.append("Failed to place all gateways. Aborting map generation.")
		return
	
	debugLog.append("Generating gateway graph...")
	var gatewayGraph: Array = await generate_gateway_graph(gateways)

	debugLog.append("Generating pathfinding graph...")
	
	await generate_pathfind_graph(gateways, gatewayGraph)
	
	debugDraw.lineDraw3.clear()
	debugLog.append("Generating pathway graph...")
	var pathwayGraph = await generate_pathway_graph(pathfindingGraph, gatewayGraph)
	
	for i in pathfindingGraph:
		debugDraw.lineDraw2.append(i)
	
	debugDraw.lineDraw2.clear()
	debugDraw.lineDraw.clear()
	for i in pathwayGraph:
		debugDraw.lineDraw2.append(i)
	debugDraw.lineDraw3.clear()
	debugDraw.queue_redraw()

	debugLog.append("Generating pathways...")
	
	generate_pathways(pathwayGraph)
	
	debugLog.append("Filling tilemap...")
	await fill_tilemap()
	
	debugDraw.lineDraw2.clear()
	debugDraw.lineDraw.clear()
	debugDraw.lineDraw3.clear()
	debugDraw.queue_redraw()
	
	debugLog.append("Map generation complete! Press space to explore.")

func fill_tilemap() -> void:
	for k in outerWallThickness:
		debugLog.append("Wrapping in walls...")
		for i in tileMap.get_used_cells(0):
			if !k:
				if tileMap.get_cell_tile_data(0, i).get_custom_data("floor"):
					for j in neighFour:
						if tileMap.get_cell_atlas_coords(0, i+j) == Vector2i(-1,-1):
							tileMap.set_cell(0,i+j,4,wallTile)
							
			else:
				for j in neighFour:
					if tileMap.get_cell_atlas_coords(0, i+j) == Vector2i(-1,-1):
						tileMap.set_cell(0,i+j,4,wallTile)
	await animate_generation()
	
	debugLog.append("Wrapping in void...")
	var tileMapSize: Vector2 = tileMap.get_used_rect().size + Vector2i(40,40)
	var tileMapPos: Vector2 = tileMap.get_used_rect().position - Vector2i(20,20)
	for x in range(tileMapPos.x, tileMapPos.x + tileMapSize.x):
		for y in range(tileMapPos.y, tileMapPos.y + tileMapSize.y):
			if tileMap.get_cell_source_id(0, Vector2i(x,y)) == -1:
				tileMap.set_cell(1,Vector2i(x,y), blackSource, blackTile)

	BetterTerrain.update_terrain_cells(tileMap, 0, tileMap.get_used_cells(0), true)
	
func walker(points: Array) -> Array:
	var start: Vector2 = Vector2(points[0])
	var end: Vector2 = Vector2(points[1])
	var walkerPoints: Array = []
	var attempts: int = 0
	debugLog.append("Starting path...")
	while start != end or attempts > maxWalkerAttempts:
		attempts += 1
		var weights: Array = []
		var totalWeight = 0

		for i in neighFour:
			var weight = (start+Vector2(i)).distance_to(end)
			weights.append((1/exp(weight)))
			totalWeight += (1/exp(weight))
		var direction: Vector2
		if !weights.size():
			direction = Vector2(neighFour[rng.randi_range(0, neighFour.size()-1)])
		else:
			for i in weights.size():
				if weights[i] != 0:
					weights[i] = (weights[i]/totalWeight)
			
			var randomValue: float = rng.randf()
			var cumulativeWeight: float = 0.0
			
			for i in weights.size():
				cumulativeWeight += weights[i]
				if weights[i] != 0:
					if randomValue < cumulativeWeight:
						direction = Vector2(neighFour[i])
						break
				
		start += direction
		
		var rWidth: int = rng.randi_range(2,4)
		var rHeight: int = rng.randi_range(2,4)
		walkerPoints.append(start)
		for x in range(-rWidth, rWidth):
			for y in range(-rHeight, rHeight):
				walkerPoints.append(start+Vector2(x,y))
	
	if start != end:
		debugLog.append("Failed to make path after " + str(attempts) + " attempts. Parts of map maybe inaccessable.")
		
	return walkerPoints

func generate_pathways(_pathwayGraph: Array) -> void:
	for i in _pathwayGraph:
		var points: Array = walker([tileMap.local_to_map(i[0]), tileMap.local_to_map(i[1])])
		for j in points:
			if tileMap.get_cell_atlas_coords(0, j) == Vector2i(-1,-1):
				tileMap.set_cell(0,j,1,floorTile)

func generate_pathway_graph(_pathfindingGraph: Array, _gatewayGraph: Array) -> Array:
	var _pathwayGraph: Array = []
	var pathWayPoints: Array = []
	for i in _gatewayGraph:
		var point1: Vector2 = Vector2.ZERO
		var point2: Vector2 = Vector2.ZERO

		var minDist = INF
		var closest: Vector2 = Vector2.ZERO
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
		
	var aStarPath: AStar2D = AStar2D.new()
	var addedPoints: Array = []
	for i in _pathfindingGraph:
			if i[0] not in addedPoints:
				var id = aStarPath.get_available_point_id()
				aStarPath.add_point(id, i[0])
				addedPoints.append(i[0])
			if i[1] not in addedPoints:
				var id = aStarPath.get_available_point_id()
				aStarPath.add_point(id, i[1])
				addedPoints.append(i[1])

	for i in _pathfindingGraph:
			var id1 = aStarPath.get_closest_point(i[0])
			var id2 = aStarPath.get_closest_point(i[1])
			if id1 != id2:
				aStarPath.connect_points(id1, id2)

	for i in pathWayPoints:
		var id1 = aStarPath.get_closest_point(i[0])
		var id2 = aStarPath.get_closest_point(i[1])
		var pathIDs = aStarPath.get_id_path(id1, id2)
		if !pathIDs.size():
			debugLog.append("Could not find a pathway. Map generation flawed. Try increasing gridCellSize, or gridScaleFactor.")
		
		for j in pathIDs.size()-1:
			var pointPos1 = aStarPath.get_point_position(pathIDs[j])
			var pointPos2 = aStarPath.get_point_position(pathIDs[j+1])
			_pathwayGraph.append([pointPos1, pointPos2])
			debugDraw.lineDraw3.append([pointPos1, pointPos2])
			debugDraw.queue_redraw()
			await animate_generation()
	
	return _pathwayGraph
	
func generate_pathfind_graph(_gateways: Array, _gatewayGraph: Array) -> void:	
	for i in _gatewayGraph:
		debugDraw.rectDraw3.append(i[0].outerRect)
		debugDraw.rectDraw3.append(i[1].outerRect)
		debugDraw.queue_redraw()
		var points1: Array = []
		var points2: Array = []
		for g in i[0].outerRect:
			points1.append(g[0])
			
		for g in i[1].outerRect:
			points2.append(g[0])

		var obstacles: Array = []
		for j in gateways:
			var gatePos: Vector2 = j.global_position
			var closestPoint: Vector2 = Geometry2D.get_closest_point_to_segment(gatePos, i[0].global_position, i[1].global_position)
			if gatePos.distance_to(closestPoint) < pathfindAvoidanceDist:
				var rect: Array = j.outerRect
				for r in rect:
					obstacles.append(r)
					debugDraw.rectDraw2.append(rect)
					
				rect = j.innerRect
				for r in rect:
					obstacles.append(r)
				debugDraw.rectDraw.append(rect)
			debugDraw.queue_redraw()
		
		for j in points1:
			for k in points2:
				var is_valid = true
				for o in obstacles:
					if j!= o[0] and j!= o[1] and k != o[0] and k != o[1]:
						if Geometry2D.segment_intersects_segment(j, k, o[0], o[1]):
							is_valid = false
				if is_valid:
					pathfindingGraph.append([j, k])
					debugDraw.lineDraw3.append([j,k])
					debugDraw.queue_redraw()
					await animate_generation()
					
		for j in debugDraw.lineDraw3:
			debugDraw.lineDraw2.append(j)
		for j in i[0].outerRect:
				if !debugDraw.lineDraw2.has(j):
						debugDraw.lineDraw2.append(j)
		for j in i[1].outerRect:
				if !debugDraw.lineDraw2.has(j):
						debugDraw.lineDraw2.append(j)
		await animate_generation()
#		debugDraw.lineDraw3.clear()
		debugDraw.rectDraw.clear()
		debugDraw.rectDraw2.clear()
		debugDraw.rectDraw3.clear()
		debugDraw.queue_redraw()

func find_tri_edges(nodes: Array) -> Array:
	var points: Array = []
	for i in nodes:
		points.append(i.global_position)
	
	var pointsTri: Array = Geometry2D.triangulate_delaunay(points)
	
	var vectorsGraph: Array = []
	for i in range(0, pointsTri.size(), 3):
		vectorsGraph.append([points[pointsTri[i]],
							points[pointsTri[i + 1]]])
		vectorsGraph.append([points[pointsTri[i + 1]],
							points[pointsTri[i + 2]]])
		vectorsGraph.append([points[pointsTri[i + 2]],
							points[pointsTri[i]]])
							
	var nodeGraph: Array = []
	for i in vectorsGraph:
		nodeGraph.append(	[nodes[(points.find(i[0]))],
							nodes[(points.find(i[1]))]])
							
	return nodeGraph

func find_mst(nodes: Array) -> Array:
	var points: Array = []
	for i in nodes:
		points.append(i.global_position)
		
	var pointsIndexFinder: Array = points.duplicate()
	
	var aStarPath: AStar2D = AStar2D.new()
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
	
	var vectorsGraph: Array = []
	for i in aStarPath.get_point_ids():
			for c in aStarPath.get_point_connections(i):
				vectorsGraph.append([aStarPath.get_point_position(i), 
									aStarPath.get_point_position(c)])
	var nodeGraph: Array = []
	for i in vectorsGraph:
		nodeGraph.append(	[nodes[(pointsIndexFinder.find(i[0]))],
							nodes[(pointsIndexFinder.find(i[1]))]])
	return nodeGraph

func generate_gateway_graph(_gateways: Array) -> Array:
	var _gatewayGraph: Array = []
	var mstEdges: Array = find_mst(_gateways.duplicate())
	
	debugLog.append("Finding MST...")
	for i in mstEdges:
		if !_gatewayGraph.has(i) and !_gatewayGraph.has([i[1],i[0]]):
			_gatewayGraph.append(i)
			await animate_generation()
			debugDraw.lineDraw.append([i[0].global_position, i[1].global_position])
			debugDraw.queue_redraw()
	
	debugLog.append("Adding extra edges...")
	var extraEdges: Array = find_tri_edges(_gateways.duplicate())
	for i in extraEdges:
		if !_gatewayGraph.has(i) and !_gatewayGraph.has([i[1],i[0]]):
			if rng.randf() < extraPathwayFactor:
				_gatewayGraph.append(i)
				await animate_generation()
				debugDraw.lineDraw.append([i[0].global_position, i[1].global_position])
				debugDraw.queue_redraw()
	return _gatewayGraph

func generate_bounding_rects(_gateway: Node2D) -> void:
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
		pathfindingGraph.append([round(_gateway.global_position), round(e.global_position)])
		for j in outerRectIncomplete:
			var entryPoint = Geometry2D.segment_intersects_segment(_gateway.global_position, entryLine, j[0], j[1])
			if entryPoint:
				entryPoints.append(round(entryPoint))
				pathfindingGraph.append([round(e.global_position), round(entryPoint)])
				
	var usedPoints = []
	for c in outerCorners.size():
		var start = outerCorners[c]
		var end = outerCorners[(c+1) % outerCorners.size()]
		entryPoints.sort_custom(func(a,b): return a.distance_to(start) < b.distance_to(start))
		while start != end:
			var is_intercepted = false
			for j in entryPoints:
				if !(j in usedPoints):
					if start.distance_to(j)+end.distance_to(j) >= start.distance_to(end)-100 and start.distance_to(j)+end.distance_to(j) <= start.distance_to(end)+100:
						outerRect.append([round(start), round(j)])
						usedPoints.append(j)
						start = j
						is_intercepted = true

			if !is_intercepted:
				outerRect.append([round(start), round(end)])
				start = end
		
	for c in innerCorners.size():
		innerRect.append([innerCorners[c], innerCorners[(c+1) % innerCorners.size()]])
	
	for r in outerRect:
		pathfindingGraph.append(r)
	
	_gateway.outerRect = outerRect
	_gateway.innerRect = innerRect

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
			debugLog.append("Failed to place " + str(amount) + " gateways after " + str(attempts) + " attempts. Consider increasing grid scale or cell size.")
			break
		var gatewayCentre: Vector2i = Vector2i(rng.randi_range(0, gridSize-1),rng.randi_range(0, gridSize-1))
		
		var neighbours: Array = []
		if !grid[gatewayCentre.x][gatewayCentre.y]:
			grid[gatewayCentre.x][gatewayCentre.y] = 1
			for i in neighEight:
				var neighbour: Vector2i = gatewayCentre + i
				if neighbour.x in range(0, gridSize) and neighbour.y in range(0, gridSize):
					grid[neighbour.x][neighbour.y] = 1
					neighbours.append(neighbour)
					
			for i in neighbours:
				for j in neighEight:
					var neighbour: Vector2i = i + j
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
			generate_bounding_rects(gateway)
			
			_gateways.append(gateway)
			await animate_generation()
			debugDraw.rectDraw.append(gateway.innerRect)
			debugDraw.rectDraw2.append(gateway.outerRect)
			debugDraw.queue_redraw()
			await animate_generation()

	return _gateways

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
				var scene = _gatewayScene.instantiate()
				if sceneState.get_node_name(1) != "TileMap":
					debugLog.append(str(path+file) + " was not loaded: Improper configuration/no tile map.")
				elif sceneState.get_node_name(2) != "entry_points":
					debugLog.append(str(path+file) + " was not loaded: Improper configuration/no entry points.")
				elif !scene.get_script():
					debugLog.append(str(path+file) + " was not loaded: No gateway script attached.")
				else:
					_gatewayScenes.append(_gatewayScene)
				scene.queue_free()
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

func animate_generation() -> void:
	if isDebug and !isAnimationSkipped and !isSkipAllAnimations:
		await get_tree().create_timer(0.001).timeout
