local Players = game:GetService("Players")

local Module = {}

function Module.GetPlayerList()
    local playerList = {}
    
    for _, player in ipairs(Players:GetPlayers()) do
        table.insert(playerList, {
            Title = string.format("%s (@%s)", player.DisplayName, player.Name),
            Icon = "user"
        })
    end
    
    if #playerList == 0 then
        table.insert(playerList, { Title = "Tidak ada pemain lain", Icon = "user-x" })
    end
    
    return playerList
end

return Module
