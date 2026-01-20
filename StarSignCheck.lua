repeat task.wait() until game:IsLoaded() and game.Players.LocalPlayer

local RS = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Player = game.Players.LocalPlayer
local Events = RS:WaitForChild("Events")

local Config = getgenv().Config or {}
local FeedConfig = Config["Auto Feed"] or {}

if Config["Check Quest"] == nil then
    Config["Check Quest"] = true
end

local FEED_DONE = false
local QUEST_DONE = false
local lastReported = {}

local BOND_ITEMS = {
    { Name = "Moon Charm", Value = 250 },
    { Name = "Pineapple", Value = 50 },
    { Name = "Strawberry", Value = 50 },
    { Name = "Blueberry", Value = 50 },
    { Name = "Sunflower Seed", Value = 50 },
    { Name = "Treat", Value = 10 }
}

local function getCache()
    local ok, c = pcall(function()
        return require(RS.ClientStatCache):Get()
    end)
    return ok and c or nil
end

local function sendWebhook(title, fields)
    local data = {
        content = "<@" .. tostring(Config["Ping Id"]) .. ">",
        embeds = {{
            title = title,
            color = 65280,
            fields = fields,
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

local function getTypes()
    local m = RS:FindFirstChild("Stickers", true):FindFirstChild("StickerTypes")
    local ok, t = pcall(require, m)
    return ok and t or nil
end

local function buildIDMap(t, map, visited)
    map = map or {}
    visited = visited or {}
    if visited[t] then return map end
    visited[t] = true

    for k, v in pairs(t) do
        if type(v) == "table" then
            if v.ID then
                map[tonumber(v.ID)] = tostring(k)
            end
            buildIDMap(v, map, visited)
        end
    end
    return map
end

local function deepFind(tbl, key, visited)
    visited = visited or {}
    if visited[tbl] then return end
    visited[tbl] = true

    for k, v in pairs(tbl) do
        if k == key and type(v) == "table" then
            return v
        end
        if type(v) == "table" then
            local f = deepFind(v, key, visited)
            if f then return f end
        end
    end
end

local types = getTypes()
local ID_MAP = buildIDMap(types)

local function checkStarSign()
    local cache = getCache()
    if not cache then return end

    local received = deepFind(cache, "Received")
    if not received then return end

    local inventory = {}

    for id, amt in pairs(received) do
        local name = ID_MAP[tonumber(id)]
        if name and name:lower():find("star sign") then
            inventory[name] = amt
        end
    end

    for name, amt in pairs(inventory) do
        if not lastReported[name] or amt > lastReported[name] then
            local list = ""
            for n, c in pairs(inventory) do
                list = list .. "- " .. n .. ": " .. c .. "\n"
            end

            sendWebhook("Star Sign collected!!!", {
                { name = "Player", value = Player.Name, inline = false },
                { name = "Star Sign", value = name, inline = false },
                { name = "Amount", value = tostring(amt), inline = false },
                { name = "Inventory", value = list ~= "" and list or "None", inline = false }
            })

            lastReported[name] = amt
        end
    end
end

local function getBeeCount()
    return Player.CoreStats.Bees.Value
end

local function checkQuest()
    if QUEST_DONE or not Config["Check Quest"] then return end

    local cache = getCache()
    if not cache then return end

    local completed = deepFind(cache, "Completed")
    if not completed then return end

    for _, name in pairs(completed) do
        if tostring(name) == "Seven To Seven" then
            sendWebhook("Quest Seven To Seven done!!!!!", {
                { name = "Player", value = Player.Name, inline = false },
                { name = "Bee Count", value = tostring(getBeeCount()), inline = false }
            })
            QUEST_DONE = true
            break
        end
    end
end

local function getBees()
    local cache = getCache()
    if not cache or not cache.Honeycomb then return {} end

    local bees = {}
    for cx, col in pairs(cache.Honeycomb) do
        for cy, bee in pairs(col) do
            if bee and bee.Lvl then
                local x = tonumber(tostring(cx):match("%d+"))
                local y = tonumber(tostring(cy):match("%d+"))
                if x and y then
                    table.insert(bees, {
                        col = x,
                        row = y,
                        level = bee.Lvl
                    })
                end
            end
        end
    end
    return bees
end

local function getTopBees(bees, amount)
    table.sort(bees, function(a, b)
        return a.level > b.level
    end)

    local out = {}
    for i = 1, math.min(amount, #bees) do
        table.insert(out, bees[i])
    end

    return #out == amount and out or nil
end

local function getBondLeft(col, row)
    local result
    pcall(function()
        result = Events.GetBondToLevel:InvokeServer(col, row)
    end)

    if type(result) == "number" then
        return result
    end

    if type(result) == "table" then
        for _, v in pairs(result) do
            if type(v) == "number" then
                return v
            end
        end
    end

    return nil
end

local function feedBond(col, row, bondLeft)
    for _, item in ipairs(BOND_ITEMS) do
        if FeedConfig["Bee Food"] and FeedConfig["Bee Food"][item.Name] then
            local count = math.floor(bondLeft / item.Value)
            if count > 0 then
                local args = {
                    [1] = col,
                    [2] = row,
                    [3] = item.Name,
                    [4] = count,
                    [5] = false
                }

                pcall(function()
                    Events.ConstructHiveCellFromEgg:InvokeServer(unpack(args))
                end)

                return true
            end
        end
    end
end

local function autoFeedStep()
    if FEED_DONE or not FeedConfig["Enable"] then return end

    local bees = getBees()
    local group = getTopBees(bees, FeedConfig["Bee Amount"] or 7)
    if not group then return end

    local done = true
    for _, b in pairs(group) do
        if b.level < (FeedConfig["Bee Level"] or 7) then
            done = false
            break
        end
    end

    if done then
        FEED_DONE = true
        return
    end

    table.sort(group, function(a, b)
        return a.level < b.level
    end)

    for _, b in pairs(group) do
        if b.level < (FeedConfig["Bee Level"] or 7) then
            local bondLeft = getBondLeft(b.col, b.row)
            if bondLeft and bondLeft > 0 then
                feedBond(b.col, b.row, bondLeft)
                break
            end
        end
    end
end

while true do
    checkStarSign()
    checkQuest()
    autoFeedStep()
    task.wait(5)
end
