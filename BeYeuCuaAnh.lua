print("anh jung dz v4")
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

local QUEST_DATA = {
    ["Treat Tutorial"] = { Treat = 1 },
    ["Bonding With Bees"] = { Treat = 5 },
    ["Search For A Sunflower Seed"] = { Treat = 10, SunflowerSeed = 1 },
    ["The Gist Of Jellies"] = { Treat = 15 },
    ["Search For Strawberries"] = { Treat = 20, Strawberry = 5 },
    ["Binging On Blueberries"] = { Treat = 30, Blueberry = 10 },
    ["Royal Jelly Jamboree"] = { Treat = 50 },
    ["Search For Sunflower Seeds"] = { Treat = 100, SunflowerSeed = 25 },
    ["Picking Out Pineapples"] = { Treat = 250, Pineapple = 25 },
    ["Seven To Seven"] = { Treat = 500, Blueberry = 25, Strawberry = 25 }
}

-- ================= CORE =================

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

-- ================= DATA =================

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

-- ================= QUEST =================

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

-- ================= AUTO FEED =================

local function autoFeed()
    if not FeedConfig.Enable then return end

    local quest = getCurrentQuest()
    if not quest then return end

    local isLast = (quest == "Seven To Seven")
    local reserve = QUEST_DATA[quest] or {}

    local bees = getBees()
    table.sort(bees,function(a,b) return a.level < b.level end)

    local max = FeedConfig["Bee Amount"] or 7
    local target = FeedConfig["Bee Level"] or 7

    for i=1,math.min(max,#bees) do
        local b = bees[i]
        if b.level < target then
            local bond = getBondLeft(b.col,b.row)
            if not bond then return end

            local inv = getInventory()
            local remain = bond

            for _,item in ipairs(BOND_ITEMS) do
                if remain <= 0 then break end
                if FeedConfig["Bee Food"][item.Name] then
                    local keep = isLast and 0 or (reserve[item.Name] or 0)
                    local have = (inv[item.Name] or 0) - keep
                    if have > 0 then
                        local use = math.min(have, math.ceil(remain/item.Value))
                        local args = {
                            b.col, b.row,
                            ITEM_KEYS[item.Name],
                            use, false
                        }
                        Events.ConstructHiveCellFromEgg:InvokeServer(unpack(args))
                        remain -= use * item.Value
                        task.wait(2)
                    end
                end
            end

            if remain > 0 and FeedConfig["Auto Buy Treat"] then
                local need = math.ceil(remain/10)
                local honey = Player.CoreStats.Honey.Value
                if honey >= need*10000 then
                    Events.ItemPackageEvent:InvokeServer("Purchase",{
                        Type="Treat",
                        Amount=need,
                        Category="Eggs"
                    })
                end
            end
            return
        end
    end
end

-- ================= AUTO HATCH =================

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

-- ================= AUTO PRINTER =================

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

-- ================= STAR SIGN =================

local function checkStarSign()
    if STATE.WROTE_STATUS then return end
    local cache = getCache()
    if not cache then return end

    local received = deepFind(cache,"Received") or {}
    local found = false

    for _,amt in pairs(received) do
        if tonumber(amt) and amt > 0 then
            found = true
        end
    end

    local beeCount = #getBees()
    local playTime = tonumber(deepFind(cache,"PlayTime"))

    if found and beeCount >= 20 and playTime == 28900 then
        writeStatus("Completed-CoStarSign")
        STATE.WROTE_STATUS = true
        return
    end

    if STATE.QUEST_DONE then
        local inv = getInventory()
        if (inv["Star Egg"] or 0) == 0 then
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

-- ================= QUEST CHECK =================

local function checkQuest()
    if STATE.QUEST_DONE or not Config["Check Quest"] then return end
    local cache = getCache()
    local completed = deepFind(cache,"Completed") or {}
    for _,q in pairs(completed) do
        if tostring(q) == "Seven To Seven" then
            STATE.QUEST_DONE = true
            sendWebhook("Quest Seven To Seven done!",{
                {name="Player",value=Player.Name,inline=false},
                {name="Bee Count",value=tostring(#getBees()),inline=false}
            },16776960)
        end
    end
end

-- ================= LOOP =================

while true do
    autoFeed()
    autoHatch()
    autoPrinter()
    checkQuest()
    checkStarSign()
    task.wait(5)
end
