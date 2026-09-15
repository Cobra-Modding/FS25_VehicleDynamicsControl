-- ============================================================
-- FS25_VehicleDynamicsCotrolConfig.lua
-- by Marcus (Cobra Modding)
-- 
--
-- Version 1.0.0.0
--
--
-- Keine Änderung am Skript ohne meine Erlaubnis
-- ============================================================

VehicleDynamicsControlConfig = VehicleDynamicsControlConfig or {}

VehicleDynamicsControlConfig.ABS_ENABLED = true
VehicleDynamicsControlConfig.ASR_ENABLED = true
VehicleDynamicsControlConfig.ESP_ENABLED = true
VehicleDynamicsControlConfig.MOTORIZED_ONLY = true
VehicleDynamicsControlConfig.PLAYER_ONLY = false

VehicleDynamicsControlConfig.ABS_MIN_SPEED_KMH = 7.0
VehicleDynamicsControlConfig.ABS_MIN_BRAKE = 0.10
VehicleDynamicsControlConfig.ABS_RELEASE_SLIP = 0.18
VehicleDynamicsControlConfig.ABS_REAPPLY_SLIP = 0.09
VehicleDynamicsControlConfig.ABS_MIN_PRESSURE = 0.08
VehicleDynamicsControlConfig.ABS_RELEASE_RATE = 12.0
VehicleDynamicsControlConfig.ABS_REAPPLY_RATE = 4.0

VehicleDynamicsControlConfig.ABS_BOGGING_RELEASE_SLIP = 0.30
VehicleDynamicsControlConfig.ABS_BOGGING_REAPPLY_SLIP = 0.15

VehicleDynamicsControlConfig.ASR_MIN_SPEED_KMH = 3.0
VehicleDynamicsControlConfig.ASR_RELEASE_SLIP = 0.12
VehicleDynamicsControlConfig.ASR_REAPPLY_SLIP = 0.06
VehicleDynamicsControlConfig.ASR_MIN_TORQUE_FACTOR = 0.35
VehicleDynamicsControlConfig.ASR_RELEASE_RATE = 4.0
VehicleDynamicsControlConfig.ASR_REAPPLY_RATE = 2.5
VehicleDynamicsControlConfig.ASR_CURVE_COMPENSATION = true
VehicleDynamicsControlConfig.ASR_CURVE_COMP_MAX_KMH = 20.0

VehicleDynamicsControlConfig.ESP_MIN_SPEED_KMH = 18.0
VehicleDynamicsControlConfig.ESP_MIN_STEER_RAD = 0.010
VehicleDynamicsControlConfig.ESP_OVERSTEER_ERROR = 0.16
VehicleDynamicsControlConfig.ESP_UNDERSTEER_ERROR = 0.20
VehicleDynamicsControlConfig.ESP_MIN_BRAKE_FACTOR = 0.06
VehicleDynamicsControlConfig.ESP_MAX_BRAKE_FACTOR = 0.32
VehicleDynamicsControlConfig.ESP_ERROR_GAIN = 0.35
VehicleDynamicsControlConfig.ESP_MAX_DESIRED_YAW = 1.35

VehicleDynamicsControlConfig.BOGGING_COMPATIBILITY = true
VehicleDynamicsControlConfig.BOGGING_MIN_WETNESS = 0.32
VehicleDynamicsControlConfig.BOGGING_MIN_RISK = 0.08
VehicleDynamicsControlConfig.BOGGING_MIN_DEPTH = 0.03

VehicleDynamicsControlConfig.TTD_COMPATIBILITY = true
VehicleDynamicsControlConfig.TTD_ASR_SLIP_FACTOR = 0.65
VehicleDynamicsControlConfig.TTD_ASR_SLIP_MARGIN = 0.04
VehicleDynamicsControlConfig.TTD_ASR_MAX_RELEASE_SLIP = 0.28
VehicleDynamicsControlConfig.TTD_ASR_MIN_TORQUE_FACTOR = 0.50
VehicleDynamicsControlConfig.TTD_ASR_RELEASE_RATE = 2.5
VehicleDynamicsControlConfig.TTD_ASR_REAPPLY_RATE = 3.5

VehicleDynamicsControlConfig.TTD_ABS_RELEASE_SLIP = 0.28
VehicleDynamicsControlConfig.TTD_ABS_REAPPLY_SLIP = 0.14

VehicleDynamicsControlConfig.TTD_ESP_MIN_SLIP = 0.12
VehicleDynamicsControlConfig.TTD_ESP_MIN_MOISTURE = 0.55
VehicleDynamicsControlConfig.TTD_ESP_MIN_SINK_PERCENT = 5.0

VehicleDynamicsControlConfig.HUD_ICON_SIZE_PX = 20
VehicleDynamicsControlConfig.HUD_GAP_PX = 2
VehicleDynamicsControlConfig.HUD_Y_OFFSET_PX = 0
VehicleDynamicsControlConfig.HUD_BLINK_MS = 300
VehicleDynamicsControlConfig.HUD_ACTIVE_HOLD_MS = 1000

VehicleDynamicsControlConfig.DEBUG = false
VehicleDynamicsControlConfig.DEBUG_INTERVAL_MS = 400

VehicleDynamicsControlConfig.DIAGNOSTIC = false
VehicleDynamicsControlConfig.ASR_DIAG_INTERVAL_MS = 700
VehicleDynamicsControlConfig.ESP_DIAG_INTERVAL_MS = 700
VehicleDynamicsControlConfig.DIAG_PLAYER_ONLY = true


VehicleDynamicsControlConfig.ASR_MOTOR_DIAG_INTERVAL_MS = 300
VehicleDynamicsControlConfig.ASR_MIN_ACCELERATION = 0.05

VehicleDynamicsControlConfig.ASR_INPUT_DIAG_INTERVAL_MS = 300
