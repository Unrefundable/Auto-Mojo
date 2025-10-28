loadstring(game:HttpGet('https://github.com/Unrefundable/Auto-Mojo/releases/latest/download/Auto.Rebirth.luau'))()

if queue_on_teleport then
    game.Players.LocalPlayer.OnTeleport:Connect(function(State)
        if State == Enum.TeleportState.InProgress then
            queue_on_teleport("loadstring(game:HttpGet('https://raw.githubusercontent.com/Unrefundable/Auto-Mojo/refs/heads/main/Script.luau'))()")
        end
    end)
else
    warn("Warning: 'queue_on_teleport' not found. This script will not re-execute on teleport. Please use your executor's Auto-Execute feature instead.")
end
