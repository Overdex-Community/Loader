print("anh jung dz v8")
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

local STATE = {
    QUEST_DONE = false,
    WROTE_STATUS = false,
    NO_STAR_TIMER = 0,
    PRINTER_CD = 0,
    LAST_SIGNS = {}
}

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
    { Name = "Moon Charm", Value = 250 },
    { Name = "Gingerbread Bear", Value = 250 },
    { Name = "Bitterberry", Value = 100 },
    { Name = "Pineapple", Value = 50 },
    { Name = "Strawberry", Value = 50 },
    { Name = "Blueberry", Value = 50 },
    { Name = "Sunflower Seed", Value = 50 },
    { Name = "Treat", Value = 10 }
}

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

local function deepFind(t, k)
    for a,b in pairs(t) do
        if a == k then return b end
        if type(b) == "table" then
            local f = deepFind(b, k)
            if f then return f end
        end
    end
end

local function sendWebhook(title, fields, color)
    pcall(function()
        request({
            Url = Config["Link Wh"],
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = Http:JSONEncode({
                content = "<@" .. tostring(Config["Ping Id"]) .. ">",
                embeds = {{
                    title = title,
                    color = color,
                    fields = fields,
                    footer = { text = "made by Jung Ganmyeon" }
                }}
            })
        })
    end)
end

local function writeStatus(text)
    if not Config["Auto Change Acc"] then return end
    pcall(function()
        writefile(Player.Name .. ".txt", text)
    end)
end
local function getInventory()
    local cache = getCache()
    if not cache or not cache.Eggs then return {} end
    local inv = {}
    for name,key in pairs(ITEM_KEYS) do
        inv[name] = tonumber(cache.Eggs[key]) or 0
    end
    return inv
end

local function getBees()
    local cache = getCache()
    local bees = {}
    if not cache or not cache.Honeycomb then return bees end
    for cx,col in pairs(cache.Honeycomb) do
        for cy,bee in pairs(col) do
            if bee and bee.Lvl then
                local x = tonumber(tostring(cx):match("%d+"))
                local y = tonumber(tostring(cy):match("%d+"))
                if x and y then
                    table.insert(bees, {col=x,row=y,level=bee.Lvl})
                end
            end
        end
    end
    return bees
end

local function getBondLeft(x,y)
    local ok,res = pcall(function()
        return Events.GetBondToLevel:InvokeServer(x,y)
    end)
    if ok and type(res) == "number" then return res end
end
local function getCurrentQuest()
    local cache = getCache()
    local completed = deepFind(cache,"Completed") or {}
    for name,_ in pairs(QUEST_DATA) do
        local done = false
        for _,q in pairs(completed) do
            if tostring(q) == name then done = true break end
        end
        if not done then return name end
    end
end

local function autoFeed()
    if FEED_DONE or not FeedConfig["Enable"] then return end

    local cache = getCache()
    if not cache then return end

    local completed = deepFind(cache, "Completed") or {}
    local inv = getInventory()

    local QUEST_TREAT_REQ = {
        ["Treat Tutorial"] = 1,
        ["Bonding With Bees"] = 5,
        ["Search For A Sunflower Seed"] = 10,
        ["The Gist Of Jellies"] = 15,
        ["Search For Strawberries"] = 20,
        ["Binging On Blueberries"] = 30,
        ["Royal Jelly Jamboree"] = 50,
        ["Search For Sunflower Seeds"] = 100,
        ["Picking Out Pineapples"] = 250,
        ["Seven To Seven"] = 500
    }

    local QUEST_FRUIT_REQ = {
        ["Search For A Sunflower Seed"] = { ["Sunflower Seed"] = 1 },
        ["Search For Strawberries"] = { ["Strawberry"] = 5 },
        ["Binging On Blueberries"] = { ["Blueberry"] = 10 },
        ["Search For Sunflower Seeds"] = { ["Sunflower Seed"] = 25 },
        ["Picking Out Pineapples"] = { ["Pineapple"] = 25 },
        ["Seven To Seven"] = { ["Blueberry"] = 25, ["Strawberry"] = 25 }
    }

    local QUEST_ORDER = {
        "Treat Tutorial",
        "Bonding With Bees",
        "Search For A Sunflower Seed",
        "The Gist Of Jellies",
        "Search For Strawberries",
        "Binging On Blueberries",
        "Royal Jelly Jamboree",
        "Search For Sunflower Seeds",
        "Picking Out Pineapples",
        "Seven To Seven"
    }

    local function isCompleted(name)
        for _, q in pairs(completed) do
            if tostring(q) == name then
                return true
            end
        end
        return false
    end

    local currentQuest
    for _, q in ipairs(QUEST_ORDER) do
        if not isCompleted(q) then
            currentQuest = q
            break
        end
    end

    if not currentQuest then
        FEED_DONE = true
        return
    end

    local isFinalQuest = (currentQuest == "Seven To Seven")

    local reserveTreat = QUEST_TREAT_REQ[currentQuest] or 0
    local reserveFruits = QUEST_FRUIT_REQ[currentQuest] or {}

    local haveTreat = inv["Treat"] or 0
    local needTreat = reserveTreat - haveTreat

    if needTreat > 0 then
        local honey = Player.CoreStats.Honey.Value
        local cost = needTreat * 10000

        if honey >= cost then
            pcall(function()
                Events.ItemPackageEvent:InvokeServer("Purchase", {
                    Type = "Treat",
                    Amount = needTreat,
                    Category = "Eggs"
                })
            end)
        end
    end

    local bees = getBees()
    if #bees == 0 then return end

    table.sort(bees, function(a, b)
        return a.level < b.level
    end)

    local maxCount = FeedConfig["Bee Amount"] or 7
    local targetLevel = FeedConfig["Bee Level"] or 7

    local targetBee

    for i = 1, math.min(maxCount, #bees) do
        if bees[i].level < targetLevel then
            targetBee = bees[i]
            break
        end
    end

    if not targetBee then
        targetBee = bees[1]
    end

    local bondLeft = getBondLeft(targetBee.col, targetBee.row)
    if not bondLeft or bondLeft <= 0 then return end

    local remaining = bondLeft
    local inventory = getInventory()

    for _, item in ipairs(BOND_ITEMS) do
        if remaining <= 0 then break end
        if FeedConfig["Bee Food"] and FeedConfig["Bee Food"][item.Name] then
            local keep = 0
            if not isFinalQuest then
                if item.Name == "Treat" then
                    keep = reserveTreat
                end
                if reserveFruits[item.Name] then
                    keep = reserveFruits[item.Name]
                end
            end

            local have = (inventory[item.Name] or 0) - keep
            if have > 0 then
                local use = math.min(have, math.ceil(remaining / item.Value))

                pcall(function()
                    Events.ConstructHiveCellFromEgg:InvokeServer(
                        targetBee.col,
                        targetBee.row,
                        ITEM_KEYS[item.Name],
                        use,
                        false
                    )
                end)

                remaining -= use * item.Value
                task.wait(2)
            end
        end
    end

    if isFinalQuest and remaining > 0 then
        local treatsNeeded = math.ceil(remaining / 10)
        local honey = Player.CoreStats.Honey.Value
        local cost = treatsNeeded * 10000

        if honey >= cost then
            pcall(function()
                Events.ItemPackageEvent:InvokeServer("Purchase", {
                    Type = "Treat",
                    Amount = treatsNeeded,
                    Category = "Eggs"
                })
            end)
        end
    end
end

local function findEmptySlot()
    for _,hive in ipairs(Workspace.Honeycombs:GetChildren()) do
        local owner = hive:FindFirstChild("Owner")
        if owner and tostring(owner.Value) == Player.Name then
            local slots = {}
            for _,cell in ipairs(hive.Cells:GetChildren()) do
                local ct = cell:FindFirstChild("CellType")
                local x = cell:FindFirstChild("CellX")
                local y = cell:FindFirstChild("CellY")
                local lock = cell:FindFirstChild("CellLocked")
                if ct and x and y and lock and not lock.Value then
                    table.insert(slots,{
                        x=x.Value,y=y.Value,
                        empty=(ct.Value=="")
                    })
                end
            end
            table.sort(slots,function(a,b)
                return a.x==b.x and a.y<b.y or a.x<b.x
            end)
            for _,s in ipairs(slots) do
                if s.empty then return s.x,s.y end
            end
        end
    end
end

local function autoHatch()
    local cfg = Config["Auto Hatch"]
    if not cfg or not cfg.Enable then return end

    local x,y = findEmptySlot()
    if not x then return end

    local inv = getInventory()
    for _,egg in ipairs(cfg["Egg Hatch"]) do
        if (inv[egg] or 0) > 0 then
            Events.ConstructHiveCellFromEgg:InvokeServer(x,y,egg,1,false)
            task.wait(3)
            return
        end
    end
end
local function autoPrinter()
    local cfg = Config["Auto Printer"]
    if not cfg or not cfg.Enable then return end
    if tick() - STATE.PRINTER_CD < 10 then return end

    local inv = getInventory()
    if (inv["Star Egg"] or 0) > 0 then
        STATE.PRINTER_CD = tick()
        Events.StickerPrinterActivate:FireServer("Star Egg")
        sendWebhook("Star Egg roll printer!!!",{
            {name="Player",value=Player.Name,inline=false}
        },16777215)
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
local function checkStarSign()
    if STATE.WROTE_STATUS then return end

    local cache = getCache()
    if not cache then return end

    local received = deepFind(cache, "Received")
    if not received then return end

    local foundThisTick = false

    for id, amount in pairs(received) do
        local name = STICKER_ID_MAP and STICKER_ID_MAP[tonumber(id)]
        if name and name:lower():find("star sign") then
            local last = STATE.LAST_SIGNS[name] or 0

            if amount > last then
                foundThisTick = true

                sendWebhook("Star Sign collected!!!", {
                    { name = "Player", value = Player.Name, inline = false },
                    { name = "Star Sign", value = name, inline = false },
                    { name = "Amount", value = tostring(amount), inline = false }
                }, 65280)

                STATE.LAST_SIGNS[name] = amount
            end
        end
    end

    local beeCount = #getBees()
    local playTime = tonumber(deepFind(cache, "PlayTime"))

    if foundThisTick and beeCount >= 20 and playTime == 28900 then
        writeStatus("Completed-CoStarSign")
        STATE.WROTE_STATUS = true
        return
    end

    if STATE.QUEST_DONE then
        local inv = getInventory()
        local hasStarEgg = (inv["Star Egg"] or 0) > 0

        if not hasStarEgg and not foundThisTick then
            if STATE.NO_STAR_TIMER == 0 then
                STATE.NO_STAR_TIMER = tick()
            elseif tick() - STATE.NO_STAR_TIMER >= 20 then
                writeStatus("Completed-KoStarSign")
                STATE.WROTE_STATUS = true
            end
        else
            STATE.NO_STAR_TIMER = 0
        end
    end
end
local function checkQuest()
    if STATE.QUEST_DONE or not Config["Check Quest"] then return end

    local cache = getCache()
    if not cache or not cache.Completed then return end

    for _,q in pairs(cache.Completed) do
        if tostring(q) == "Seven To Seven" then
            STATE.QUEST_DONE = true
            sendWebhook("Quest Seven To Seven done!", {
                {name = "Player", value = Player.Name, inline = false},
                {name = "Bee Count", value = tostring(#getBees()), inline = false}
            }, 16776960)
            return
        end
    end
end
while true do
    autoFeed()
    autoHatch()
    autoPrinter()
    checkQuest()
    checkStarSign()
    task.wait(5)
end
