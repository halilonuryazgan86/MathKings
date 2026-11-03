class_name OffscreenPause
extends RefCounted
## Ekran dışındaki nesnelerin _process'ini durdurur (bölümde onlarca animasyonlu nesne var).


static func make(rect: Rect2) -> VisibleOnScreenEnabler2D:
	var enabler := VisibleOnScreenEnabler2D.new()
	enabler.rect = rect
	enabler.enable_node_path = NodePath("..")
	enabler.enable_mode = VisibleOnScreenEnabler2D.ENABLE_MODE_INHERIT
	return enabler
