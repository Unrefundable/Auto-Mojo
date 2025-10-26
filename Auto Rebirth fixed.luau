local Players = game:GetService("Players")

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local localPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()

local function onCharacterAdded(character)
    print("Character has loaded:", character.Name)
end

if localPlayer.Character then
    onCharacterAdded(localPlayer.Character)
end
localPlayer.CharacterAdded:Connect(onCharacterAdded)

task.wait(2)
-- Script goes down here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local ByteNetReliable = ReplicatedStorage:WaitForChild("ByteNetReliable")

local TARGET_CRYSTAL = 3
local TARGET_GOLD = 12

local playerGui = localPlayer:WaitForChild("PlayerGui")
local spawnGui = playerGui:WaitForChild("SpawnGui")
local customization = spawnGui:WaitForChild("Customization")
local mainGui = playerGui:WaitForChild("MainGui")
local leftPanel = mainGui:WaitForChild("LeftPanel")
local rightPanel = mainGui:WaitForChild("RightPanel")
local inventoryList = rightPanel:WaitForChild("Inventory"):WaitForChild("List")
local bedButton = customization:WaitForChild("BedButton")
local spawnFirst = ReplicatedStorage:WaitForChild("Events"):WaitForChild("SpawnFirst")
local resourcesFolder = workspace:WaitForChild("Resources")
local itemsFolder = workspace:WaitForChild("Items")
local playersFolder = workspace:WaitForChild("Players")
local packetsModule = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Packets")
local Packets = require(packetsModule)
local pickupPacket = Packets.Pickup
local rebirthButton = leftPanel:WaitForChild("Mojo"):WaitForChild("RebirthButton")
local rebirthConfirmButton = mainGui:WaitForChild("Panels"):WaitForChild("MojoConfirm"):WaitForChild("LevelUpFrame"):WaitForChild("ConfirmButton")

local GOLD_PAYLOAD = buffer.fromstring("\134U\2")
local CRYSTAL_PAYLOAD = buffer.fromstring("\134\180\1")

local rootEnv do
    local ok, env = pcall(getfenv, 0)
    rootEnv = ok and env or _G
end

local getgenvFunc = rawget(rootEnv, "getgenv")
local synLib = rawget(rootEnv, "syn")
local fluxusLib = rawget(rootEnv, "fluxus")
local readfileFunc = rawget(rootEnv, "readfile")
local isfileFunc = rawget(rootEnv, "isfile")
local queue_on_teleport_global = rawget(rootEnv, "queue_on_teleport")
local queueteleport_global = rawget(rootEnv, "queueteleport")
local queueTeleport_global = rawget(rootEnv, "queueTeleport")
local fluxusQueue_global = rawget(rootEnv, "fluxusQueueOnTeleport")
local krnlQueue_global = rawget(rootEnv, "KRNL_QUEUE_ON_TELEPORT")

local function getTimestamp()
    if typeof(os) == "table" and typeof(os.time) == "function" then
        local ok, value = pcall(os.time)
        if ok then
            return value
        end
    end

    if typeof(tick) == "function" then
        local ok, value = pcall(tick)
        if ok then
            return value
        end
    end

    return 0
end

local function missing(expectedType, value, fallback)
    if typeof(value) == expectedType then
        return value
    end
    return fallback
end

local function findQueueFunction()
    local candidates = {}

    if typeof(getgenvFunc) == "function" then
        local env = getgenvFunc()
        if typeof(env) == "table" then
            table.insert(candidates, env.queue_on_teleport)
            table.insert(candidates, env.queueonteleport)
            table.insert(candidates, env.queueTeleport)
        end
    end

    table.insert(candidates, queue_on_teleport_global)
    table.insert(candidates, queueteleport_global)
    table.insert(candidates, queueTeleport_global)

    if typeof(synLib) == "table" then
        table.insert(candidates, synLib.queue_on_teleport)
    end

    if typeof(fluxusLib) == "table" then
        table.insert(candidates, fluxusLib.queue_on_teleport)
    end

    table.insert(candidates, fluxusQueue_global)
    table.insert(candidates, krnlQueue_global)

    for _, candidate in ipairs(candidates) do
        if typeof(candidate) == "function" then
            return candidate
        end
    end

    return nil
end

local function resolveScriptPath()
    if typeof(getgenvFunc) == "function" then
        local env = getgenvFunc()
        if typeof(env) == "table" then
            local override = env.AUTO_REBIRTH_FILE_PATH
            if typeof(override) == "string" and override ~= "" then
                return override
            end
        end
    end

    if typeof(debug) == "table" and typeof(debug.getinfo) == "function" then
        local info = debug.getinfo(2, "S")
        if info and typeof(info.source) == "string" and info.source:sub(1, 1) == "@" then
            return info.source:sub(2)
        end
    end

    return nil
end

local function buildQueuedChunk()
    local queuePath = resolveScriptPath()

    if queuePath and typeof(isfileFunc) == "function" and not isfileFunc(queuePath) then
        queuePath = nil
    end

    if queuePath and typeof(readfileFunc) == "function" then
        return string.format([[local ok,data = pcall(readfile, %q)
if ok and data then
    local fn = loadstring(data)
    if fn then
        fn()
    end
end]], queuePath)
    end

    if typeof(getgenvFunc) == "function" then
        local env = getgenvFunc()
        if typeof(env) == "table" then
            local inline = env.AUTO_REBIRTH_INLINE_SOURCE
            if typeof(inline) == "string" and inline ~= "" then
                return string.format([[local fn = loadstring(%q)
if fn then
    fn()
end]], inline)
            end
        end
    end

    return nil
end

local queuedTeleportFunction = findQueueFunction()

local function setupTeleportQueue()
    if not queuedTeleportFunction then
        return
    end

    local chunk = buildQueuedChunk()
    if not chunk then
        warn("[AutoRebirth] queue_on_teleport available but no source to queue. Set getgenv().AUTO_REBIRTH_FILE_PATH or AUTO_REBIRTH_INLINE_SOURCE.")
        return
    end

    local success, err = pcall(queuedTeleportFunction, chunk)
    if not success then
        warn("[AutoRebirth] Failed to queue teleport script:", err)
    end
end

-- Queue this script so executors auto re-run it after a teleport or server hop.
setupTeleportQueue()

local envQueue
if typeof(getgenvFunc) == "function" then
    local env = getgenvFunc()
    if typeof(env) == "table" then
        envQueue = env.queue_on_teleport or env.queueonteleport or env.queueTeleport
    end
end

local queueteleport = missing(
    "function",
    envQueue or queue_on_teleport_global or queueteleport_global or queueTeleport_global or (synLib and synLib.queue_on_teleport) or (fluxusLib and fluxusLib.queue_on_teleport) or fluxusQueue_global or krnlQueue_global or queuedTeleportFunction
)

game.Players.LocalPlayer.OnTeleport:Connect(function(state)
    if queueteleport then
        queueteleport("loadstring(game:HttpGet('https://raw.githubusercontent.com/Unrefundable/Auto-Mojo/refs/heads/main/Auto%20Rebirth%20fixed.luau'))()")
    end
end)

local DEFAULT_REJOIN_OPTIONS = {
    waitBefore = 10,
    kickMessage = "\n Worry not",
}

local function resolveRejoinOptions(options)
    options = options or {}

    local waitBefore = tonumber(options.waitBefore) or DEFAULT_REJOIN_OPTIONS.waitBefore
    if waitBefore < 0 then
        waitBefore = 0
    end

    local kickMessage = typeof(options.kickMessage) == "string" and options.kickMessage or DEFAULT_REJOIN_OPTIONS.kickMessage

    return {
        waitBefore = waitBefore,
        kickMessage = kickMessage,
    }
end

local function bedSpawn()
    while true do
        firesignal(bedButton.Activated)

        task.wait(0.1)

        local ok, result = pcall(spawnFirst.InvokeServer, spawnFirst, true)
        if ok and result ~= false then
            break
        end

        task.wait(5)
    end

    task.wait(1)
end

local function getItemPosition(item)
    if item:IsA("BasePart") then
        return item.Position
    end

    if item:IsA("Model") then
        local primary = item.PrimaryPart
        if not primary then
            primary = item:FindFirstChildWhichIsA("BasePart")
        end

        if primary then
            return primary.Position
        end
    end

    local pivotCFrame = nil
    local ok = pcall(function()
        pivotCFrame = item:GetPivot()
    end)

    if ok and pivotCFrame then
        return pivotCFrame.Position
    end

    return nil
end

local function getRootPosition()
    local character = localPlayer.Character
    if not character then
        return nil
    end

    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if rootPart then
        return rootPart.Position
    end

    return nil
end

local function pickupNearby(radius)
    radius = radius or 20
    if not (pickupPacket and typeof(pickupPacket.send) == "function") then
        return
    end

    local idleCycles = 0
    while idleCycles < 5 do
        local origin = getRootPosition()
        if not origin then
            idleCycles = idleCycles + 1
            task.wait(0.1)
            continue
        end

        local collected = false
        for _, item in ipairs(itemsFolder:GetChildren()) do
            local entityId = item:GetAttribute("EntityID")
            if entityId then
                local pos = getItemPosition(item)
                if pos and (pos - origin).Magnitude <= radius then
                    pickupPacket.send(entityId)
                    collected = true
                end
            end
        end

        if collected then
            idleCycles = 0
        else
            idleCycles = idleCycles + 1
        end

        task.wait(0.1)
    end
end

local function queueRejoin(options)
    local resolved = resolveRejoinOptions(options)
    local waitBefore = resolved.waitBefore
    local kickMessage = resolved.kickMessage

    local placeId = game.PlaceId ~= 0 and game.PlaceId or 11729688377
    local privateServerId = game.PrivateServerId

    task.spawn(function()
        task.wait(waitBefore)

        local kickOk, kickErr = pcall(function()
            localPlayer:Kick(kickMessage)
        end)
        if not kickOk and kickErr then
            warn("[AutoRebirth] Kick failed:", kickErr)
        end

        task.wait(0.5)

        local ok, err
        if typeof(privateServerId) == "string" and privateServerId ~= "" then
            ok, err = pcall(function()
                TeleportService:TeleportToPrivateServer(placeId, privateServerId, {localPlayer})
            end)
        else
            ok, err = pcall(function()
                TeleportService:Teleport(placeId, localPlayer)
            end)
        end

        if not ok and err then
            warn("[AutoRebirth] Teleport failed:", err)
        end
    end)

    task.wait(waitBefore + 5)
end

local function getCount(name)
    local entry = inventoryList:FindFirstChild(name)
    if not entry then
        return 0
    end

    local quantityImage = entry:FindFirstChild("QuantityImage")
    if not quantityImage then
        return 0
    end

    local label = quantityImage:FindFirstChild("QuantityText")
    if not label then
        return 0
    end

    local text = label.Text
    if typeof(text) ~= "string" then
        return 0
    end

    local number = tonumber(text:match("%d+"))
    return number or 0
end

local function buyUntilTarget(name, target, payload)
    local count = getCount(name)
    while count < target do
        ByteNetReliable:FireServer(payload)

        local oldCount = count
        repeat
            task.wait(0.05)
            count = getCount(name)
        until count ~= oldCount
    end
end

bedSpawn()

ByteNetReliable:FireServer(buffer.fromstring("\183\2"))
task.wait(0.5)

local toolsFolder = playersFolder:FindFirstChild(localPlayer.Name)
toolsFolder = toolsFolder and toolsFolder:FindFirstChild("Tools")
local hasGodAxeEquipped = false

if toolsFolder and toolsFolder:FindFirstChild("God Axe") then
    hasGodAxeEquipped = true
else
    task.wait(0.5)
    buyUntilTarget("Crystal Chunk", TARGET_CRYSTAL, CRYSTAL_PAYLOAD)
    buyUntilTarget("Gold", TARGET_GOLD, GOLD_PAYLOAD)
    task.wait(1)

    ByteNetReliable:FireServer(buffer.fromstring("\5\198\1"))
    task.wait(1)

    ByteNetReliable:FireServer(buffer.fromstring("\183\2"))
    task.wait(1)
end

while true do
    local ancientTree = resourcesFolder:FindFirstChild("Ancient Tree")
    if not ancientTree then
        break
    end

    ByteNetReliable:FireServer(buffer.fromstring("\17\1\0\19\2\0\0"))
    task.wait(0.25)
end

pickupNearby(20)

local function findGuiObject(parent, childName)
    if not parent then
        return nil
    end

    local child = parent:FindFirstChild(childName)
    if child then
        return child
    end

    local ok, result = pcall(parent.WaitForChild, parent, childName, 3)
    if not ok then
        return nil
    end

    return result
end

local function findLevelLabel(playerGuiRef)
    local current = playerGuiRef

    for _, name in ipairs({"Topbar", "Topbar", "Right", "Level", "Level"}) do
        current = findGuiObject(current, name)
        if not current then
            return nil
        end
    end

    return current
end

local function getPlayerLevelText()
    local playerGuiRef = findGuiObject(localPlayer, "PlayerGui")
    if not playerGuiRef then
        return nil
    end

    local levelLabel = findLevelLabel(playerGuiRef)
    if not levelLabel then
        return nil
    end

    local text = levelLabel.Text
    if typeof(text) ~= "string" then
        return nil
    end

    return text
end

local levelText = getPlayerLevelText()

if levelText then
    print("Player level:", levelText)
else
    print("Player level: unavailable")
end

if levelText == "lvl 100" then
    local character = localPlayer.Character
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.Health = 0
        else
            character:BreakJoints()
        end
    end

    task.wait(1)
    task.wait(0.5)
    firesignal(rebirthButton.Activated)
    task.wait(0.2)
    firesignal(rebirthConfirmButton.Activated)

    local respawned
    if localPlayer.Character == character then
        respawned = localPlayer.CharacterAdded:Wait()
    else
        respawned = localPlayer.Character
    end

    if respawned then
        respawned:WaitForChild("HumanoidRootPart", 5)
    end

    task.wait(2)
    bedSpawn()
    pickupNearby(20)
    queueRejoin({waitBefore = 10})
else
    queueRejoin({waitBefore = 10})
end

return
