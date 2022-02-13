extends Interface

const Stats = preload("res://Objects/Enumerations.gd").Stats

var player_team: OpTeam
var opponent_team: OpTeam

var player_opmon: OpMon
var opponent_opmon: OpMon

var move_dialog = null

# Visual events during the battle (animations, dialogs or others) are put in the forms
# or "actions", a dictionnary with the name of a method and the parameters to give it
# The action queue is filled during the calculations and is executed afterward
# The action queue is not meant to be filled manually: methods exist to fill
# automatically the queue. You can see them after the "Methods queuing actions" section.
var _action_queue := []

# True if its the player’s turn being calculated, false if it’s the opponent’s
# turn being calculated. Used in some actions to determine which OpMon is active.
var _player_in_action := true

# True if the hp bar is animated so the player’s HP label can be updated in real time.
var _hp_bar_animated := false

func init(p_player_team: OpTeam, p_opponent_team: OpTeam):
	player_team = p_player_team
	opponent_team = p_opponent_team
	player_opmon = player_team.get_opmon(0)
	opponent_opmon = opponent_team.get_opmon(0)
	
func _enter_tree():
	$PlayerOpMon.texture = player_opmon.species.back_texture
	$OpponentOpMon.texture = opponent_opmon.species.front_texture
	$PlayerInfobox/Name.text = player_opmon.get_effective_name()
	$OpponentInfobox/Name.text = opponent_opmon.get_effective_name()
	$PlayerInfobox/HPLabel.text = player_opmon.get_hp_string()
	$PlayerInfobox/HP.max_value = player_opmon.stats[Stats.HP]
	$PlayerInfobox/HP.value = player_opmon.hp
	$OpponentInfobox/HP.max_value = opponent_opmon.stats[Stats.HP]
	$OpponentInfobox/HP.value = opponent_opmon.hp

func _process(_delta):
	if _hp_bar_animated:
		_update_hp_label()

func opmon_selected():
	pass
	
func item_selected():
	pass
	
func move_selected():
	$BaseDialog.visible = false
	move_dialog = load("res://Scenes/Battle/MoveDialog.tscn").instance()
	move_dialog.set_moves(player_opmon.moves)
	move_dialog.rect_position = $BaseDialog.rect_position
	add_child(move_dialog)
	
func move_chosen(id):
	remove_child(move_dialog)
	$TextDialog.visible = true
	var opponent_chosen = 0
	
	# Calculates the order of the turn
	var order = []
	var player_move_priority = player_opmon.moves[id].data.priority > opponent_opmon.moves[opponent_chosen].data.priority
	var no_move_priority = player_opmon.moves[id].data.priority == opponent_opmon.moves[opponent_chosen].data.priority
	var player_faster = player_opmon.get_effective_stats()[Stats.SPE] >= opponent_opmon.get_effective_stats()[Stats.SPE]
	if player_move_priority or (no_move_priority and player_faster):
		order.append(player_opmon)
		order.append(opponent_opmon)
	else:
		order.append(opponent_opmon)
		order.append(player_opmon)
	
	# Processes the turn
	for opmon in order:
		var move
		var opponent
		_player_in_action = opmon == player_opmon
		if _player_in_action:
			move = id
			opponent = opponent_opmon
		else:
			move = opponent_chosen
			opponent = player_opmon
		opmon.moves[move].move(self, opmon, opponent)
		if opmon.is_ko() or opponent.is_ko():
			ko()
	_next_action()
	
func _next_action():
	if _action_queue.empty():
		show_base_dialog()
		$TextDialog.visible = false
	else:
		var action = _action_queue.pop_front()
		self.callv(action["method"], action["parameters"])

func _end_turn():
	self.call_deferred("show_base_dialog")

func show_base_dialog():
	$BaseDialog.visible = true

func _update_hp_label():
	$PlayerInfobox/HPLabel.text = String($PlayerInfobox/HP.value) + " / " + String(player_opmon.stats[Stats.HP])

# Executed when one on the OpMons is KO
func ko():
	emit_signal("closed")

# Choices of the base dialog

func run_selected():
	emit_signal("closed")
	
func move_failed():
	pass
	
func move_ineffective():
	pass
	
func effectiveness(factor):
	pass

	
# Methods queuing actions

# The "text" parameter must be an array of Strings where one element is printed on one dialog.
# Make sure the text is not too long to be shown.
func add_dialog(text: Array):
	_action_queue.append({"method": "_dialog", "parameters": [text]})
	
# is_self: if the updated hp has to be the acting opmon’s bar (true) or the opponent’s one (false)
# new value: the new value of the hp bar.
func update_hp(is_self: bool, new_value: int):
	_action_queue.append({"method": "_update_hp", "parameters": [is_self == _player_in_action, new_value]})
	
func stat_changed(target: OpMon, stat, change):
	pass
	
# Methods executing actions
# Every action must, by one way or another, call back _next_action to continue the chain

# Calls _next_action via $TextDialog whose signal "dialog_over" is connected to _next_action
func _dialog(text: Array):
	$TextDialog.reset()
	$TextDialog.set_dialog_lines(text)
	$TextDialog.go()

# Calls _next_action via the animation player whose signal "animation_finished" is connected to "_health_bar_stop"
func _update_hp(player: bool, new_value: int):
	var hpbar:TextureProgress = $PlayerInfobox/HP if player else $OpponentInfobox/HP
	var animation_player: AnimationPlayer = $PlayerInfobox/HP/AnimationPlayer if player else $OpponentInfobox/HP/AnimationPlayer
	var animation := Animation.new()
	var track_index := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track_index, ".:value")
	animation.length = 1
	animation.track_insert_key(track_index, 0, hpbar.value)
	animation.track_insert_key(track_index, 1, new_value)
	if animation_player.has_animation("hpbar"):
		animation_player.remove_animation("hpbar")
	animation_player.add_animation("hpbar", animation)
	animation_player.play("hpbar")
	_hp_bar_animated = true
	
# Calls _next_action for _update_hp
func _health_bar_stop(_anim_name):
	$PlayerInfobox/HP/AnimationPlayer.stop()
	$OpponentInfobox/HP/AnimationPlayer.stop()
	_hp_bar_animated = false
	_next_action()
