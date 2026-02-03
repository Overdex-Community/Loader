function hopSprout()
    local FILE,TTL="sproutjobid.json",600
    local WS=game:GetService("Workspace")
    local TP=game:GetService("TeleportService")
    local Http=game:GetService("HttpService")
    local Players=game:GetService("Players")
    local Player=Players.LocalPlayer
    local PID=game.PlaceId
    local SPROUT_WH="https://discord.com/api/webhooks/1467181055004905656/veMg4vsAgJa8v4mbdT5z__qAOg-1ztfubMwrM5RzfCxQa6tOY_UxB3FuBxdBFYMA8glw"

    getgenv().Config=getgenv().Config or {}
    getgenv().Config["Field Accept"]=getgenv().Config["Field Accept"] or {
        Enable=true,
        ["Field Name"]={
            "Sunflower","Dandelion","Mushroom","Blue Flower","Clover","Strawberry",
            "Spider","Bamboo","Pineapple","Stump","Cactus","Pumpkin","Pine Tree",
            "Rose","Hub","Mountain Top"
        }
    }
    local cfg=getgenv().Config["Field Accept"]

    local LAST_REQ,REQ_CD=0,8
    local BUSY=false

    local function read()
        if not isfile or not isfile(FILE) then return {} end
        local ok,d=pcall(function() return Http:JSONDecode(readfile(FILE)) end)
        return ok and d or {}
    end

    local function write(t)
        if writefile then
            writefile(FILE,Http:JSONEncode(t))
        end
    end

    local function saveJob()
        local t=read()
        local now=os.time()
        for k,v in pairs(t) do
            if now-(v.Time or 0)>=TTL then t[k]=nil end
        end
        t[game.JobId]={Time=now}
        write(t)
    end

    local function findField(pos)
        local zones=WS:FindFirstChild("FlowerZones")
        if not zones then return "Unknown" end
        for _,f in pairs(zones:GetChildren()) do
            if f:IsA("BasePart") then
                local s,c=f.Size/2,f.Position
                if pos.X>=c.X-s.X and pos.X<=c.X+s.X
                and pos.Z>=c.Z-s.Z and pos.Z<=c.Z+s.Z then
                    return f.Name
                end
            end
        end
        return "Unknown"
    end

    local function allowed(name)
        for _,v in pairs(cfg["Field Name"]) do
            if string.find(string.lower(name),string.lower(v)) then
                return true
            end
        end
        return false
    end

    local function sproutWebhook(field)
        if not request or not SPROUT_WH or SPROUT_WH=="" then return end
        local job=game.JobId
        local tpCode='game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId,"'..job..'",game.Players.LocalPlayer)'
        local data={
            embeds={{
                title="🌱 Sprout Found!",
                color=65280,
                fields={
                    {name="Field",value=field,inline=true},
                    {name="JobID",value=job,inline=false},
                    {name="Teleport",value="`"..tpCode.."`",inline=false}
                },
                footer={text="Sprout Hopper | "..os.date("%d/%m/%Y %H:%M:%S")}
            }}
        }
        pcall(function()
            request({
                Url=SPROUT_WH,
                Method="POST",
                Headers={["Content-Type"]="application/json"},
                Body=Http:JSONEncode(data)
            })
        end)
    end

    local function getServers(cursor)
        local now=tick()
        if now-LAST_REQ<REQ_CD then
            task.wait(REQ_CD-(now-LAST_REQ))
        end
        LAST_REQ=tick()

        local url="https://games.roblox.com/v1/games/"..PID.."/servers/Public?sortOrder=Asc&limit=100"
        if cursor then url=url.."&cursor="..cursor end

        local ok,data=pcall(function()
            return Http:JSONDecode(game:HttpGet(url))
        end)

        if not ok then
            task.wait(15)
            return nil
        end
        return data
    end

    local function hop()
        if BUSY then return end
        BUSY=true

        saveJob()
        local used=read()
        local cursor=nil
        local tries=0

        while tries<150 do
            local page=getServers(cursor)
            if not page then
                tries+=1
                task.wait(2)
            else
                for _,s in pairs(page.data or {}) do
                    if s.playing>0
                    and s.playing<s.maxPlayers
                    and not used[s.id]
                    and not s.privateServerId
                    and (not s.access or s.access=="Public") then
                        used[s.id]={Time=os.time()}
                        write(used)
                        TP:TeleportToPlaceInstance(PID,s.id,Player)
                        BUSY=false
                        return
                    end
                end
                cursor=page.nextPageCursor
                if not cursor then break end
            end
        end

        BUSY=false
    end

    local sprouts=WS:FindFirstChild("Sprouts")
    local sprout=sprouts and sprouts:FindFirstChild("Sprout")

    if not (sprout and sprout:IsA("MeshPart")) then
        return hop()
    end

    local field=findField(sprout.Position)
    if allowed(field) then
        sproutWebhook(field)
        sprout.AncestryChanged:Wait()
        hop()
    else
        hop()
    end
end

task.spawn(function()
    while true do
        pcall(hopSprout)
        task.wait(25)
    end
end)
