-- Practice Makes Perfect: Robot Health Scaling
-- Fixed: Uses Blackboard system to strictly ignore the Main Menu dummy player.

local config = {
    storedLevel = 1 
}

local timer = 0.0
local checkInterval = 2.0 -- Check stats every 2 seconds

-- Your curve: Level -> Multiplier
local healthCurve = {
    {  1, 1.0 },
    { 10, 1.6 },
    { 20, 6.8 },
    { 30, 9.3 },
    { 40, 12.8 },
    { 50, 16.5 },
    { 60, 24.9 },
}

-- FILE I/O
function loadConfig()
    local file = io.open("saved_level.json", "r")
    if file then
        local content = file:read("*a")
        local level = tonumber(content)
        if level then
            config.storedLevel = level
            print("[PMP] Loaded stored level: " .. level)
        end
        file:close()
    else
        print("[PMP] No stored level found. Using default (1).")
    end
end

function saveConfig(level)
    local file = io.open("saved_level.json", "w")
    if file then
        file:write(tostring(level))
        file:close()
        print("[PMP] Updated cache: Level " .. level)
    end
end

-- CALCULATIONS
function evalHealthMult(level)
    if level <= healthCurve[1][1] then return healthCurve[1][2] end
    
    for i = 1, #healthCurve - 1 do
        local x1, y1 = healthCurve[i][1], healthCurve[i][2]
        local x2, y2 = healthCurve[i + 1][1], healthCurve[i + 1][2]
        if level <= x2 then
            local t = (level - x1) / (x2 - x1)
            return y1 + (y2 - y1) * t
        end
    end
    return healthCurve[#healthCurve][2]
end

function applyRobotHealthForLevel(level)
    local mult = evalHealthMult(level)
    TweakDB:SetFlat("NPCStatPreset.Q001_training_robotHealth_inline0.value", mult)
    print(("[PMP] Set TweakDB multiplier to %.3f (Level %d)"):format(mult, level))
end

-- HELPERS
function isInMenu()
    -- This checks if the UI thinks we are in a menu (Main Menu, Pause Menu, etc)
    local bbDefs = Game.GetAllBlackboardDefs()
    if not bbDefs then return true end
    local uiBB = Game.GetBlackboardSystem():Get(bbDefs.UI_System)
    if not uiBB then return true end
    
    return uiBB:GetBool(bbDefs.UI_System.IsInMenu)
end

-- LOGIC
function checkAndApply()
    -- If we are in any menu, do nothing (main menu, pause, inventory, etc.)
    if isInMenu() then return end

    local player = Game.GetPlayer()
    if not player then return end

    local statsSys = Game.GetStatsSystem()
    if not statsSys then return end

    local currentLevel = math.floor(statsSys:GetStatValue(player:GetEntityID(), "Level") + 0.5)

    -- IMPORTANT:
    -- 1) Ignore level 0/1 completely. That's almost always the dummy player.
    -- 2) Only react when we see a "real" level change.
    if currentLevel <= 1 then
        return
    end

    if currentLevel > config.storedLevel then
        -- player actually leveled up
        print("[PMP] Detected level change (Stored: "..config.storedLevel.." -> Current: "..currentLevel..")")
        
        -- 1. Update the cache file
        config.storedLevel = currentLevel
        saveConfig(currentLevel)

        -- 2. Apply it live
        applyRobotHealthForLevel(currentLevel)
    elseif currentLevel > 1 and  currentLevel < config.storedLevel then
        -- player actually leveled decreased
        print("[PMP] Detected level change (Stored: "..config.storedLevel.." -> Current: "..currentLevel..")")
        
        -- 1. Update the cache file
        config.storedLevel = currentLevel
        saveConfig(currentLevel)

        -- 2. Apply it live
        applyRobotHealthForLevel(currentLevel)
    elseif currentLevel == config.storedLevel then
        -- same level, just apply multiplier again to override load timing
        -- 2. Apply it live
        applyRobotHealthForLevel(currentLevel)
    end

end


-- EVENTS
registerForEvent("onInit", function()
    loadConfig()
    -- Apply the LAST KNOWN level immediately. 
    -- This ensures the TweakDB is ready before the save even loads.
    applyRobotHealthForLevel(config.storedLevel) 
    print("[PMP] Init complete. Waiting for gameplay to update stats...")
end)

registerForEvent("onUpdate", function(delta)
    timer = timer + delta
    if timer > checkInterval then
        timer = 0
        checkAndApply()
    end
end)