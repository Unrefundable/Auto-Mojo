local Players = game:GetService("Players")

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local localPlayer = Players.LocalPlayer

local function onCharacterAdded(character)
    print("Character has loaded:", character.Name)
end

if localPlayer.Character then
    onCharacterAdded(localPlayer.Character)
end
localPlayer.CharacterAdded:Connect(onCharacterAdded)

task.wait(5)

loadstring(game:HttpGet('https://github.com/Unrefundable/Auto-Mojo/releases/latest/download/Auto.Rebirth.luau'))()

function missing(t, f, fallback)
    if type(f) == t then return f end
    return fallback
end

queueteleport =  missing("function", queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport))

game.Players.LocalPlayer.OnTeleport:Connect(function(State)
    if queueteleport then
   queueteleport("loadstring(game:HttpGet('https://raw.githubusercontent.com/Unrefundable/Auto-Mojo/refs/heads/main/Script.luau'))()")
    end
end)
