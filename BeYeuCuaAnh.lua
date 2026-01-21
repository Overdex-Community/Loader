print("anh jung dz v2")
repeat task.wait() until game:IsLoaded() and game.Players.LocalPlayer

local Config = getgenv().Config
local FeedConfig = Config["Auto Feed"] or {}
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Http = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")

local Player = Players.LocalPlayer
local Events = RS:WaitForChild("Events")

local Cache = { data = nil, last = 0 }

local ITEM_KEYS = {
    ["Moon Charm"] = "MoonCharm",
    ["Pineapple"] = "Pineapple",
    ["Strawberry"] = "Strawberry",
    ["Blueberry"] = "Blueberry",
    ["Sunflower Seed"] = "SunflowerSeed",
    ["Bitterberry"] = "Bitterberry",
    ["Neonberry"] = "Neonberry",
    ["Gingerbread Bear"] = "GingerbreadBear",
    ["Treat"] = "Treat",
    ["Silver"] = "Silver",
    ["Gold"] = "Gold",
    ["Diamond"] = "Diamond",
    ["Star Egg"] = "Star",
    ["Basic"] = "Basic"
}

local BOND_ITEMS = {
    { Name = "Neonberry", Value = 500 },
    { Name = "MoonCharm", Value = 250 },
    { Name = "GingerbreadBear", Value = 250 },
    { Name = "Bitterberry", Value = 100 },
    { Name = "Pineapple", Value = 50 },
    { Name = "Strawberry", Value = 50 },
    { Name = "Blueberry", Value = 50 },
    { Name = "SunflowerSeed", Value = 50 },
    { Name = "Treat", Value = 10 }
}

local LAST_SIGNS = {}
local QUEST_DONE = false
local FEED_DONE = false
local PRINTER_CD = 0
local STAR_TIMER = 0
local ACC_CHANGED = false

local function getCache()
    if tick() - Cache.last > 1 then
        local ok, res = pcall(function()
            return require(RS.ClientStatCache):Get()
        end)
        if ok then
            Cache.data = res
            Cache.last = tick()
        end
    end
    return Cache.data
end

local function writeStatus(text)
    if not Config["Auto Change Acc"] then return end
    local name = Player.Name .. ".txt"
    pcall(function()
        writefile(name, text)
    end)
end

local function sendWebhook(title, fields, color)
    local data = {
        content = "<@" .. tostring(Config["Ping Id"]) .. ">",
        embeds = {{
            title = title,
            color = color,
            fields = fields,
            footer = { text = "made by Jung Ganmyeon" }
        }}
    }

    pcall(function()
        request({
            Url = Config["Link Wh"],
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = Http:JSONEncode(data)
        })
    end)
end

local function deepFind(tbl, key, seen)
    seen = seen or {}
    if seen[tbl] then return end
    seen[tbl] = true

    for k, v in pairs(tbl) do
        if k == key then return v end
        if type(v) == "table" then
            local f = deepFind(v, key, seen)
            if f then return f end
        end
    end
end

local function getInventory()
    local cache = getCache()
    if not cache or not cache.Eggs then return {} end

    local inv = {}
    for name, key in pairs(ITEM_KEYS) do
        inv[name] = tonumber(cache.Eggs[key]) or 0
    end
    return inv
end

local function getBees()
    local cache = getCache()
    local bees = {}
    if not cache or not cache.Honeycomb then return bees end

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

local function findEmptySlot()
    for _, hive in ipairs(Workspace.Honeycombs:GetChildren()) do
        local owner = hive:FindFirstChild("Owner")
        local isMine =
            (owner and owner:IsA("ObjectValue") and owner.Value == Player) or
            (owner and owner:IsA("StringValue") and owner.Value == Player.Name) or
            (owner and owner:IsA("IntValue") and owner.Value == Player.UserId)

        if isMine then
            local slots = {}

            for _, cell in ipairs(hive.Cells:GetChildren()) do
                local cellType = cell:FindFirstChild("CellType")
                local x = cell:FindFirstChild("CellX")
                local y = cell:FindFirstChild("CellY")
                local locked = cell:FindFirstChild("CellLocked")

                if cellType and x and y and locked and not locked.Value then
                    table.insert(slots, {
                        x = x.Value,
                        y = y.Value,
                        empty = (cellType.Value == "" or tostring(cellType.Value):lower() == "empty")
                    })
                end
            end

            table.sort(slots, function(a, b)
                if a.x == b.x then
                    return a.y < b.y
                end
                return a.x < b.x
            end)

            for _, s in ipairs(slots) do
                if s.empty then
                    return s.x, s.y
                end
            end
        end
    end
end

local function getBondLeft(col, row)
    local result
    pcall(function()
        result = Events.GetBondToLevel:InvokeServer(col, row)
    end)

    if type(result) == "number" then return result end
    if type(result) == "table" then
        for _, v in pairs(result) do
            if type(v) == "number" then return v end
        end
    end
end

local function autoFeed()
    if FEED_DONE or not FeedConfig["Enable"] then return end

    local bees = getBees()
    table.sort(bees, function(a, b)
        return a.level > b.level
    end)

    local maxCount = FeedConfig["Bee Amount"] or 7
    local targetLevel = FeedConfig["Bee Level"] or 7

    local group = {}
    for i = 1, math.min(maxCount, #bees) do
        group[i] = bees[i]
    end
    if #group < maxCount then return end

    local allDone = true
    for _, b in ipairs(group) do
        if b.level < targetLevel then
            allDone = false
            break
        end
    end
    if allDone then
        FEED_DONE = true
        return
    end

    table.sort(group, function(a, b)
        return a.level < b.level
    end)

    local inv = getInventory()

    for _, b in ipairs(group) do
        if b.level < targetLevel then
            local bondLeft = getBondLeft(b.col, b.row)
            if not bondLeft or bondLeft <= 0 then return end

            local remaining = bondLeft

            for _, item in ipairs(BOND_ITEMS) do
                if remaining <= 0 then break end
                if FeedConfig["Bee Food"] and FeedConfig["Bee Food"][item.Name] then
                    local have = inv[item.Name] or 0
                    local need = math.ceil(remaining / item.Value)
                    local use = math.min(have, need)

                    if use > 0 then
                        local args = {
                            [1] = b.col,
                            [2] = b.row,
                            [3] = ITEM_KEYS[item.Name],
                            [4] = use,
                            [5] = false
                        }

                        pcall(function()
                            Events.ConstructHiveCellFromEgg:InvokeServer(unpack(args))
                        end)

                        remaining -= use * item.Value
                        task.wait(3)
                    end
                end
            end
            break
        end
    end
end

local function autoHatch()
    local cfg = Config["Auto Hatch"]
    if not cfg or not cfg["Enable"] then return end

    local col, row = findEmptySlot()
    if not col then return end

    local inv = getInventory()

    for _, egg in ipairs(cfg["Egg Hatch"]) do
        if (inv[egg] or 0) > 0 then
            local args = {
                [1] = col,
                [2] = row,
                [3] = egg,
                [4] = 1,
                [5] = false
            }

            pcall(function()
                Events.ConstructHiveCellFromEgg:InvokeServer(unpack(args))
            end)

            task.wait(3)
            return
        end
    end
end

local function autoPrinter()
    local cfg = Config["Auto Printer"]
    if not cfg or not cfg["Enable"] then return end
    if tick() - PRINTER_CD < 10 then return end

    local inv = getInventory()
    if (inv["Star Egg"] or 0) > 0 then
        PRINTER_CD = tick()
        Events.StickerPrinterActivate:FireServer("Star Egg")

        sendWebhook("Star Egg roll printer!!!", {
            { name = "Player", value = Player.Name, inline = false }
        }, 16777215)
    end
end

local function getStickerTypes()
    local folder = RS:FindFirstChild("Stickers", true)
    if not folder then return end
    local module = folder:FindFirstChild("StickerTypes")
    if not module then return end

    local ok, data = pcall(require, module)
    return ok and data or nil
end

local function buildIDMap(tbl, map, seen)
    map = map or {}
    seen = seen or {}
    if seen[tbl] then return map end
    seen[tbl] = true

    for k, v in pairs(tbl) do
        if type(v) == "table" then
            if v.ID then
                map[tonumber(v.ID)] = tostring(k)
            end
            buildIDMap(v, map, seen)
        end
    end
    return map
end

local STICKER_TYPES = getStickerTypes()
local STICKER_ID_MAP = STICKER_TYPES and buildIDMap(STICKER_TYPES) or {}
local LAST_SIGNS = {}
local HAS_STAR_SIGN = false
local WROTE_STATUS = false
local NO_STAR_TIMER = 0
local function checkQuest()
    if QUEST_DONE or Config["Check Quest"] == false then return end

    local cache = getCache()
    if not cache then return end

    local completed = deepFind(cache, "Completed")
    if not completed then return end

    for _, q in pairs(completed) do
        if tostring(q) == "Seven To Seven" then
            sendWebhook("Quest Seven To Seven done!!!!!", {
                { name = "Player", value = Player.Name, inline = false },
                { name = "Bee Count", value = tostring(#getBees()), inline = false }
            }, 16776960)

            QUEST_DONE = true
            STAR_TIMER = tick()
            break
        end
    end
end
local function checkStarSign()
    if WROTE_STATUS then return end
    if not Config["Auto Change Acc"] then return end

    local cache = getCache()
    if not cache then return end

    local received = deepFind(cache, "Received")
    if not received then return end

    local foundThisTick = false
    HAS_STAR_SIGN = false

    for id, amount in pairs(received) do
        local name = STICKER_ID_MAP[tonumber(id)]
        if name and name:lower():find("star sign") then
            HAS_STAR_SIGN = true

            if not LAST_SIGNS[name] or amount > LAST_SIGNS[name] then
                foundThisTick = true

                sendWebhook("Star Sign collected!!!", {
                    { name = "Player", value = Player.Name, inline = false },
                    { name = "Star Sign", value = name, inline = false },
                    { name = "Amount", value = tostring(amount), inline = false }
                }, 65280)

                LAST_SIGNS[name] = amount
            end
        end
    end

    local beeCount = #getBees()
    local playTime = tonumber(deepFind(cache, "PlayTime"))

    if HAS_STAR_SIGN and beeCount >= 20 and playTime == 28900 then
        local filename = Player.Name .. ".txt"
        writefile(filename, "Completed-CoStarSign")
        WROTE_STATUS = true
        return
    end

    if QUEST_DONE then
        local inv = getInventory()
        local hasStarEgg = (inv["Star Egg"] or 0) > 0

        if not hasStarEgg and not foundThisTick then
            if NO_STAR_TIMER == 0 then
                NO_STAR_TIMER = tick()
            end
        else
            NO_STAR_TIMER = 0
        end

        if NO_STAR_TIMER > 0 and tick() - NO_STAR_TIMER >= 20 then
            local filename = Player.Name .. ".txt"
            writefile(filename, "Completed-KoStarSign")
            WROTE_STATUS = true
        end
    end
end



local function handleStarTimeout()
    if not QUEST_DONE then return end
    if STAR_TIMER == 0 then return end

    if tick() - STAR_TIMER >= 20 then
        writeStatus("Completed-KoStarSign")
        STAR_TIMER = 0
    end
end

while true do
    checkStarSign()
    autoFeed()
    autoHatch()
    autoPrinter()
    checkQuest()
    handleStarTimeout()
    task.wait(5)
end
