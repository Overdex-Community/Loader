function hopVicious()
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
    local VICIOUS_WH = "https://discord.com/api/webhooks/1467181077595557929/j26ECltg71z7QjDbALYF-ZuhEcEhyh6w_Jq56VSCU434nW9DKnYJ_tUCoeB539g9Jj7a"

    local FILE, TTL = "vicjobid.json", 600
    local LAST_REQ, REQ_CD = 0, 8

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

    local function findVicious()
        local monsters = WS:FindFirstChild("Monsters")
        if not monsters then return nil end
        for _, mob in pairs(monsters:GetChildren()) do
            if mob:IsA("Model") and mob.Name:match("^Vicious Bee") then
                return mob
            end
        end
        return nil
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
        if not cfg.Enable then return true end
        for _, v in pairs(cfg["Field Name"]) do
            if string.find(string.lower(name), string.lower(v)) then
                return true
            end
        end
        return false
    end

    local function viciousWebhook(field)
        if not VICIOUS_WH or VICIOUS_WH == "" or not request then return end
        local job = game.JobId
        local tpCode = 'game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId,"' .. job .. '",game.Players.LocalPlayer)'
        local data = {
            embeds = {{
                title = "🐝 Vicious Bee Found!",
                color = 16711680,
                fields = {
                    { name = "Field", value = field, inline = true },
                    { name = "JobID", value = job, inline = false },
                    { name = "Teleport", value = "`" .. tpCode .. "`", inline = false }
                }
            }}
        }
        pcall(function()
            request({
                Url = VICIOUS_WH,
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
        if not ok then
            task.wait(15)
            return nil
        end
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
                    if s.playing > 0
                    and s.playing < s.maxPlayers
                    and not used[s.id]
                    and not s.privateServerId then

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
                if not cursor then
                    return
                end
            else
                task.wait(2)
            end
        end
    end

    local vicious = findVicious()

    if not vicious then
        hop()
        return
    end

    local field = "Unknown"
    if vicious.PrimaryPart then
        field = findField(vicious.PrimaryPart.Position)
    end

    if not allowed(field) then
        hop()
        return
    end

    viciousWebhook(field)

    local destroyed = false
    local conn
    conn = vicious.AncestryChanged:Connect(function(_, parent)
        if not parent then
            destroyed = true
            conn:Disconnect()
        end
    end)

    repeat task.wait(1) until destroyed

    task.wait(5)
    hop()
end
hopVicious()
