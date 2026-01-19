repeat task.wait() until game:IsLoaded() and game.Players.LocalPlayer

local RS = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Player = game.Players.LocalPlayer

local TARGET_QUEST = "Seven To Seven"

local Config = getgenv().Config or {}
local CHECK_QUEST = Config["Check Quest"]
if CHECK_QUEST == nil then CHECK_QUEST = true end

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
        if k == "Received" and type(x) == "table" then return x end
        if type(x) == "table" then
            local f = findReceived(x, v)
            if f then return f end
        end
    end
end

local function findCompleted(t, v)
    v = v or {}
    if v[t] then return end
    v[t] = true
    for k, x in pairs(t) do
        if k == "Completed" and type(x) == "table" then return x end
        if type(x) == "table" then
            local f = findCompleted(x, v)
            if f then return f end
        end
    end
end

local function getBeeCount()
    local cache = getCache()
    if not cache or not cache.Honeycomb then return 0 end
    local count = 0
    for _, col in pairs(cache.Honeycomb) do
        for _, bee in pairs(col) do
            if bee and bee.Type then
                count += 1
            end
        end
    end
    return count
end

local function sendStarWebhook(name, amt, inventory)
    local list = ""
    for n, c in pairs(inventory) do
        list ..= "- " .. n .. ": " .. c .. "\n"
    end

    local data = {
        content = "<@" .. tostring(Config["Ping Id"]) .. ">",
        embeds = {{
            title = "Star Sign collected!!!",
            color = 65280,
            fields = {
                { name = "Player", value = Player.Name, inline = false },
                { name = "Star Sign", value = name, inline = false },
                { name = "Amount", value = tostring(amt), inline = false },
                { name = "Inventory", value = list ~= "" and list or "None", inline = false }
            },
            footer = { text = "made by Jung Ganmyeon" }
        }}
    }

    pcall(function()
        request({
            Url = Config["Link Wh"],
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(data)
        })
    end)
end

local function sendQuestWebhook()
    local data = {
        content = "<@" .. tostring(Config["Ping Id"]) .. ">",
        embeds = {{
            title = "Quest " .. TARGET_QUEST .. " done!!!!!",
            color = 65280,
            fields = {
                { name = "Player", value = Player.Name, inline = false },
                { name = "Bee Count", value = tostring(getBeeCount()), inline = false }
            },
            footer = { text = "made by Jung Ganmyeon" }
        }}
    }

    pcall(function()
        request({
            Url = Config["Link Wh"],
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(data)
        })
    end)
end

local types = getTypes()
local idMap = buildMap(types)

local lastStar = {}
local questReported = false

while true do
    local cache = getCache()

    if cache then
        local received = findReceived(cache)
        if received then
            local inventory = {}
            for id, amt in pairs(received) do
                local name = idMap[tonumber(id)]
                if name and name:lower():find("star sign") then
                    inventory[name] = amt
                end
            end

            for name, amt in pairs(inventory) do
                if not lastStar[name] or amt > lastStar[name] then
                    sendStarWebhook(name, amt, inventory)
                    lastStar[name] = amt
                end
            end
        end

        if CHECK_QUEST and not questReported then
            local completed = findCompleted(cache)
            if completed then
                for _, q in pairs(completed) do
                    if tostring(q) == TARGET_QUEST then
                        sendQuestWebhook()
                        questReported = true
                        break
                    end
                end
            end
        end
    end

    task.wait(5)
end
