print("anh jung dz")
repeat task.wait() until game:IsLoaded() and game.Players.LocalPlayer

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

local LAST_STAR = {}
local QUEST_DONE = false
local FEED_DONE = false
local PRINTER_CD = 0

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

local function sendWebhook(title, fields, color)
    local data = {
        content = "<@" .. tostring(getgenv().Config["Ping Id"]) .. ">",
        embeds = {{
            title = title,
            color = color,
            fields = fields,
            footer = { text = "made by Jung Ganmyeon" }
        }}
    }

    pcall(function()
        request({
            Url = getgenv().Config["Link Wh"],
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

local function getHive()
    for _, hive in pairs(Workspace.Honeycombs:GetChildren()) do
        if hive:FindFirstChild("Owner") and hive.Owner.Value == Player.Name then
            return hive
        end
    end
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

local function getTopBees(bees, amount)
    table.sort(bees, function(a,b)
        return a.level > b.level
    end)

    local out = {}
    for i = 1, math.min(amount, #bees) do
        out[i] = bees[i]
    end
    return #out == amount and out or nil
end

local function findEmptySlot()
    local hives = Workspace:WaitForChild("Honeycombs")

    for _, hive in ipairs(hives:GetChildren()) do
        local owner = hive:FindFirstChild("Owner")
        local isMine = false

        if owner and owner:IsA("ObjectValue") and owner.Value == Player then
            isMine = true
        elseif owner and owner:IsA("StringValue") and owner.Value == Player.Name then
            isMine = true
        elseif owner and owner:IsA("IntValue") and owner.Value == Player.UserId then
            isMine = true
        end

        if isMine then
            local cells = hive:WaitForChild("Cells")
            local slots = {}

            for _, cell in ipairs(cells:GetChildren()) do
                local bee = cell:FindFirstChild("Bee")
                local x = cell:FindFirstChild("CellX")
                local y = cell:FindFirstChild("CellY")

                if bee and x and y and bee:IsA("ObjectValue") then
                    table.insert(slots, {
                        x = x.Value,
                        y = y.Value,
                        empty = bee.Value == nil
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

local function buyTreat()
    local cfg = getgenv().Config["Auto Feed"]
    if not cfg or not cfg["Auto Buy Treat"] then return end

    local honey = Player.CoreStats.Honey.Value
    if honey < 10000000 then return end

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

local function feedBee(col, row, bondLeft)
    buyTreat()
    local inv = getInventory()
    local remaining = bondLeft
    local cfg = getgenv().Config["Auto Feed"]

    for _, item in ipairs(BOND_ITEMS) do
        if remaining <= 0 then break end
        if cfg["Bee Food"][item.Name] then
            local have = inv[item.Name] or 0
            if have > 0 then
                local need = math.ceil(remaining / item.Value)
                local use = math.min(have, need)

                local args = {
                    [1] = col,
                    [2] = row,
                    [3] = ITEM_KEYS[item.Name],
                    [4] = use,
                    [5] = false
                }

                pcall(function()
                    Events.ConstructHiveCellFromEgg:InvokeServer(unpack(args))
                end)

                remaining -= (use * item.Value)
                task.wait(3)
            end
        end
    end
end

local function autoFeed()
    if FEED_DONE or not FeedConfig["Enable"] then return end

    local cache = getCache()
    if not cache or not cache.Honeycomb then return end

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

    table.sort(bees, function(a, b)
        return a.level > b.level
    end)

    local maxCount = FeedConfig["Bee Amount"] or 7
    local targetLevel = FeedConfig["Bee Level"] or 7

    local group = {}
    for i = 1, math.min(maxCount, #bees) do
        table.insert(group, bees[i])
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

    for _, b in ipairs(group) do
        if b.level < targetLevel then
            local bondLeft = getBondLeft(b.col, b.row)
            if not bondLeft or bondLeft <= 0 then return end

            local inv = getInventory()
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
                            [3] = item.Name,
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

            if remaining > 0 and FeedConfig["Auto Buy Treat"] and checkSunflowerQuest() then
                local treatsNeeded = math.ceil(remaining / 10)
                local honey = getHoney()
                local cost = treatsNeeded * 10000

                if honey >= cost then
                    local args = {
                        [1] = "Purchase",
                        [2] = {
                            ["Type"] = "Treat",
                            ["Amount"] = treatsNeeded,
                            ["Category"] = "Eggs"
                        }
                    }

                    pcall(function()
                        Events.ItemPackageEvent:InvokeServer(unpack(args))
                    end)
                end
            end

            break
        end
    end
end

local function autoHatch()
    local cfg = getgenv().Config["Auto Hatch"]
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
    local cfg = getgenv().Config["Auto Printer"]
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

local function checkQuest()
    if QUEST_DONE or getgenv().Config["Check Quest"] == false then return end

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
            return
        end
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

local function checkStarSign()
    local cache = getCache()
    if not cache then return end

    local received = deepFind(cache, "Received")
    if not received then return end

    local inventory = {}

    for id, amount in pairs(received) do
        local name = STICKER_ID_MAP[tonumber(id)]
        if name and name:lower():find("star sign") then
            inventory[name] = amount
        end
    end

    for name, amt in pairs(inventory) do
        if not LAST_SIGNS[name] or amt > LAST_SIGNS[name] then
            local list = ""
            for n, c in pairs(inventory) do
                list = list .. "- " .. n .. ": " .. c .. "\n"
            end

            sendWebhook("Star Sign collected!!!", {
                { name = "Player", value = Player.Name, inline = false },
                { name = "Star Sign", value = name, inline = false },
                { name = "Amount", value = tostring(amt), inline = false },
                { name = "Inventory", value = list ~= "" and list or "None", inline = false }
            }, 65280)

            LAST_SIGNS[name] = amt
        end
    end
end

while true do
    checkStarSign()
    autoFeed()
    autoHatch()
    autoPrinter()
    checkQuest()
    task.wait(5)
end
