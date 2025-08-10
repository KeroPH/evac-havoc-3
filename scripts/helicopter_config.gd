extends Resource
class_name HelicopterConfig

# Display name for the helicopter type
export(String) var name : String = "Balanced"

# Movement & control
export(float) var move_speed : float = 400.0
export(float) var move_angle : float = 23.0 # degrees of tilt at full lateral input
export(float) var velocity_lerp : float = 0.10
export(float) var rotation_lerp : float = 0.04

# Fuel
export(float) var fuel_max : float = 500.0
export(float) var fuel_drain_ground : float = 0.03
export(float) var fuel_drain_down : float = 0.04
export(float) var fuel_drain_up : float = 0.09
export(float) var fuel_drain_side : float = 0.07
export(float) var fuel_drain_hover : float = 0.05

# Behavior when out of fuel
export(float) var fall_speed_out_of_fuel : float = 3.0

# Optional visuals per type
export(Texture) var body_texture
export(Texture) var top_prop_texture
export(Texture) var back_prop_texture
export(SpriteFrames) var top_prop_frames
export(SpriteFrames) var back_prop_frames
