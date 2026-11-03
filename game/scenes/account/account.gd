extends Control
## Yetişkin hesabı ekranı (ebeveyn kapısından sonra açılır).
## Modlar: login, register, confirm, forgot, reset.

var _mode := ""
var _busy := false
var _pending_password := ""  # Doğrulamadan sonra otomatik giriş için (yalnızca bellekte)

@onready var _title: Label = %Title
@onready var _info: Label = %Info
@onready var _email: LineEdit = %EmailEdit
@onready var _password: LineEdit = %PasswordEdit
@onready var _password2: LineEdit = %Password2Edit
@onready var _code: LineEdit = %CodeEdit
@onready var _consent_row: Control = %ConsentRow
@onready var _consent: CheckBox = %ConsentCheck
@onready var _status: Label = %Status
@onready var _primary: Button = %PrimaryButton
@onready var _switch: Button = %SwitchButton
@onready var _forgot: Button = %ForgotButton
@onready var _resend: Button = %ResendButton
@onready var _consent_panel: Control = %ConsentPanel


func _ready() -> void:
	_primary.pressed.connect(_on_primary)
	_switch.pressed.connect(func() -> void: _set_mode("register" if _mode == "login" else "login"))
	_forgot.pressed.connect(func() -> void: _set_mode("forgot"))
	_resend.pressed.connect(_on_resend)
	%ConsentLink.pressed.connect(func() -> void: _consent_panel.show())
	%ConsentClose.pressed.connect(func() -> void: _consent_panel.hide())
	%BackButton.pressed.connect(_back)
	_consent_panel.hide()
	_email.text = Cloud.email
	_set_mode(GameState.account_mode)


func _set_mode(mode: String, info_key := "") -> void:
	_mode = mode
	_status.text = ""
	var titles := {"login": "ACC_LOGIN_TITLE", "register": "ACC_REGISTER_TITLE", "confirm": "ACC_CONFIRM_TITLE",
		"forgot": "ACC_FORGOT_TITLE", "reset": "ACC_RESET_TITLE"}
	var buttons := {"login": "MENU_LOGIN", "register": "ACC_CREATE", "confirm": "ACC_VERIFY",
		"forgot": "ACC_SEND_CODE", "reset": "ACC_CHANGE_PASSWORD"}
	_title.text = tr(titles[mode])
	_primary.text = tr(buttons[mode])
	_info.text = tr(info_key) if not info_key.is_empty() else ""
	_info.visible = not _info.text.is_empty()
	_password.visible = mode in ["login", "register", "reset"]
	_password.placeholder_text = tr("ACC_NEW_PASSWORD" if mode == "reset" else "ACC_PASSWORD")
	_password2.visible = mode in ["register", "reset"]
	_code.visible = mode in ["confirm", "reset"]
	_code.text = ""
	_consent_row.visible = mode == "register"
	_switch.visible = mode in ["login", "register"]
	_switch.text = tr("ACC_GO_REGISTER" if mode == "login" else "ACC_GO_LOGIN")
	_forgot.visible = mode == "login"
	_resend.visible = mode == "confirm"
	if mode in ["confirm", "forgot", "reset"]:
		_password.text = ""
		_password2.text = ""


func _on_primary() -> void:
	if _busy:
		return
	var error := _validate()
	if not error.is_empty():
		_status.text = tr(error)
		return
	_set_busy(true)
	var email := _email.text.strip_edges()
	match _mode:
		"login":
			var res := await Cloud.login(email, _password.text)
			if res.ok:
				GameState.go_to(GameState.SCENE_PROFILE_PICKER)
				return
			if res.code == "email_not_confirmed":
				_pending_password = _password.text
				_set_mode("confirm", "ACC_CONFIRM_INFO")
			else:
				_status.text = res.error
		"register":
			var res := await Cloud.register(email, _password.text, _consent.button_pressed)
			if res.ok:
				_pending_password = _password.text
				_set_mode("confirm", "ACC_CONFIRM_INFO")
			else:
				_status.text = res.error
		"confirm":
			var res := await Cloud.confirm_email(email, _code.text)
			if not res.ok:
				_status.text = res.error
			elif not _pending_password.is_empty():
				var login := await Cloud.login(email, _pending_password)
				_pending_password = ""
				if login.ok:
					GameState.go_to(GameState.SCENE_PROFILE_PICKER)
					return
				_set_mode("login", "ACC_CONFIRMED")
			else:
				_set_mode("login", "ACC_CONFIRMED")
		"forgot":
			var res := await Cloud.forgot_password(email)
			if res.ok:
				_set_mode("reset", "ACC_RESET_INFO")
			else:
				_status.text = res.error
		"reset":
			var res := await Cloud.reset_password(email, _code.text, _password.text)
			if res.ok:
				_password.text = ""
				_set_mode("login", "ACC_PASSWORD_CHANGED")
			else:
				_status.text = res.error
	_set_busy(false)


func _validate() -> String:
	var email := _email.text.strip_edges()
	if not ("@" in email and "." in email.get_slice("@", 1)):
		return "ACC_ERR_EMAIL"
	if _password.visible and _password.text.length() < 8:
		return "ACC_ERR_PASSWORD"
	if _password2.visible and _password.text != _password2.text:
		return "ACC_ERR_MATCH"
	if _code.visible and not (_code.text.strip_edges().length() == 6 and _code.text.strip_edges().is_valid_int()):
		return "ACC_ERR_CODE"
	if _consent_row.visible and not _consent.button_pressed:
		return "ACC_ERR_CONSENT"
	return ""


func _on_resend() -> void:
	_set_busy(true)
	var res := await Cloud.resend_confirmation(_email.text)
	_status.text = tr("ACC_CODE_SENT") if res.ok else res.error
	_set_busy(false)


func _set_busy(busy: bool) -> void:
	_busy = busy
	_primary.disabled = busy
	if busy:
		_status.text = tr("NET_WAIT")


func _back() -> void:
	GameState.go_to(GameState.SCENE_MAIN_MENU)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _consent_panel.visible:
			_consent_panel.hide()
		else:
			_back()
