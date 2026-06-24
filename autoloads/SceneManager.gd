extends Node

# Central scene router. Every transition goes THROUGH the loading screen so the player
# always sees the title + status bar (and so threaded loading has somewhere to live).
# loading_screen.gd reads target_scene to know what to load next; on boot the main scene
# is the loading screen itself and this default sends it to the main menu.

const LOADING   := "res://scenes/loading_screen.tscn"
const MAIN_MENU := "res://scenes/main_menu.tscn"
const HOLE      := "res://scenes/hole.tscn"
const CLUBHOUSE := "res://scenes/clubhouse.tscn"
const PRO_SHOP  := "res://scenes/pro_shop.tscn"

var target_scene: String = MAIN_MENU

func goto(path: String) -> void:
	target_scene = path
	get_tree().change_scene_to_file(LOADING)
