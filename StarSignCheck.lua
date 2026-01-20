repeat task.wait() until game:IsLoaded() and game.Players.LocalPlayer

local RS = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Player = game.Players.LocalPlayer
local Events = RS:WaitForChild("Events")

local Config = getgenv().Config
if Config["Check Quest"] == nil then
    Config["Check Quest"] = true
end

local FEED_DONE = false
local QUEST_DONE = false
local lastReported = {}

local TREAT_COST = {
    [1] = 1,
    [2] = 4,
    [3] = 20,
    [4] = 75,
    [5] = 400,
    [6] = 1500
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

local function getTop7(bees)
    table.sort(bees, function(a, b)
        return a.level > b.level
    end)

    local out = {}
    for i = 1, math.min(7, #bees) do
        table.insert(out, bees[i])
    end

    return #out == 7 and out or nil
end

local function getHoney()
    return Player.CoreStats.Honey.Value
end

local function getTreatCount()
    local cache = getCache()
    if not cache or not cache.Items then return 0 end
    return cache.Items.Treat or 0
end

local function buyTreat()
    local args = {
        [1] = "Purchase",
        [2] = {
            ["Type"] = "Treat",
            ["Amount"] = 1000,
            ["Category"] = "Eggs"
        }
    }
    pcall(function()
        Events.ItemPackageEvent:InvokeServer(unpack(args))
    end)
end

local function feedBee(col, row, amount)
    local args = {
        [1] = col,
        [2] = row,
        [3] = "Treat",
        [4] = amount,
        [5] = false
    }
    pcall(function()
        Events.ConstructHiveCellFromEgg:InvokeServer(unpack(args))
    end)
end

local function autoFeedStep()
    if FEED_DONE or not Config["Auto Feed Lv 7"] then return end

    local bees = getBees()
    local group = getTop7(bees)
    if not group then return end

    local done = true
    for _, b in pairs(group) do
        if b.level < 7 then
            done = false
            break
        end
    end

    if done then
        FEED_DONE = true
        return
    end

    if getHoney() >= 10000000 then
        buyTreat()
    end

    local treats = getTreatCount()

    table.sort(group, function(a, b)
        return a.level < b.level
    end)

    for _, b in pairs(group) do
        if b.level < 7 then
            local need = TREAT_COST[b.level]
            if treats >= need then
                feedBee(b.col, b.row, need)
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
