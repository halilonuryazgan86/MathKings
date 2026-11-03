extends Control
## Hesaptaki çocuk profillerini listeler; misafir ilerlemesini aktarma, yeni profil,
## çıkış ve hesap silme (mağaza/KVKK gereksinimi) buradan yapılır.

const MAX_PROFILES := 5

var _busy := false

@onready var _account: Label = %AccountLabel
@onready var _status: Label = %Status
@onready var _list: VBoxContainer = %ProfileList
@onready var _transfer: Button = %TransferButton
@onready var _new: Button = %NewButton
@onready var _delete_panel: Control = %DeletePanel
@onready var _delete_password: LineEdit = %DeletePassword
@onready var _delete_status: Label = %DeleteStatus


func _ready() -> void:
	if not Cloud.is_logged_in():
		GameState.account_mode = "login"
		GameState.go_to.call_deferred(GameState.SCENE_ACCOUNT)  # _ready içinde sahne değiştirilemez
		return
	_account.text = tr("PICKER_ACCOUNT").format({"email": Cloud.email})
	_transfer.pressed.connect(_on_transfer)
	_new.pressed.connect(_on_new)
	%LogoutButton.pressed.connect(_on_logout)
	%DeleteButton.pressed.connect(func() -> void: _delete_panel.show())
	%DeleteCancel.pressed.connect(func() -> void: _delete_panel.hide())
	%DeleteConfirm.pressed.connect(_on_delete)
	%BackButton.pressed.connect(_back)
	_delete_panel.hide()
	_transfer.hide()
	_new.hide()
	await _refresh()


func _refresh() -> void:
	for child in _list.get_children():
		child.queue_free()
	_status.text = tr("NET_WAIT")
	var res := await Cloud.list_profiles()
	if not res.ok:
		_status.text = res.error
		if res.status == 401:
			GameState.account_mode = "login"
			GameState.go_to(GameState.SCENE_ACCOUNT)
		return
	var profiles: Array = res.data
	_status.text = tr("PICKER_EMPTY") if profiles.is_empty() else ""
	for p in profiles:
		var b := Button.new()
		b.text = "%s  ·  %s" % [p.nickname, tr("GRADE_N").format({"grade": int(p.grade)})]
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		if p.id == Cloud.active_profile_id:
			b.text += "  (%s)" % tr("PICKER_ACTIVE")
		b.pressed.connect(_on_pick.bind(p))
		_list.add_child(b)

	var guest := GameState.guest_save()
	var can_add := profiles.size() < MAX_PROFILES
	_transfer.visible = can_add and guest.has_profile() and guest.linked_profile_id().is_empty()
	_transfer.text = tr("PICKER_TRANSFER").format({"name": guest.nickname()})
	_new.visible = can_add


func _on_pick(profile: Dictionary) -> void:
	if not _begin():
		return
	await GameState.activate_cloud_profile(profile)
	GameState.go_to(GameState.SCENE_MAIN_MENU)


func _on_transfer() -> void:
	if not _begin():
		return
	var res := await GameState.transfer_guest_progress()
	if res.ok:
		GameState.go_to(GameState.SCENE_MAIN_MENU)
	else:
		_end(res.error)


func _on_new() -> void:
	GameState.creating_cloud_profile = true
	GameState.go_to(GameState.SCENE_PROFILE_SETUP)


func _on_logout() -> void:
	if not _begin():
		return
	await GameState.logout()
	GameState.go_to(GameState.SCENE_MAIN_MENU)


func _on_delete() -> void:
	if _busy or _delete_password.text.is_empty():
		return
	_busy = true
	_delete_status.text = tr("NET_WAIT")
	var res := await Cloud.delete_account(_delete_password.text)
	_busy = false
	if not res.ok:
		_delete_status.text = res.error
		return
	await GameState.logout(false)
	GameState.notice_key = "ACCOUNT_DELETED"
	GameState.go_to(GameState.SCENE_MAIN_MENU)


func _begin() -> bool:
	if _busy:
		return false
	_busy = true
	_status.text = tr("NET_WAIT")
	return true


func _end(message: String) -> void:
	_busy = false
	_status.text = message


func _back() -> void:
	GameState.go_to(GameState.SCENE_MAIN_MENU)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _delete_panel.visible:
			_delete_panel.hide()
		else:
			_back()
