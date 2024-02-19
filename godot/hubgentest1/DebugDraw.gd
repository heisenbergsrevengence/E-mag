extends Node2D

var rectDraw: Array
var rectDraw2: Array
var rectDraw3: Array
var lineDraw: Array
var lineDraw2: Array
var lineDraw3: Array

var testingLineDraw: Array

func _draw():
	if rectDraw:
		for i in rectDraw:
			for j in i:
				draw_polyline(j, Color.RED, 2, true)
				draw_circle(j[0], 10, Color.YELLOW)
	if rectDraw2:
		for i in rectDraw2:
			for j in i:
				draw_polyline(j, Color.GREEN, 3, true)
				draw_circle(j[0], 10, Color.YELLOW)

	if lineDraw:
		for i in lineDraw:
			draw_line(i[0], i[1], Color.YELLOW, 8, true)
			draw_circle(i[0], 10, Color.YELLOW)

	if lineDraw2:
		for i in lineDraw2:
			draw_line(i[0], i[1], Color.GREEN, 3, true)
			draw_circle(i[0], 10, Color.YELLOW)

	if lineDraw3:
		for i in lineDraw3:
			draw_line(i[0], i[1], Color.BLUE, 3, true)
			draw_circle(i[0], 10, Color.YELLOW)

	if rectDraw3:
		for i in rectDraw3:
			for j in i:
				draw_polyline(j, Color.YELLOW, 3, true)
				draw_circle(j[0], 10, Color.YELLOW)

	if testingLineDraw:
		for i in testingLineDraw:
			draw_circle(i, 10, Color.YELLOW)
