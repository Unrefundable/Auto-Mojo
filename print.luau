print('check')

function missing(t, f, fallback)
    if type(f) == t then return f end
    return fallback
end

-- Support for multiple executors including Delta
queueteleport = missing("function",
    queue_on_teleport or
    queueonteleport or
    (delta and delta.queue_on_teleport) or
    (syn and syn.queue_on_teleport) or
    (fluxus and fluxus.queue_on_teleport)
)

game.Players.LocalPlayer.OnTeleport:Connect(function(State)
    if queueteleport then
        queueteleport("loadstring(game:HttpGet('https://raw.githubusercontent.com/Unrefundable/Auto-Mojo/refs/heads/main/print.luau'))()")
    end
end)

-- Run the external script LAST
loadstring(game:HttpGet('https://github.com/Unrefundable/Auto-Mojo/releases/latest/download/Auto.Rebirth.luau'))()
