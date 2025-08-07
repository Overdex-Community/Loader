if not game:IsLoaded() then
    game.Loaded:Wait()
end

task.wait(math.random())

local scripts = {
    [108533757090220] = 'https://cdn.shouko.dev/RokidManager/neyoshiiuem/main/gtdpre.lua',
    [123516946198836] = 'https://cdn.shouko.dev/RokidManager/neyoshiiuem/main/gtdpre.lua'
}

local url = scripts[game.PlaceId]
if url then
    task.wait(math.random())
    if game.PlaceId == 108533757090220 then
        print("in")
        while true do
            pcall(function()
                loadstring(game:HttpGet(url))()
            end)
            task.wait(10)
        end
    else
        pcall(function()
            loadstring(game:HttpGet(url))()
        end)
    end
end
