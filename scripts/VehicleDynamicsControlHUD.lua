-- ============================================================
-- FS25_VehicleDynamicsControlHUD.lua
-- by Marcus (Cobra Modding)
-- 
--
-- Version 1.0.0.0
--
--
-- Keine Änderung am Skript ohne meine Erlaubnis
-- ============================================================

VehicleDynamicsControlHUD = VehicleDynamicsControlHUD or {
    modDirectory = g_currentModDirectory
}

local HUD = VehicleDynamicsControlHUD
local CFG = VehicleDynamicsControlConfig or {}


local function cfg(name, defaultValue)
    local value = CFG[name]
    if value == nil then return defaultValue end
    return value
end


function HUD:isBoggingHUDPresent()
    return _G.BoggingHUD ~= nil or _G.RealisticBogging ~= nil
end


function HUD:slotOccupied(vehicle)
    local env = _G.FS25_AdvancedVehicleFunctions
    local control = (env and env.g_VehicleSystems) or _G.g_VehicleSystems

    local root = vehicle
    if vehicle.getRootVehicle ~= nil then
        root = vehicle:getRootVehicle()
    end
    if control ~= nil and control.getVehicleRoot ~= nil then
        root = control:getVehicleRoot(vehicle)
    end

    if root ~= nil and root.frcHandbrakeActive == true then
        return true
    end

    return control ~= nil
        and control.preheatRootVehicle == root
        and (control.preheatRemaining or 0) > 0
end


function HUD:isActive(vehicle, systemName)
    if VehicleDynamicsControlSystems == nil then return false end

    local activityVehicle = vehicle
    if VehicleDynamicsControlSystems.getActivityVehicle ~= nil then
        activityVehicle = VehicleDynamicsControlSystems:getActivityVehicle(vehicle)
    end

    return VehicleDynamicsControlSystems:isRecentlyActive(
        activityVehicle,
        systemName,
        cfg("HUD_ACTIVE_HOLD_MS", 1000)
    )
end


function HUD.draw(speedMeter)
    local self = HUD
    local vehicle = speedMeter.vehicle

    if vehicle == nil
        or not speedMeter.isVehicleDrawSafe
        or speedMeter.gearIcon == nil
        or vehicle.spec_motorized == nil
        or self.overlays == nil then
        return
    end

    local absActive = self:isActive(vehicle, "ABS")
    local asrActive = self:isActive(vehicle, "ASR")
    local espActive = self:isActive(vehicle, "ESP")

    if not absActive and not asrActive and not espActive then
        return
    end

    local now = g_time or 0
    if math.floor(now / cfg("HUD_BLINK_MS", 300)) % 2 == 1 then
        return
    end

    local posX, posY = speedMeter:getPosition()

    local _, fuelCapacity =
        SpeedMeterDisplay.getVehicleFuelLevelAndCapacity(vehicle)

    local hasFuel = fuelCapacity ~= nil
    local hasRepair =
        vehicle.getDamageAmount ~= nil
        and vehicle:getDamageAmount() ~= nil

    local sectionPosX =
        posX + speedMeter.sectionOffsetX
    local sectionPosY =
        posY + speedMeter.sectionOffsetY

    if hasFuel then
        sectionPosX = sectionPosX + speedMeter.fuelOffsetX
    end

    if hasRepair then
        sectionPosX = sectionPosX + speedMeter.repairOffsetX
    end

    sectionPosX = sectionPosX + speedMeter.gearOffsetX

    local gearIconX =
        sectionPosX + speedMeter.gearIconOffsetX

    local gearIconY =
        sectionPosY
        + speedMeter.gearOffsetY
        + speedMeter.gearIconOffsetY

    local sizePx = cfg("HUD_ICON_SIZE_PX", 20)
    local gapPx = cfg("HUD_GAP_PX", 2)

    local w, h =
        speedMeter:scalePixelValuesToScreenVector(sizePx, sizePx)

    local gapX =
        speedMeter:scalePixelToScreenWidth(gapPx)

    local gapY =
        speedMeter:scalePixelToScreenHeight(2)

    local centerX =
        gearIconX + speedMeter.gearIcon.width * 0.5

    local baseX =
        centerX - w * 0.5

    local baseY =
        gearIconY - h - gapY

    local systems = {
        {name="ABS", active=absActive},
        {name="ASR", active=asrActive},
        {name="ESP", active=espActive}
    }

    for _, entry in ipairs(systems) do
        if entry.active then
            local overlay = self.overlays[entry.name]
            if overlay ~= nil then
                overlay:setDimension(w, h)
                overlay:setPosition(baseX, baseY)

                if entry.name == "ASR" then
                    overlay:setColor(0.15, 1.0, 0.15, 1.0)
                else
                    overlay:setColor(1.0, 0.65, 0.05, 1.0)
                end

                overlay:render()
            end
        end
    end
end


function HUD:loadMap()
    if g_dedicatedServer ~= nil then return end

    self.overlays = {
        ABS = Overlay.new(self.modDirectory .. "icons/abs.dds", 0, 0, 0, 0),
        ASR = Overlay.new(self.modDirectory .. "icons/asr.dds", 0, 0, 0, 0),
        ESP = Overlay.new(self.modDirectory .. "icons/esp.dds", 0, 0, 0, 0)
    }

    if not self.installed then
        SpeedMeterDisplay.draw =
            Utils.appendedFunction(SpeedMeterDisplay.draw, HUD.draw)
        self.installed = true
    end
end


function HUD:deleteMap()
    if self.overlays ~= nil then
        for _, overlay in pairs(self.overlays) do
            if overlay ~= nil then overlay:delete() end
        end
    end
    self.overlays = nil
end


addModEventListener(HUD)
