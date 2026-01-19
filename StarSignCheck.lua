repeat task.wait() until game:IsLoaded() and game.Players.LocalPlayer

local RS = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Player = game.Players.LocalPlayer

local function getCache()
    local ok, c = pcall(function()
        return require(RS.ClientStatCache):Get()
    end)
    return ok and c or nil
end

local function getTypes()
    local m = RS:FindFirstChild("Stickers", true):FindFirstChild("StickerTypes")
    local ok, t = pcall(require, m)
    return ok and t or nil
end

local function buildMap(t, m, v)
    m = m or {}
    v = v or {}
    if v[t] then return m end
    v[t] = true

    for k, x in pairs(t) do
        if type(x) == "table" then
            if x.ID then
                m[tonumber(x.ID)] = tostring(k)
            end
            buildMap(x, m, v)
        end
    end

    return m
end

local function findReceived(t, v)
    v = v or {}
    if v[t] then return end
    v[t] = true

    for k, x in pairs(t) do
        if k == "Received" and type(x) == "table" then
            return x
        end
        if type(x) == "table" then
            local f = findReceived(x, v)
            if f then return f end
        end
    end
end

local function sendWebhook(starName, amount, inventory)
    local list = ""
    for name, count in pairs(inventory) do
        list = list .. "- " .. name .. ": " .. count .. "\n"
    end

    local data = {
        content = "<@" .. tostring(getgenv().Config["Ping Id"]) .. ">",
        embeds = {{
            title = "Star Sign collected!!!",
            color = 65280,
            fields = {
                { name = "Player", value = Player.Name, inline = false },
                { name = "Star Sign", value = starName, inline = false },
                { name = "Amount", value = tostring(amount), inline = false },
                { name = "Inventory", value = list ~= "" and list or "None", inline = false }
            },
            footer = { text = "made by Jung Ganmyeon" }
        }}
    }

    pcall(function()
        request({
            Url = getgenv().Config["Link Wh"],
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(data)
        })
    end)
end

local types = getTypes()
local idMap = buildMap(types)

local lastReported = {}

while true do
    local cache = getCache()
    local received = cache and findReceived(cache)

    if received then
        local inventory = {}

        for id, amt in pairs(received) do
            local name = idMap[tonumber(id)]
            if name and name:lower():find("star sign") then
                inventory[name] = amt
            end
        end

        for name, amt in pairs(inventory) do
            if not lastReported[name] or amt > lastReported[name] then
                sendWebhook(name, amt, inventory)
                lastReported[name] = amt
            end
        end
    end

    task.wait(5)
end
