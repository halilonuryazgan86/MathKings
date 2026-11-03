extends Node
## Sunucu API istemcisi ve yetişkin hesap oturumu.
## Çevrimdışıyken oyun etkilenmez: istekler {"ok": false, "error": ...} döndürür.
## Erişim belirteci yalnızca bellekte tutulur; süresi dolunca yenileme belirteciyle yenilenir.

signal session_changed
signal session_expired

const API := "/api/v1"
const CONSENT_VERSION := "2026-11-taslak"  # Sunucudaki Consent:CurrentVersion ile aynı olmalı.
const TIMEOUT_SEC := 15.0
const REFRESH_MARGIN_SEC := 30.0

var email := ""
var active_profile_id := ""
var _refresh_token := ""
var _access_token := ""
var _access_expires_at := 0.0


func _ready() -> void:
	var s := SessionStore.read()
	email = s.get("email", "")
	_refresh_token = s.get("refreshToken", "")
	active_profile_id = s.get("activeProfileId", "")


## Debug: geliştirme adresi (Android'de yerel ağ). Release: yalnızca HTTPS üretim adresi.
func base_url() -> String:
	if OS.is_debug_build():
		return str(ProjectSettings.get_setting("mathkings/api/base_url", "http://localhost:5055")).trim_suffix("/")
	return str(ProjectSettings.get_setting("mathkings/api/release_base_url", "")).trim_suffix("/")


## Release derlemelerde her zaman false: sertifika doğrulaması kapatılamaz.
func _allow_dev_certificate() -> bool:
	return OS.is_debug_build() and base_url().begins_with("https://") \
		and ProjectSettings.get_setting("mathkings/api/allow_dev_certificate", false) == true


func is_logged_in() -> bool:
	return not _refresh_token.is_empty()


# --- Hesap -------------------------------------------------------------------

func register(mail: String, password: String, is_adult: bool) -> Dictionary:
	return await _call(HTTPClient.METHOD_POST, "/auth/register", {
		"email": mail.strip_edges(), "password": password,
		"isAdult": is_adult, "consentVersion": CONSENT_VERSION})


func confirm_email(mail: String, code: String) -> Dictionary:
	return await _call(HTTPClient.METHOD_POST, "/auth/confirm-email", {"email": mail.strip_edges(), "code": code.strip_edges()})


func resend_confirmation(mail: String) -> Dictionary:
	return await _call(HTTPClient.METHOD_POST, "/auth/resend-confirmation", {"email": mail.strip_edges()})


func forgot_password(mail: String) -> Dictionary:
	return await _call(HTTPClient.METHOD_POST, "/auth/forgot-password", {"email": mail.strip_edges()})


func reset_password(mail: String, code: String, new_password: String) -> Dictionary:
	return await _call(HTTPClient.METHOD_POST, "/auth/reset-password",
		{"email": mail.strip_edges(), "code": code.strip_edges(), "newPassword": new_password})


func login(mail: String, password: String) -> Dictionary:
	var res := await _call(HTTPClient.METHOD_POST, "/auth/login", {"email": mail.strip_edges(), "password": password})
	if res.ok:
		email = mail.strip_edges()
		active_profile_id = ""
		_apply_tokens(res.data)
		session_changed.emit()
	return res


## Sunucuda tüm yenileme belirteçlerini geçersiz kılar (çevrimdışıysa yerelde çıkış yapılır).
func logout() -> void:
	if is_logged_in():
		await _call(HTTPClient.METHOD_POST, "/auth/logout", null, true)
	_clear()


func delete_account(password: String) -> Dictionary:
	var res := await _call(HTTPClient.METHOD_POST, "/account/delete", {"password": password}, true)
	if res.ok:
		_clear()
	return res


func set_active_profile(profile_id: String) -> void:
	active_profile_id = profile_id
	_save_session()


# --- Profiller ve ilerleme ---------------------------------------------------

func list_profiles() -> Dictionary:
	return await _call(HTTPClient.METHOD_GET, "/profiles", null, true)


func create_profile(nickname: String, grade: int, character_id: String) -> Dictionary:
	return await _call(HTTPClient.METHOD_POST, "/profiles",
		{"nickname": nickname, "grade": grade, "characterId": character_id}, true)


func update_profile(profile_id: String, nickname: String, grade: int, character_id: String) -> Dictionary:
	return await _call(HTTPClient.METHOD_PUT, "/profiles/" + profile_id,
		{"nickname": nickname, "grade": grade, "characterId": character_id}, true)


func get_save(profile_id: String) -> Dictionary:
	return await _call(HTTPClient.METHOD_GET, "/profiles/%s/save" % profile_id, null, true)


func put_save(profile_id: String, progress: Dictionary) -> Dictionary:
	return await _call(HTTPClient.METHOD_PUT, "/profiles/%s/save" % profile_id, progress, true)


# --- HTTP --------------------------------------------------------------------

func _call(method: int, path: String, body: Variant = null, auth := false) -> Dictionary:
	if auth:
		var token_error := await _ensure_access_token()
		if not token_error.is_empty():
			return _result(0 if token_error == "NET_OFFLINE" else 401, null, token_error)
	var res := await _send(method, API + path, body, auth)
	if auth and res.status == 401:
		# Erişim belirteci sunucuda reddedildi: bir kez yenileyip tekrar dene.
		_access_token = ""
		var token_error := await _ensure_access_token()
		if not token_error.is_empty():
			return _result(401, null, token_error)
		res = await _send(method, API + path, body, auth)
	return res


## Boş dize = geçerli belirteç var. Aksi halde hata anahtarı (NET_OFFLINE / SESSION_EXPIRED).
func _ensure_access_token() -> String:
	if not _access_token.is_empty() and _now() < _access_expires_at - REFRESH_MARGIN_SEC:
		return ""
	if _refresh_token.is_empty():
		return "SESSION_EXPIRED"
	var res := await _send(HTTPClient.METHOD_POST, API + "/auth/refresh", {"refreshToken": _refresh_token}, false)
	if res.ok:
		_apply_tokens(res.data)
		return ""
	if res.status == 0:
		return "NET_OFFLINE"  # Çevrimdışı: oturumu koru, sonra tekrar denenir.
	_expire_session()
	return "SESSION_EXPIRED"


func _send(method: int, url_path: String, body: Variant, auth: bool) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = TIMEOUT_SEC
	if _allow_dev_certificate():
		# Yalnızca debug derlemede: yerel ağdaki API'nin .NET geliştirme sertifikası kabul edilir.
		http.set_tls_options(TLSOptions.client_unsafe())
	add_child(http)
	var headers := PackedStringArray(["Content-Type: application/json", "Accept: application/json"])
	if auth:
		headers.append("Authorization: Bearer " + _access_token)
	var payload := "" if body == null else JSON.stringify(body)
	if http.request(base_url() + url_path, headers, method, payload) != OK:
		http.queue_free()
		return _result(0, null)
	var r: Array = await http.request_completed
	http.queue_free()
	if r[0] != HTTPRequest.RESULT_SUCCESS:
		return _result(0, null)
	var text := (r[3] as PackedByteArray).get_string_from_utf8()
	return _result(r[1], JSON.parse_string(text) if not text.is_empty() else null)


static func _result(status: int, data: Variant, error_key := "") -> Dictionary:
	var ok := status >= 200 and status < 300 and error_key.is_empty()
	return {
		"ok": ok,
		"status": status,
		"data": data,
		"code": data.get("code", "") if data is Dictionary else "",
		"error": "" if ok else error_message(status, data, error_key),
	}


## Kullanıcıya gösterilecek Türkçe hata. Sunucu mesajları zaten Türkçedir.
static func error_message(status: int, data: Variant, error_key := "") -> String:
	if not error_key.is_empty():
		return TranslationServer.translate(error_key)
	if status == 0:
		return TranslationServer.translate("NET_OFFLINE")
	if data is Dictionary:
		if data.get("errors") is Dictionary and not data.errors.is_empty():
			var lines := PackedStringArray()
			for field in data.errors:
				for msg in data.errors[field]:
					lines.append(str(msg))
			return "\n".join(lines)
		if data.get("detail") is String:
			return data.detail
	if status == 429:
		return TranslationServer.translate("NET_TOO_MANY")
	return TranslationServer.translate("NET_ERROR")


func _apply_tokens(data: Variant) -> void:
	if not (data is Dictionary and data.has("accessToken") and data.has("refreshToken")):
		return
	_access_token = data.accessToken
	_refresh_token = data.refreshToken
	_access_expires_at = _now() + float(data.get("expiresIn", 0))
	_save_session()


func _expire_session() -> void:
	_access_token = ""
	_refresh_token = ""
	_save_session()
	session_expired.emit()
	session_changed.emit()


func _clear() -> void:
	email = ""
	active_profile_id = ""
	_access_token = ""
	_refresh_token = ""
	SessionStore.clear()
	session_changed.emit()


func _save_session() -> void:
	SessionStore.write({"email": email, "refreshToken": _refresh_token, "activeProfileId": active_profile_id})


func _now() -> float:
	return Time.get_unix_time_from_system()
