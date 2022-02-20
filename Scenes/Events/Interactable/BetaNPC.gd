tool
extends "res://Scenes/Events/Interactable/Character.gd"

const PlayerClass = preload("Player.gd")
const OpTeam = preload("res://Objects/OpTeam.gd")
const OpMon = preload("res://Objects/OpMon.gd")

var player_team: OpTeam
var opponent_team: OpTeam

func _ready():
	._ready()
	if not Engine.editor_hint:
		var tackle = load("res://OpMon-Data/GodotResources/Moves/Tackle.tres")
		var growl = load("res://OpMon-Data/GodotResources/Moves/Growl.tres")
		var harden = load("res://OpMon-Data/GodotResources/Moves/Harden.tres")
		var bot_nature = load("res://OpMon-Data/GodotResources/Natures/Bot.tres")
		var popmon = OpMon.new("", load("res://OpMon-Data/GodotResources/Species/Furnurus.tres"), 10, 
		[tackle, growl, null, null], bot_nature)
		var oopmon = OpMon.new("", load("res://OpMon-Data/GodotResources/Species/Carnapple.tres"), 10, 
		[tackle, harden, null, null], bot_nature)
		player_team = OpTeam.new([popmon, null, null, null, null, null])
		opponent_team = OpTeam.new([oopmon, null, null, null, null, null])

# Called when the player interacts with the NPC
func interact(player: PlayerClass):
	.interact(player)
	if _moving != Vector2.ZERO:
		return
	_paused = true
	change_faced_direction(player.get_direction()) # Changes the faced direction of the NPC to face the player
	_map_manager.pause_player()
	var battle_scene = load("res://Scenes/Battle/BattleScene.tscn").instance()
	battle_scene.init(player_team, opponent_team)
	_map_manager.load_interface(battle_scene)

func change_faced_direction(player_faced_direction):
	# Change the direction the NPC is facing based on the direction the player
	# is facing: if the player is facing up then face down, etc.
	if player_faced_direction == Vector2.UP:
		$AnimatedSprite.flip_h = false
		$AnimatedSprite.animation = "walk_down"
	elif player_faced_direction == Vector2.DOWN:
		$AnimatedSprite.flip_h = false
		$AnimatedSprite.animation = "walk_up"
	elif player_faced_direction == Vector2.RIGHT:
		$AnimatedSprite.flip_h = true
		$AnimatedSprite.animation = "walk_side"
	elif player_faced_direction == Vector2.LEFT:
		$AnimatedSprite.flip_h = false
		$AnimatedSprite.animation = "walk_side"

func _unpause():
	_paused = false
