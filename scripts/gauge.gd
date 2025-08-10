extends Control

const EMPTY_ANGLE : float = -PI / 3.0

onready var needle = $needle

func _on_fuel_update(percentage : float):
	# Guard against invalid values
	var pct := clamp(percentage, 0.0, 1.0)
	needle.rotation = lerp_angle(EMPTY_ANGLE, -EMPTY_ANGLE, pct)

	# Play a warning beep when low on fuel; stop otherwise
	if pct > 0.0 and pct < 0.15:
		if not $warning_audio.playing:
			$warning_audio.play()
	else:
		if $warning_audio.playing:
			$warning_audio.stop()
