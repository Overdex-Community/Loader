function hopSprout()
    local WS = game:GetService("Workspace")
    local TP = game:GetService("TeleportService")
    local Http = game:GetService("HttpService")
    local Players = game:GetService("Players")
    local Player = Players.LocalPlayer
    local PID = game.PlaceId

    getgenv().Config = getgenv().Config or {}
    getgenv().Config["Field Accept"] = getgenv().Config["Field Accept"] or {
        Enable = false,
        ["Field Name"] = {}
    }

    local cfg = getgenv().Config["Field Accept"]
    if not cfg.Enable then return end

    local FILE, TTL = "sproutjobid.json", 600
    local LAST_REQ, REQ_CD = 0, 8
    local SPROUT_WH = "https://discord.com/api/webhooks/1467181076622606428/knHp0IVlHI6krH-niedJB81pp95c08NgwtaAvJJ1f8D3CSQofCfDee28hG1cWIIbFdZb"

    local function read()
        if not isfile(FILE) then return {} end
        local ok, data = pcall(function()
            return Http:JSONDecode(readfile(FILE))
        end)
        return ok and data or {}
    end

    local function write(t)
        writefile(FILE, Http:JSONEncode(t))
    end

    local function saveJob()
        local t = read()
        local now = os.time()
        for k, v in pairs(t) do
            if now - (v.Time or 0) >= TTL then
                t[k] = nil
            end
        end
        t[game.JobId] = { Time = now }
        write(t)
    end

    local function findField(pos)
        local zones = WS:FindFirstChild("FlowerZones")
        if not zones then return "Unknown" end
        for _, f in pairs(zones:GetChildren()) do
            if f:IsA("BasePart") then
                local s, c = f.Size / 2, f.Position
                if pos.X >= c.X - s.X and pos.X <= c.X + s.X
                and pos.Z >= c.Z - s.Z and pos.Z <= c.Z + s.Z then
                    return f.Name
                end
            end
        end
        return "Unknown"
    end

    local function allowed(name)
        for _, v in pairs(cfg["Field Name"]) do
            if string.find(string.lower(name), string.lower(v)) then
                return true
            end
        end
        return false
    end

    local function sproutWebhook(field)
        if not SPROUT_WH or SPROUT_WH == "" or not request then return end
        local job = game.JobId
        local tpCode = 'game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId,"' .. job .. '",game.Players.LocalPlayer)'
        local data = {
            embeds = {{
                title = "🌱 Sprout Found!",
                color = 65280,
                fields = {
                    { name = "Field", value = field, inline = true },
                    { name = "JobID", value = job, inline = false },
                    { name = "Teleport", value = "`" .. tpCode .. "`", inline = false }
                }
            }}
        }
        pcall(function()
            request({
                Url = SPROUT_WH,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = Http:JSONEncode(data)
            })
        end)
    end

    local function getServers(cursor)
        local now = tick()
        if now - LAST_REQ < REQ_CD then
            task.wait(REQ_CD - (now - LAST_REQ))
        end
        LAST_REQ = tick()
        local url = "https://games.roblox.com/v1/games/" .. PID .. "/servers/Public?sortOrder=Asc&limit=100"
        if cursor then url = url .. "&cursor=" .. cursor end
        local ok, data = pcall(function()
            return Http:JSONDecode(game:HttpGet(url))
        end)
        if not ok then task.wait(15) return nil end
        return data
    end

    local function hop()
        saveJob()
        local used = read()
        local cursor
        while true do
            local page = getServers(cursor)
            if page then
                for _, s in pairs(page.data or {}) do
                    if s.playing > 0 and s.playing < s.maxPlayers and not used[s.id] and not s.privateServerId then
                        used[s.id] = { Time = os.time() }
                        write(used)
                        pcall(function()
                            TP:TeleportToPlaceInstance(PID, s.id, Player)
                        end)
                        task.wait(5)
                        return
                    end
                end
                cursor = page.nextPageCursor
                if not cursor then return end
            else
                task.wait(2)
            end
        end
    end

    local sprouts = WS:FindFirstChild("Sprouts")
    local sprout = sprouts and sprouts:FindFirstChild("Sprout")

    if not (sprout and sprout:IsA("MeshPart")) then
        hop()
        return
    end

    local field = findField(sprout.Position)
    if not allowed(field) then
        hop()
        return
    end

    sproutWebhook(field)

    local destroyed = false
    local conn
    conn = sprout.AncestryChanged:Connect(function(_, parent)
        if not parent then
            destroyed = true
            conn:Disconnect()
        end
    end)

    repeat task.wait(1) until destroyed

    if isfile(FILE) then delfile(FILE) end
    task.wait(40)
    hop()
end
hopSprout()
