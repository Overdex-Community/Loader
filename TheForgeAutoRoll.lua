getgenv().Configs = {
    ["Race You Want"] = {"Human","Shadow"},
    ["Enter Code"] = {"Release","SorryForUpd"}
}

local function AutoRollRace()
    local rs = game:GetService("ReplicatedStorage")
    local ok, data = pcall(require, rs:WaitForChild("ReplicaClient"))
    if not ok then return end

    local function getData()
        local res = {Race=nil,Spins=nil}
        local vt, vf = {}, {}
        local targets = {race="Race",spins="Spins"}

        local function scan(v)
            local t = typeof(v)
            if t == "function" then
                if vf[v] then return end
                vf[v] = true
                local ok2, ret = pcall(v)
                if ok2 and typeof(ret) == "table" then scan(ret) end
                return
            end
            if t ~= "table" or vt[v] then return end
            vt[v] = true
            for k,val in pairs(v) do
                local key = string.lower(tostring(k))
                if targets[key] and typeof(val) ~= "table" and typeof(val) ~= "function" then
                    res[targets[key]] = val
                end
                local tv = typeof(val)
                if tv == "table" or tv == "function" then scan(val) end
            end
        end

        scan(typeof(data) == "function" and select(2, pcall(data)) or data)
        return res
    end

    local codes = getgenv().Configs["Enter Code"] or {}
    for _,code in ipairs(codes) do
        pcall(function()
            rs.Shared.Packages.Knit.Services.CodeService.RF.RedeemCode:InvokeServer(code)
        end)
        task.wait(0.5)
    end

    while true do
        local info = getData()
        local race, spins = info.Race, info.Spins

        local good = false
        local wanted = getgenv().Configs["Race You Want"] or {}
        if race then
            local rl = string.lower(tostring(race))
            for _,v in ipairs(wanted) do
                if rl == string.lower(tostring(v)) then
                    good = true
                    break
                end
            end
        end

        if good or not spins or spins <= 0 then return end

        pcall(function()
            rs.Shared.Packages.Knit.Services.RaceService.RF.Reroll:InvokeServer()
        end)

        task.wait(5)
    end
end

AutoRollRace()
