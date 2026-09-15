-- ============================================================
-- FS25_VehicleDynamicsControlSystems.lua
-- by Marcus (Cobra Modding)
-- 
--
-- Version 1.0.0.0
--
--
-- Keine Änderung am Skript ohne meine Erlaubnis
-- ============================================================

VehicleDynamicsControlSystems = VehicleDynamicsControlSystems or {}

local SYS = VehicleDynamicsControlSystems
local CFG = VehicleDynamicsControlConfig or {}

SYS.VERSION = "1.0.0.1"
SYS.PREFIX = "[VehicleDynamicsControl] "
SYS.wheelStates = SYS.wheelStates or setmetatable({}, {__mode="k"})
SYS.vehicleStates = SYS.vehicleStates or setmetatable({}, {__mode="k"})
SYS.installed = SYS.installed or false
SYS.boggingRuntimeSeen = SYS.boggingRuntimeSeen or false


local function cfg(name, defaultValue)
    local v = CFG[name]
    if v == nil then return defaultValue end
    return v
end


local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end


local function sign(v)
    if v > 0 then return 1 end
    if v < 0 then return -1 end
    return 0
end


local function logInfo(fmt, ...)
    local msg = string.format(fmt, ...)
    if Logging ~= nil and Logging.info ~= nil then
        Logging.info("%s%s", SYS.PREFIX, msg)
    else
        print(SYS.PREFIX .. msg)
    end
end


local function logWarning(fmt, ...)
    local msg = string.format(fmt, ...)
    if Logging ~= nil and Logging.warning ~= nil then
        Logging.warning("%s%s", SYS.PREFIX, msg)
    else
        print(SYS.PREFIX .. "WARNING: " .. msg)
    end
end


function SYS:isPlayerVehicle(vehicle)
    if vehicle == nil then return false end
    if vehicle.getIsVehicleControlledByPlayer ~= nil then
        return vehicle:getIsVehicleControlledByPlayer()
    end
    return true
end


function SYS:diagAllowed(vehicle)
    if not cfg("DIAGNOSTIC", true) then return false end
    if cfg("DIAG_PLAYER_ONLY", true) and not self:isPlayerVehicle(vehicle) then
        return false
    end
    return true
end


function SYS:getWheelState(physics)
    local state = self.wheelStates[physics]
    if state == nil then
        state = {
            absPressure = 1.0,
            asrTorqueFactor = 1.0,
            espBrakeFactor = 0.0,
            brakeSlip = 0.0,
            driveSlip = 0.0,
            wheelSpeedKmh = 0.0,
            vehicleSpeedKmh = 0.0,
            boggingProtected = false,
            lastAbsLog = -1000000,
            lastAsrLog = -1000000,
            lastAsrDiag = -1000000
        }
        self.wheelStates[physics] = state
    end
    return state
end


function SYS:getVehicleState(vehicle)
    local state = self.vehicleStates[vehicle]
    if state == nil then
        state = {
            lastUpdateTime = -1,
            yawSign = nil,
            desiredYaw = 0.0,
            actualYaw = 0.0,
            espMode = nil,
            espTargetPhysics = nil,
            espBrakeFactor = 0.0,
            lastESPLog = -1000000,
            lastESPDiag = -1000000,
            lastBoggingLog = -1000000,
            lastASRMotorLog = -1000000,
            lastASRInputLog = -1000000,
            ttdDataTime = -1,
            ttdData = nil,
            active = {ABS=-1000000, ASR=-1000000, ESP=-1000000}
        }
        self.vehicleStates[vehicle] = state
    end
    return state
end


function SYS:getActivityVehicle(vehicle)
    if vehicle == nil then
        return nil
    end

    if vehicle.getRootVehicle ~= nil then
        local ok, root = pcall(vehicle.getRootVehicle, vehicle)
        if ok and root ~= nil then
            return root
        end
    end

    return vehicle
end


function SYS:markActive(vehicle, systemName)
    local activityVehicle = self:getActivityVehicle(vehicle)
    if activityVehicle == nil then return end

    local vs = self:getVehicleState(activityVehicle)
    vs.active[systemName] = g_time or 0
end


function SYS:isRecentlyActive(vehicle, systemName, holdMs)
    local activityVehicle = self:getActivityVehicle(vehicle)
    if activityVehicle == nil then return false end

    local vs = self.vehicleStates[activityVehicle]
    if vs == nil or vs.active == nil then return false end

    local t = vs.active[systemName] or -1000000
    return (g_time or 0) - t <= (holdMs or 1000)
end


function SYS:isExcludedVehicle(vehicle)
    if vehicle == nil then return false end

    local modName = "fs25_lsfmfarmequipmentpack"
    if type(vehicle.customEnvironment) == "string"
        and string.lower(vehicle.customEnvironment) == modName then
        return true
    end

    local function matchesPath(value)
        if type(value) ~= "string" then return false end
        local path = "/" .. string.lower(value):gsub("\\", "/") .. "/"
        return path:find("/" .. modName .. "/", 1, true) ~= nil
            or path:find("/" .. modName .. ".zip/", 1, true) ~= nil
    end

    return matchesPath(vehicle.configFileName) or matchesPath(vehicle.baseDirectory)
end


function SYS:isEligibleVehicle(vehicle)
    if vehicle == nil then return false end
    if self:isExcludedVehicle(vehicle) then return false end
    if cfg("MOTORIZED_ONLY", true) and vehicle.spec_motorized == nil then
        return false
    end
    if cfg("PLAYER_ONLY", false) then
        if vehicle.getIsVehicleControlledByPlayer == nil
            or not vehicle:getIsVehicleControlledByPlayer() then
            return false
        end
    end
    return vehicle.spec_wheels ~= nil
end


function SYS:isBoggingStateActive(soil)
    if not cfg("BOGGING_COMPATIBILITY", true) or soil == nil then
        return false
    end

    if not self.boggingRuntimeSeen then
        self.boggingRuntimeSeen = true
        logInfo("RealisticBogging runtime soil detected (rbSoil) - compatibility active")
    end

    local wetness = soil.wetness or 0
    local risk = soil.risk or 0
    local depth = soil.depth or 0

    return wetness > cfg("BOGGING_MIN_WETNESS", 0.32)
        and (risk >= cfg("BOGGING_MIN_RISK", 0.08)
            or depth >= cfg("BOGGING_MIN_DEPTH", 0.03))
end


function SYS:isWheelBoggingProtected(physics)
    return physics ~= nil and self:isBoggingStateActive(physics.rbSoil)
end


function SYS:isVehicleBoggingProtected(vehicle)
    if vehicle == nil or vehicle.spec_wheels == nil then return false end
    for _, wheel in ipairs(vehicle.spec_wheels.wheels) do
        if wheel.physics ~= nil and self:isWheelBoggingProtected(wheel.physics) then
            return true
        end
    end
    return false
end


function SYS:getTTDData(vehicle)
    if not cfg("TTD_COMPATIBILITY", true)
        or vehicle == nil
        or vehicle.spec_tractorTerrainDynamics == nil then
        return nil
    end

    local vs = self:getVehicleState(vehicle)
    local now = g_time or 0
    if vs.ttdDataTime == now then
        return vs.ttdData
    end

    local raw = nil

    if g_TTD_Shared ~= nil
        and type(g_TTD_Shared.getSharedData) == "function" then
        local ok, data = pcall(g_TTD_Shared.getSharedData, vehicle)
        if ok and type(data) == "table" then
            raw = data
        end
    end

    local spec = vehicle.spec_tractorTerrainDynamics
    local ground = spec.groundData or {}

    if raw == nil then
        raw = {
            moisture = ground.moisture,
            onField = ground.onField,
            slip = ground.slipIntensity,
            groundType = ground.groundTypeValue,
            currentState = spec.currentTTDState
        }
    end

    local currentState = raw.currentState or spec.currentTTDState or "unknown"

    local onField = raw.onField
    if onField == nil then
        onField = currentState == "field"
    end

    local sink = 0.0
    if g_TTD_WheelSinkSystem ~= nil
        and type(g_TTD_WheelSinkSystem.getAverageSink) == "function" then
        local okSink, value = pcall(g_TTD_WheelSinkSystem.getAverageSink, vehicle)
        if okSink and type(value) == "number" then
            sink = value
        end
    elseif type(vehicle.getAverageSink) == "function" then
        local okSink, value = pcall(vehicle.getAverageSink, vehicle)
        if okSink and type(value) == "number" then
            sink = value
        end
    end

    local data = {
        moisture = clamp(tonumber(raw.moisture) or 0.2, 0.0, 1.0),
        onField = onField == true and currentState ~= "road",
        slip = clamp(tonumber(raw.slip) or 0.0, 0.0, 1.0),
        groundType = tonumber(raw.groundType) or 5,
        currentState = currentState,
        sink = math.max(tonumber(raw.sink) or sink or 0.0, 0.0)
    }

    vs.ttdDataTime = now
    vs.ttdData = data
    return data
end


function SYS:getTTDASRTuning(vehicle)
    local releaseSlip = cfg("ASR_RELEASE_SLIP", 0.12)
    local reapplySlip = cfg("ASR_REAPPLY_SLIP", 0.06)
    local minFactor = cfg("ASR_MIN_TORQUE_FACTOR", 0.35)
    local releaseRate = cfg("ASR_RELEASE_RATE", 4.0)
    local reapplyRate = cfg("ASR_REAPPLY_RATE", 2.5)

    local data = self:getTTDData(vehicle)
    if data == nil or not data.onField then
        return releaseSlip, reapplySlip, minFactor, releaseRate, reapplyRate, nil
    end

    local expectedSlip = clamp(data.slip, 0.0, 0.50)

    local ttdRelease = expectedSlip * cfg("TTD_ASR_SLIP_FACTOR", 0.65)
        + cfg("TTD_ASR_SLIP_MARGIN", 0.04)

    releaseSlip = clamp(
        math.max(releaseSlip, ttdRelease),
        cfg("ASR_RELEASE_SLIP", 0.12),
        cfg("TTD_ASR_MAX_RELEASE_SLIP", 0.28)
    )

    reapplySlip = clamp(
        releaseSlip * 0.55,
        cfg("ASR_REAPPLY_SLIP", 0.06),
        math.max(releaseSlip - 0.02, cfg("ASR_REAPPLY_SLIP", 0.06))
    )

    minFactor = math.max(
        minFactor,
        cfg("TTD_ASR_MIN_TORQUE_FACTOR", 0.50)
    )

    releaseRate = math.min(
        releaseRate,
        cfg("TTD_ASR_RELEASE_RATE", 2.5)
    )

    reapplyRate = math.max(
        reapplyRate,
        cfg("TTD_ASR_REAPPLY_RATE", 3.5)
    )

    return releaseSlip, reapplySlip, minFactor, releaseRate, reapplyRate, data
end


function SYS:getABSThresholds(vehicle, boggingProtected)
    if boggingProtected then
        return
            cfg("ABS_BOGGING_RELEASE_SLIP", 0.30),
            cfg("ABS_BOGGING_REAPPLY_SLIP", 0.15)
    end

    local releaseSlip = cfg("ABS_RELEASE_SLIP", 0.18)
    local reapplySlip = cfg("ABS_REAPPLY_SLIP", 0.09)

    local data = self:getTTDData(vehicle)
    if data ~= nil and data.onField then
        releaseSlip = math.max(
            releaseSlip,
            cfg("TTD_ABS_RELEASE_SLIP", 0.28)
        )
        reapplySlip = math.max(
            reapplySlip,
            cfg("TTD_ABS_REAPPLY_SLIP", 0.14)
        )
    end

    return releaseSlip, reapplySlip
end


function SYS:shouldSuppressESPForTTD(vehicle)
    local data = self:getTTDData(vehicle)
    if data == nil or not data.onField then
        return false
    end

    return data.slip >= cfg("TTD_ESP_MIN_SLIP", 0.12)
        or data.moisture >= cfg("TTD_ESP_MIN_MOISTURE", 0.55)
        or data.sink >= cfg("TTD_ESP_MIN_SINK_PERCENT", 5.0)
end


function SYS:getWheelLocalPosition(vehicle, wheel)
    if vehicle == nil or vehicle.rootNode == nil or wheel == nil
        or localToLocal == nil then
        return nil
    end

    local positionNode = wheel.driveNode or wheel.repr
    if positionNode == nil or positionNode == 0 then
        return nil
    end

    local rootNode = vehicle.rootNode
    local ok, x, y, z = pcall(localToLocal, positionNode, rootNode, 0, 0, 0)
    if not ok then return nil end
    return x, y, z
end


function SYS:espDiag(vehicle, vs, reason, fmt, ...)
    if not self:diagAllowed(vehicle) then return end

    local now = g_time or 0
    if now - (vs.lastESPDiag or -1000000) < cfg("ESP_DIAG_INTERVAL_MS", 700) then
        return
    end
    vs.lastESPDiag = now

    local extra = ""
    if fmt ~= nil then
        extra = " " .. string.format(fmt, ...)
    end
    logInfo("ESP DIAG reason=%s%s", tostring(reason), extra)
end


function SYS:selectESPWheel(vehicle, wantFront, sideSign)
    local spec = vehicle.spec_wheels
    if spec == nil then return nil end

    local infos = {}
    local minX, maxX = math.huge, -math.huge
    local minZ, maxZ = math.huge, -math.huge

    for _, wheel in ipairs(spec.wheels) do
        local physics = wheel.physics
        if physics ~= nil and physics.hasGroundContact == true then
            local x, _, z = self:getWheelLocalPosition(vehicle, wheel)
            if x ~= nil and z ~= nil then
                minX, maxX = math.min(minX, x), math.max(maxX, x)
                minZ, maxZ = math.min(minZ, z), math.max(maxZ, z)
                infos[#infos+1] = {wheel=wheel, physics=physics, x=x, z=z}
            end
        end
    end

    if #infos == 0 then return nil end

    local centerX = (minX + maxX) * 0.5
    local centerZ = (minZ + maxZ) * 0.5
    local halfX = math.max((maxX - minX) * 0.5, 0.25)
    local halfZ = math.max((maxZ - minZ) * 0.5, 0.50)

    local bestPhysics, bestScore = nil, -math.huge
    for _, info in ipairs(infos) do
        local nx = (info.x - centerX) / halfX
        local nz = (info.z - centerZ) / halfZ
        local frontScore = wantFront and nz or -nz
        local sideScore = sideSign * nx
        local score = frontScore * 2.0 + sideScore
        if score > bestScore then
            bestScore = score
            bestPhysics = info.physics
        end
    end

    return bestPhysics
end


function SYS:computeESP(vehicle, dt)
    local vs = self:getVehicleState(vehicle)
    local now = g_time or 0

    if vs.lastUpdateTime == now then return end
    vs.lastUpdateTime = now
    vs.espMode = nil
    vs.espTargetPhysics = nil
    vs.espBrakeFactor = 0.0
    vs.desiredYaw = 0.0
    vs.actualYaw = 0.0

    if not cfg("ESP_ENABLED", true) then
        self:espDiag(vehicle, vs, "disabled")
        return
    end
    if not self:isEligibleVehicle(vehicle) then return end
    if vehicle.isServer ~= true or vehicle.isAddedToPhysics ~= true then
        self:espDiag(vehicle, vs, "notServerOrPhysics")
        return
    end
    if vehicle.rootNode == nil then
        self:espDiag(vehicle, vs, "noRootNode")
        return
    end

    local speedKmh = math.abs(vehicle:getLastSpeed() or 0)
    if speedKmh < cfg("ESP_MIN_SPEED_KMH", 18.0) then
        if speedKmh > 10 then
            self:espDiag(vehicle, vs, "speedLow", "speed=%.1f", speedKmh)
        end
        return
    end

    if self:isVehicleBoggingProtected(vehicle) then
        self:espDiag(vehicle, vs, "boggingSuppressed", "speed=%.1f", speedKmh)
        return
    end

    if self:shouldSuppressESPForTTD(vehicle) then
        self:espDiag(vehicle, vs, "ttdTerrainSuppressed", "speed=%.1f", speedKmh)
        return
    end

    local spec = vehicle.spec_wheels
    local steerSum, steerCount = 0.0, 0
    local minZ, maxZ = math.huge, -math.huge
    local steeringSamples = {}

    for _, wheel in ipairs(spec.wheels) do
        local p = wheel.physics
        if p ~= nil then
            local _, _, z = self:getWheelLocalPosition(vehicle, wheel)
            if z ~= nil then
                minZ, maxZ = math.min(minZ, z), math.max(maxZ, z)
            end

            local rotMin = p.rotMin or 0
            local rotMax = p.rotMax or 0
            local angle = p.steeringAngle

            if type(angle) == "number" then
                steeringSamples[#steeringSamples+1] =
                    string.format("%s:%.4f[%.3f..%.3f]",
                        tostring(wheel.wheelIndex or "?"), angle, rotMin, rotMax)
            end

            if math.abs(rotMax - rotMin) > 0.01 and type(angle) == "number" then
                steerSum = steerSum + angle
                steerCount = steerCount + 1
            end
        end
    end

    if steerCount == 0 then
        self:espDiag(
            vehicle, vs, "noSteerableWheels",
            "samples=%s", table.concat(steeringSamples, ",")
        )
        return
    end

    if minZ == math.huge or maxZ == -math.huge then
        self:espDiag(vehicle, vs, "noWheelPositions")
        return
    end

    local avgSteer = steerSum / steerCount
    if math.abs(avgSteer) < cfg("ESP_MIN_STEER_RAD", 0.025) then
        self:espDiag(
            vehicle, vs, "steerBelowThreshold",
            "avgSteer=%.5f count=%d samples=%s",
            avgSteer, steerCount, table.concat(steeringSamples, ",")
        )
        return
    end

    local wheelbase = maxZ - minZ
    if wheelbase < 1.2 then
        self:espDiag(
            vehicle, vs, "wheelbaseInvalid",
            "wheelbase=%.3f minZ=%.3f maxZ=%.3f",
            wheelbase, minZ, maxZ
        )
        return
    end

    if getAngularVelocity == nil then
        self:espDiag(vehicle, vs, "getAngularVelocityMissing")
        return
    end

    local okYaw, wx, wy, wz = pcall(getAngularVelocity, vehicle.rootNode)
    if not okYaw or type(wy) ~= "number" then
        self:espDiag(
            vehicle, vs, "yawUnavailable",
            "ok=%s wx=%s wy=%s wz=%s",
            tostring(okYaw), tostring(wx), tostring(wy), tostring(wz)
        )
        return
    end

    local yawRate = wy
    local speedMps = speedKmh / 3.6
    local rawDesired = speedMps / wheelbase * math.tan(avgSteer)

    if vs.yawSign == nil
        and math.abs(rawDesired) > 0.03
        and math.abs(yawRate) > 0.03 then
        vs.yawSign = sign(yawRate * rawDesired)
        if vs.yawSign == 0 then vs.yawSign = 1 end
        logInfo(
            "ESP yaw sign calibrated: %d (steer=%.4f yaw=%.4f desiredRaw=%.4f wheelbase=%.2f)",
            vs.yawSign, avgSteer, yawRate, rawDesired, wheelbase
        )
    end

    if vs.yawSign == nil then
        self:espDiag(
            vehicle, vs, "calibrationWaiting",
            "speed=%.1f steer=%.4f yaw=%.4f rawDesired=%.4f wheelbase=%.2f",
            speedKmh, avgSteer, yawRate, rawDesired, wheelbase
        )
        return
    end

    local desiredYaw = clamp(
        rawDesired * vs.yawSign,
        -cfg("ESP_MAX_DESIRED_YAW", 1.35),
        cfg("ESP_MAX_DESIRED_YAW", 1.35)
    )

    if math.abs(desiredYaw) < 0.03 then
        self:espDiag(
            vehicle, vs, "desiredYawTooSmall",
            "desired=%.4f actual=%.4f steer=%.4f",
            desiredYaw, yawRate, avgSteer
        )
        return
    end

    vs.desiredYaw = desiredYaw
    vs.actualYaw = yawRate

    local turnSign = sign(desiredYaw)
    local actualAlongTurn = yawRate * turnSign
    local desiredMagnitude = math.abs(desiredYaw)
    local yawError = actualAlongTurn - desiredMagnitude

    local mode, targetPhysics, threshold

    if yawError > cfg("ESP_OVERSTEER_ERROR", 0.16) then
        mode = "OVERSTEER"
        targetPhysics = self:selectESPWheel(vehicle, true, -turnSign)
        threshold = cfg("ESP_OVERSTEER_ERROR", 0.16)
    elseif yawError < -cfg("ESP_UNDERSTEER_ERROR", 0.20) then
        mode = "UNDERSTEER"
        targetPhysics = self:selectESPWheel(vehicle, false, turnSign)
        threshold = cfg("ESP_UNDERSTEER_ERROR", 0.20)
    else
        self:espDiag(
            vehicle, vs, "withinYawThreshold",
            "speed=%.1f steer=%.4f desired=%.4f actual=%.4f error=%.4f",
            speedKmh, avgSteer, desiredYaw, yawRate, yawError
        )
        return
    end

    if targetPhysics == nil then
        self:espDiag(
            vehicle, vs, "noTargetWheel",
            "mode=%s error=%.4f", tostring(mode), yawError
        )
        return
    end

    local excess = math.max(math.abs(yawError) - threshold, 0)
    local brakeFactor = clamp(
        cfg("ESP_MIN_BRAKE_FACTOR", 0.06) + excess * cfg("ESP_ERROR_GAIN", 0.35),
        cfg("ESP_MIN_BRAKE_FACTOR", 0.06),
        cfg("ESP_MAX_BRAKE_FACTOR", 0.32)
    )

    vs.espMode = mode
    vs.espTargetPhysics = targetPhysics
    vs.espBrakeFactor = brakeFactor
end


function SYS.onServerUpdate(physics, dt, currentUpdateIndex, groundWetness)
    local vehicle = physics.vehicle
    local wheel = physics.wheel
    local state = SYS:getWheelState(physics)

    state.espBrakeFactor = 0.0

    if vehicle == nil or wheel == nil
        or not SYS:isEligibleVehicle(vehicle)
        or vehicle.isServer ~= true
        or vehicle.isAddedToPhysics ~= true then
        state.absPressure = 1.0
        state.asrTorqueFactor = 1.0
        return
    end

    SYS:computeESP(vehicle, dt)

    local vs = SYS:getVehicleState(vehicle)
    if vs.espTargetPhysics == physics then
        state.espBrakeFactor = vs.espBrakeFactor or 0.0
    end

    local speedKmh = math.abs(vehicle:getLastSpeed() or 0)
    state.vehicleSpeedKmh = speedKmh
    state.boggingProtected = SYS:isWheelBoggingProtected(physics)

    if physics.wheelShape == nil
        or physics.wheelShape == 0
        or physics.hasGroundContact ~= true then
        state.absPressure = 1.0
        state.asrTorqueFactor = 1.0
        return
    end

    local okAxle, axleSpeed = pcall(
        getWheelShapeAxleSpeed,
        wheel.node,
        physics.wheelShape
    )
    if not okAxle or type(axleSpeed) ~= "number" then
        state.absPressure = 1.0
        state.asrTorqueFactor = 1.0
        return
    end

    local radius = physics.radius or 0.5
    local wheelSpeedMps = math.abs(axleSpeed * radius)
    local vehicleSpeedMps = speedKmh / 3.6

    state.wheelSpeedKmh = wheelSpeedMps * 3.6
    state.brakeSlip = clamp(
        (vehicleSpeedMps - wheelSpeedMps) / math.max(vehicleSpeedMps, 0.5),
        0.0, 1.0
    )

    local asrReferenceSpeedMps = vehicleSpeedMps

    if cfg("ASR_CURVE_COMPENSATION", true)
        and getAngularVelocity ~= nil
        and vehicle.rootNode ~= nil then

        local okYaw, _, yawRate, _ = pcall(getAngularVelocity, vehicle.rootNode)
        if okYaw and type(yawRate) == "number" then
            local localX = nil
            local x = SYS:getWheelLocalPosition(vehicle, wheel)
            if x ~= nil then
                localX = x
            end

            if localX ~= nil then
                local curveExtraMps = math.abs(yawRate) * math.abs(localX)
                local maxCurveExtraMps =
                    cfg("ASR_CURVE_COMP_MAX_KMH", 20.0) / 3.6

                curveExtraMps = math.min(curveExtraMps, maxCurveExtraMps)
                asrReferenceSpeedMps =
                    asrReferenceSpeedMps + curveExtraMps
            end
        end
    end

    state.driveSlip = clamp(
        (wheelSpeedMps - asrReferenceSpeedMps) / math.max(wheelSpeedMps, 0.5),
        0.0, 1.0
    )

    local dtSeconds = clamp((dt or 16.667) * 0.001, 0.001, 0.1)

    local driverBrake = math.max(wheel.brakePedal or 0.0, 0.0)
    local effectiveBrake = math.max(driverBrake, state.espBrakeFactor or 0.0)

    if cfg("ABS_ENABLED", true)
        and speedKmh >= cfg("ABS_MIN_SPEED_KMH", 7.0)
        and effectiveBrake >= cfg("ABS_MIN_BRAKE", 0.10) then

        local releaseSlip, reapplySlip =
            SYS:getABSThresholds(vehicle, state.boggingProtected)

        if state.brakeSlip >= releaseSlip then
            state.absPressure = math.max(
                cfg("ABS_MIN_PRESSURE", 0.08),
                state.absPressure - cfg("ABS_RELEASE_RATE", 12.0) * dtSeconds
            )
        elseif state.brakeSlip <= reapplySlip then
            state.absPressure = math.min(
                1.0,
                state.absPressure + cfg("ABS_REAPPLY_RATE", 4.0) * dtSeconds
            )
        end
    else
        state.absPressure = 1.0
    end

    if cfg("ASR_ENABLED", true)
        and speedKmh >= cfg("ASR_MIN_SPEED_KMH", 3.0)
        and not state.boggingProtected then

        local releaseSlip, reapplySlip, minFactor, releaseRate, reapplyRate =
            SYS:getTTDASRTuning(vehicle)

        if state.driveSlip >= releaseSlip then
            state.asrTorqueFactor = math.max(
                minFactor,
                state.asrTorqueFactor - releaseRate * dtSeconds
            )
        elseif state.driveSlip <= reapplySlip then
            state.asrTorqueFactor = math.min(
                1.0,
                state.asrTorqueFactor + reapplyRate * dtSeconds
            )
        end
    else
        state.asrTorqueFactor = 1.0
    end
end


function SYS:getVehicleASRFactor(vehicle)
    if vehicle == nil
        or not cfg("ASR_ENABLED", true)
        or not self:isEligibleVehicle(vehicle) then
        return 1.0
    end

    if self:isVehicleBoggingProtected(vehicle) then
        return 1.0
    end

    local factor = 1.0
    local spec = vehicle.spec_wheels
    if spec == nil then
        return factor
    end

    for _, wheel in ipairs(spec.wheels) do
        local physics = wheel.physics
        if physics ~= nil then
            local state = self.wheelStates[physics]
            if state ~= nil and not state.boggingProtected then
                factor = math.min(factor, state.asrTorqueFactor or 1.0)
            end
        end
    end

    return clamp(
        factor,
        cfg("ASR_MIN_TORQUE_FACTOR", 0.35),
        1.0
    )
end



function SYS.updateWheelsPhysics(vehicle, superFunc, dt, currentSpeed, acceleration, doHandbrake, stopAndGoBraking)
    local adjustedAcceleration = acceleration

    if vehicle ~= nil
        and cfg("ASR_ENABLED", true)
        and SYS:isEligibleVehicle(vehicle)
        and acceleration ~= nil
        and math.abs(acceleration) >= cfg("ASR_MIN_ACCELERATION", 0.05) then

        local factor = SYS:getVehicleASRFactor(vehicle)

        if factor < 0.999 then
            adjustedAcceleration = acceleration * factor
            SYS:markActive(vehicle, "ASR")

            if cfg("DEBUG", true) then
                local vs = SYS:getVehicleState(vehicle)
                local now = g_time or 0

                if now - (vs.lastASRInputLog or -1000000)
                    >= cfg("ASR_INPUT_DIAG_INTERVAL_MS", 300) then

                    vs.lastASRInputLog = now

                    local maxSlip = 0.0
                    local maxWheel = "?"
                    if vehicle.spec_wheels ~= nil then
                        for _, wheel in ipairs(vehicle.spec_wheels.wheels) do
                            local physics = wheel.physics
                            local state = physics ~= nil and SYS.wheelStates[physics] or nil
                            if state ~= nil and (state.driveSlip or 0.0) > maxSlip then
                                maxSlip = state.driveSlip or 0.0
                                maxWheel = tostring(wheel.wheelIndex or "?")
                            end
                        end
                    end

                    logInfo(
                        "ASR ACTIVE inputFactor=%.0f%% accelIn=%.3f accelOut=%.3f maxSlip=%.1f%% wheel=%s",
                        factor * 100.0,
                        acceleration,
                        adjustedAcceleration,
                        maxSlip * 100.0,
                        maxWheel
                    )
                end
            end
        end
    end

    return superFunc(
        vehicle,
        dt,
        currentSpeed,
        adjustedAcceleration,
        doHandbrake,
        stopAndGoBraking
    )
end


function SYS.updatePhysics(physics, superFunc, brakeForce, torque)
    local vehicle = physics.vehicle
    local state = SYS.wheelStates[physics]

    if state == nil or vehicle == nil or SYS:isExcludedVehicle(vehicle) then
        return superFunc(physics, brakeForce, torque)
    end

    if SYS:diagAllowed(vehicle)
        and state.vehicleSpeedKmh >= cfg("ASR_MIN_SPEED_KMH", 3.0) then

        local now = g_time or 0
        if now - state.lastAsrDiag >= cfg("ASR_DIAG_INTERVAL_MS", 700) then
            state.lastAsrDiag = now
            logInfo(
                "ASR DIAG wheel=%s speed=%.1f wheelSpeed=%.1f driveSlip=%.1f%% factor=%.0f%% bogProtected=%s",
                tostring(physics.wheel and physics.wheel.wheelIndex or "?"),
                state.vehicleSpeedKmh,
                state.wheelSpeedKmh,
                state.driveSlip * 100.0,
                state.asrTorqueFactor * 100.0,
                tostring(state.boggingProtected)
            )
        end
    end

    local adjustedBrake = math.max(brakeForce or 0.0, 0.0)

    if cfg("ESP_ENABLED", true) and state.espBrakeFactor > 0.0 then
        local fullBrake = 0.0
        if vehicle.getBrakeForce ~= nil then
            fullBrake = math.max(vehicle:getBrakeForce() or 0.0, 0.0)
        end
        adjustedBrake = adjustedBrake + fullBrake * state.espBrakeFactor
        SYS:markActive(vehicle, "ESP")

        if cfg("DEBUG", true) then
            local vs = SYS:getVehicleState(vehicle)
            local now = g_time or 0
            if now - vs.lastESPLog >= cfg("DEBUG_INTERVAL_MS", 400) then
                vs.lastESPLog = now
                logInfo(
                    "ESP ACTIVE mode=%s wheel=%s desiredYaw=%.3f actualYaw=%.3f brake=%.0f%%",
                    tostring(vs.espMode or "?"),
                    tostring(physics.wheel and physics.wheel.wheelIndex or "?"),
                    vs.desiredYaw or 0.0,
                    vs.actualYaw or 0.0,
                    state.espBrakeFactor * 100.0
                )
            end
        end
    end

    if cfg("ABS_ENABLED", true)
        and adjustedBrake > 0
        and state.absPressure < 0.999 then

        adjustedBrake = adjustedBrake * state.absPressure
        SYS:markActive(vehicle, "ABS")

        if cfg("DEBUG", true) then
            local now = g_time or 0
            if now - state.lastAbsLog >= cfg("DEBUG_INTERVAL_MS", 400) then
                state.lastAbsLog = now
                logInfo(
                    "ABS ACTIVE wheel=%s speed=%.1fkm/h brakeSlip=%.1f%% pressure=%.0f%% bogCompat=%s",
                    tostring(physics.wheel and physics.wheel.wheelIndex or "?"),
                    state.vehicleSpeedKmh,
                    state.brakeSlip * 100.0,
                    state.absPressure * 100.0,
                    tostring(state.boggingProtected)
                )
            end
        end
    end

    return superFunc(physics, adjustedBrake, torque)
end


function SYS:loadMap()
    if self.installed then return end

    if WheelPhysics == nil
        or WheelPhysics.serverUpdate == nil
        or WheelPhysics.updatePhysics == nil
        or Utils == nil
        or Utils.prependedFunction == nil
        or Utils.overwrittenFunction == nil then
        logWarning("Unsupported WheelPhysics/Utils API; vehicle safety systems disabled")
        return
    end

    WheelPhysics.serverUpdate =
        Utils.prependedFunction(WheelPhysics.serverUpdate, SYS.onServerUpdate)

    WheelPhysics.updatePhysics =
        Utils.overwrittenFunction(WheelPhysics.updatePhysics, SYS.updatePhysics)

    local asrInputHook = false
    if WheelsUtil ~= nil
        and WheelsUtil.updateWheelsPhysics ~= nil
        and Utils.overwrittenFunction ~= nil then
        WheelsUtil.updateWheelsPhysics =
            Utils.overwrittenFunction(WheelsUtil.updateWheelsPhysics, SYS.updateWheelsPhysics)
        asrInputHook = true
    else
        logWarning("WheelsUtil:updateWheelsPhysics unavailable; ASR output disabled")
    end

    self.installed = true

    logInfo(
        "v%s loaded: ABS=%s ASR=%s ESP=%s ASRInputHook=%s",
        self.VERSION,
        tostring(cfg("ABS_ENABLED", true)),
        tostring(cfg("ASR_ENABLED", true)),
        tostring(cfg("ESP_ENABLED", true)),
        tostring(asrInputHook)
    )
end


function SYS:deleteMap()
    self.wheelStates = setmetatable({}, {__mode="k"})
    self.vehicleStates = setmetatable({}, {__mode="k"})
end


addModEventListener(SYS)
