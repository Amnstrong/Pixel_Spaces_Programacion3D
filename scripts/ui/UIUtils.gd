class_name UIUtils
## Utilidades compartidas por los menús (sonidos en botones).


static func wire_button(button: BaseButton, callback: Callable) -> void:
	button.pressed.connect(func() -> void:
		AudioManager.play_sfx("click")
		callback.call()
	)
	button.mouse_entered.connect(func() -> void:
		if not button.disabled and button.focus_mode != Control.FOCUS_NONE:
			button.grab_focus()
	)
	button.focus_entered.connect(func() -> void: AudioManager.play_sfx("hover"))
