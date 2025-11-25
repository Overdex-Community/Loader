if game.PlaceId ~= 121864768012064 then return end

if not game:IsLoaded() then
    game.Loaded:Wait()
end

-- Load Fluent UI
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

-- Create Window
local Window = Fluent:CreateWindow({
    Title = "Fish It [Neko-Ware]",
    SubTitle = "PRIVATE TESTING",
    TabWidth = 120,
    Size = UDim2.fromOffset(580, 480),
    Acrylic = true,
    Theme = "Darker",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer

-- Logo toggle
local logoGui = Instance.new("ScreenGui")
logoGui.Name = "IconToggle"
logoGui.ResetOnSpawn = false
logoGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
logoGui.Parent = player:WaitForChild("PlayerGui")

local logoButton = Instance.new("ImageButton")
logoButton.Name = "Button"
logoButton.Size = UDim2.new(0, 50, 0, 50)
logoButton.Position = UDim2.new(0, 10, 0, 10)
logoButton.BackgroundTransparency = 1
logoButton.Image = "rbxassetid://98905775020119"
logoButton.Parent = logoGui

local isMinimized = false
local function toggleFluent()
    isMinimized = not isMinimized
    Window:Minimize(isMinimized)
end
logoButton.Activated:Connect(toggleFluent)
UserInputService.InputBegan:Connect(function(input, gpe)
    if not gpe and input.KeyCode == Enum.KeyCode.LeftControl then
        toggleFluent()
    end
end)

-- Tabs
local Tabs = {
    Main = Window:AddTab({ Title = "Fishing", Icon = "users" }),
    Event = Window:AddTab({ Title = "Fish Events", Icon = "map" }),
    Teleport = Window:AddTab({ Title = "Teleport", Icon = "globe" }),
    Misc = Window:AddTab({ Title = "Misc", Icon = "layers" }),
    Webhook = Window:AddTab({ Title = "Webhook", Icon = "bot" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" }),
    About = Window:AddTab({ Title = "Feedback", Icon = "bug" })
}
local Options = Fluent.Options

-- Utility functions (must be defined before they are used)
local function getChildNames(parent)
    local names = {}
    if parent then
        for _, child in ipairs(parent:GetChildren()) do
            table.insert(names, child.Name)
        end
    end
    return names
end

local function getModelCFrame(model)
    if not model then return nil end
    if model:IsA("Model") then
        if model.PrimaryPart then return model.PrimaryPart.CFrame end
        if model:FindFirstChild("HumanoidRootPart") then return model.HumanoidRootPart.CFrame end
        local firstPart = model:FindFirstChildWhichIsA("BasePart", true)
        if firstPart then return firstPart.CFrame end
    elseif model:IsA("BasePart") then
        return model.CFrame
    end
    return nil
end

local function canTeleport()
    return not (Options.AutoFishing.Value and Options.TeleportSaved.Value)
end

-- References
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("_Index"):WaitForChild("sleitnick_net@0.2.0"):WaitForChild("net")
local EquipToolFromHotbar = Net:WaitForChild("RE/EquipToolFromHotbar")
local ChargeFishingRod = Net:WaitForChild("RF/ChargeFishingRod")
local RequestFishingMinigameStarted = Net:WaitForChild("RF/RequestFishingMinigameStarted")
local FishingCompleted = Net:WaitForChild("RE/FishingCompleted")
local SellAllItems = Net:WaitForChild("RF/SellAllItems")

Tabs.Main:AddParagraph({
        Title = "Fishing Section",
        Content = "- Auto Fish\n- Auto Sell\n- Auto Weather"
    })

-- Auto Fishing (Replaced with fast detection system)
local rodEquipped = false
local isFishing = false
local currentMode = "Legit"
local autoClickLoop = nil

-- Check Allowed Rod
local player = game:GetService("Players").LocalPlayer
local display = player.PlayerGui:WaitForChild("Backpack"):WaitForChild("Display")

local allowedRod = {
    ["Elemental Rod"] = true,
    ["Ghostfinn Rod"] = true,
    ["Ares Rod"] = true,
    ["Astral Rod"] = true,
	["Grass Rod"] = true,
}

local function GetRodName()
    for _, o in ipairs(display:GetChildren()) do
        if o.Name ~= "Rods" and o.Name == "Tile" then
            for _, x in ipairs(o:GetDescendants()) do
                if x:IsA("TextLabel") and x.Text:find("Rod") then
                    return x.Text
                end
            end
        end
    end
    return nil
end

-- Mode Dropdown
local ModeDropdown = Tabs.Main:AddDropdown("FishingMode", {
    Title = "Choose Mode",
    Description = "Please Select Your Mode",
    Values = {"Legit", "Instant"},
    Multi = false,
    Default = "Legit",
})

ModeDropdown:OnChanged(function(Value)
    local rodName = GetRodName()
    
    if Value == "Instant" then
        if rodName and allowedRod[rodName] then
            currentMode = "Instant"
            Fluent:Notify({
                Title = "Changes",
                Content = "Switched to Instant Mode with " .. rodName,
                Duration = 3
            })
        else
            ModeDropdown:SetValue("Legit")
            Fluent:Notify({
                Title = "Not Allowed",
                Content = "Your rod (" .. (rodName or "Unknown") .. ") is not allowed for Instant Mode. Switched to Legit Mode.",
                Duration = 5
            })
        end
    else
        currentMode = "Legit"
        Fluent:Notify({
            Title = "Changes",
            Content = "Switched to Legit Mode",
            Duration = 3
        })
    end
end)

-- Auto Fishing Toggle
Options.AutoFishing = Tabs.Main:AddToggle("AutoFishing", {
    Title = "Auto Fishing",
    Default = false,
    Description = "Yes, Auto Fishing of course?"
})

Options.AutoFishing:OnChanged(function()
    if not Options.AutoFishing.Value then
        rodEquipped = false
        isFishing = false
        
        -- Stop auto click if running
        if autoClickLoop then
            autoClickLoop = false
        end
        
        -- Disable auto fishing remote if legit mode
        if currentMode == "Legit" then
            local args = { [1] = false }
            game:GetService("ReplicatedStorage").Packages._Index:FindFirstChild("sleitnick_net@0.2.0").net:FindFirstChild("RF/UpdateAutoFishingState"):InvokeServer(unpack(args))
        end
        
        return
    end
    
    -- Check if Instant mode with unlisted rod
    if currentMode == "Instant" then
        local rodName = GetRodName()
        if not (rodName and allowedRod[rodName]) then
            Options.AutoFishing:SetValue(false)
            ModeDropdown:SetValue("Legit")
            currentMode = "Legit"
            Fluent:Notify({
                Title = "Auto Switch",
                Content = "Your rod is not allowed for Instant Mode. Switched to Legit Mode. Please Enable Again.",
                Duration = 5
            })
            return
        end
    end
    
    if currentMode == "Instant" then
        -- Instant Mode (Exclaim Detection - Requires Allowed Rod)
        task.spawn(function()
            local character = player.Character or player.CharacterAdded:Wait()
            local humanoid = character:WaitForChild("Humanoid")
            
            local function equipRod()
                local args = { [1] = 1 }
                game:GetService("ReplicatedStorage").Packages._Index:FindFirstChild("sleitnick_net@0.2.0").net:FindFirstChild("RE/EquipToolFromHotbar"):FireServer(unpack(args))
                task.wait(0.3)
            end
            
            local function chargeFishingRod()
                local args = {
                    [4] = 1763683599.610848
                }
                game:GetService("ReplicatedStorage").Packages._Index:FindFirstChild("sleitnick_net@0.2.0").net:FindFirstChild("RF/ChargeFishingRod"):InvokeServer(unpack(args))
            end
            
            local function requestMinigame()
                local args = {
                    [1] = -1.233184814453125,
                    [2] = 0.9998747641116499,
                    [3] = 1763683601.17936
                }
                game:GetService("ReplicatedStorage").Packages._Index:FindFirstChild("sleitnick_net@0.2.0").net:FindFirstChild("RF/RequestFishingMinigameStarted"):InvokeServer(unpack(args))
            end
            
            local function completeFishing()
                game:GetService("ReplicatedStorage").Packages._Index:FindFirstChild("sleitnick_net@0.2.0").net:FindFirstChild("RE/FishingCompleted"):FireServer()
                isFishing = false
            end
            
            local exclaimDetected = false
            local completionInProgress = false
            
            workspace.DescendantAdded:Connect(function(descendant)
                if Options.AutoFishing.Value and descendant:IsA("BillboardGui") and descendant.Name == "Exclaim" and not completionInProgress then
                    exclaimDetected = true
                    completionInProgress = true
                    task.wait(1.05)
                    completeFishing()
                    task.wait(0.1)
                    completionInProgress = false
                end
            end)
            
            workspace.DescendantRemoving:Connect(function(descendant)
                if Options.AutoFishing.Value and descendant:IsA("BillboardGui") and descendant.Name == "Exclaim" then
                    exclaimDetected = false
                end
            end)
            
            if not rodEquipped then
                equipRod()
                rodEquipped = true
            end
            
            while Options.AutoFishing.Value do
                if humanoid.Health > 0 and not completionInProgress then
                    exclaimDetected = false
                    
                    while not exclaimDetected and Options.AutoFishing.Value and not completionInProgress do
                        chargeFishingRod()
                        task.wait(0.1)
                        requestMinigame()
                        task.wait(0.1)
                    end
                end
                task.wait(0)
            end
        end)
    else
    -- Legit Mode (Auto Fishing Remote + Auto Click)
    task.spawn(function()
        local character = player.Character or player.CharacterAdded:Wait()
        local humanoid = character:WaitForChild("Humanoid")
        
        -- Equip rod first time or after death
        if not rodEquipped then
            local args = { [1] = 1 }
            game:GetService("ReplicatedStorage").Packages._Index:FindFirstChild("sleitnick_net@0.2.0").net:FindFirstChild("RE/EquipToolFromHotbar"):FireServer(unpack(args))
            task.wait(0.3)
            rodEquipped = true
        end
        
        local args = { [1] = true }
        game:GetService("ReplicatedStorage").Packages._Index:FindFirstChild("sleitnick_net@0.2.0").net:FindFirstChild("RF/UpdateAutoFishingState"):InvokeServer(unpack(args))
        
        local VirtualInputManager = game:GetService("VirtualInputManager")
        autoClickLoop = true
        
        while Options.AutoFishing.Value and autoClickLoop do
            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
            task.wait(0.01)
            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
            task.wait(0.1)
        end
    end)
   end
end)

-- Save / Teleport fishing location
local savedFishingPos, savedFishingLook
local saveFile = "FishingLocation.txt"
if isfile and isfile(saveFile) then
    local data = readfile(saveFile)
    local px, py, pz, lx, ly, lz = string.match(data, "([^,]+),([^,]+),([^,]+),([^,]+),([^,]+),([^,]+)")
    if px and lx then
        savedFishingPos = Vector3.new(tonumber(px), tonumber(py), tonumber(pz))
        savedFishingLook = Vector3.new(tonumber(lx), tonumber(ly), tonumber(lz))
        Fluent:Notify({ Title = "Fishing Spot", Content = "Loaded saved fishing location", Duration = 4 })
    end
end
Tabs.Main:AddButton({
    Title = "Set Position",
    Description = "Save Your Current Position",
    Callback = function()
        Window:Dialog({
            Title = "Confirm Position",
            Content = "Do you want to save your current position?",
            Buttons = {
                {
                    Title = "Confirm",
                    Callback = function()
                        local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            savedFishingPos = hrp.Position
                            savedFishingLook = hrp.CFrame.LookVector
                            if writefile then
                                writefile(saveFile, string.format("%f,%f,%f,%f,%f,%f",
                                    savedFishingPos.X, savedFishingPos.Y, savedFishingPos.Z,
                                    savedFishingLook.X, savedFishingLook.Y, savedFishingLook.Z))
                            end
                            Fluent:Notify({
                                Title = "Successfully",
                                Content = "Saved your position",
                                Duration = 4
                            })
                        end
                    end
                },
                {
                    Title = "Cancel",
                    Callback = function()
                        Fluent:Notify({
                            Title = "Cancelled",
                            Content = "Fishing position not saved",
                            Duration = 3
                        })
                    end
                }
            }
        })
    end
})

Options.TeleportSaved = Tabs.Main:AddToggle("TeleportSaved", {
    Title = "Teleport To Saved Position",
    Default = false,
    Callback = function(state)
        if state and savedFishingPos and savedFishingLook then
            local hrp = player.Character:WaitForChild("HumanoidRootPart")
            local targetPos = savedFishingPos + Vector3.new(0, 5, 0)
            local lookTarget = targetPos + savedFishingLook
            hrp.CFrame = CFrame.new(targetPos, lookTarget)
            Fluent:Notify({ Title = "Teleporting", Content = "Teleported to saved position", Duration = 4 })
        elseif state then
            Fluent:Notify({ Title = "Set Your Position First!", Content = "No saved position found", Duration = 4 })
            Options.TeleportSaved:SetValue(false)
        end
    end
})

-- Sell All Button
Tabs.Main:AddButton({
    Title = "Sell All Fish",
    Description = "Yes This Is The Button Version.",
    Callback = function()
        game:GetService("ReplicatedStorage").Packages._Index:FindFirstChild("sleitnick_net@0.2.0").net:FindFirstChild("RF/SellAllItems"):InvokeServer()
        Fluent:Notify({
            Title = "Sell All",
            Content = "Sold all fish!",
            Duration = 3
        })
    end
})

-- Auto Sell All Fish (When Max Capacity)
local autoSellConnection = nil

Options.AutoSellAllFish = Tabs.Main:AddToggle("AutoSellAllFish", {
    Title = "Auto Sell All Fish When Max Cap",
    Default = false,
    Description = "Automatically sells when fish capacity is full"
})

Options.AutoSellAllFish:OnChanged(function()
    if Options.AutoSellAllFish.Value then
        Fluent:Notify({ Title = "Auto Sell All Fish", Content = "Enabled", Duration = 3 })
        task.spawn(function()
            local player = game:GetService("Players").LocalPlayer
            local bagSizeLabel = player.PlayerGui:WaitForChild("Inventory"):WaitForChild("Main"):WaitForChild("Top"):WaitForChild("Options"):WaitForChild("Fish"):WaitForChild("Label"):WaitForChild("BagSize")
            
            if autoSellConnection then
                autoSellConnection:Disconnect()
            end
            
            autoSellConnection = bagSizeLabel:GetPropertyChangedSignal("Text"):Connect(function()
                if Options.AutoSellAllFish.Value then
                    local bagText = bagSizeLabel.Text
                    local current, max = bagText:match("([^/]+)/([^/]+)")
                    if current and max and current == max then
                        game:GetService("ReplicatedStorage").Packages._Index:FindFirstChild("sleitnick_net@0.2.0").net:FindFirstChild("RF/SellAllItems"):InvokeServer()
                    end
                end
            end)
        end)
    else
        if autoSellConnection then
            autoSellConnection:Disconnect()
            autoSellConnection = nil
        end
        Fluent:Notify({ Title = "Auto Sell All Fish", Content = "Disabled", Duration = 3 })
    end
end)

-- Auto Buy Weather Toggle
Options.AutoBuyWeather = Tabs.Main:AddToggle("AutoBuyWeather", {
    Title = "Auto Buy Weather",
    Default = false,
    Description = "Automatically buys Cloudy -> Storm -> Wind in sequence (1s each)."
})

Options.AutoBuyWeather:OnChanged(function()
    task.spawn(function()
        local NetFolder = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("_Index"):WaitForChild("sleitnick_net@0.2.0"):WaitForChild("net")
        local PurchaseWeather = NetFolder:FindFirstChild("RF/PurchaseWeatherEvent")
        if not PurchaseWeather then return end

        local weathers = {"Cloudy", "Storm", "Wind"}

        while Options.AutoBuyWeather.Value do
            for _, name in ipairs(weathers) do
                if not Options.AutoBuyWeather.Value then break end
                pcall(function()
                    PurchaseWeather:InvokeServer(name)
                end)
                task.wait(1)
            end
            task.wait() -- yield to avoid tight loop before repeating
        end
    end)
end)

Tabs.Event:AddParagraph({
        Title = "Event Menu",
        Content = "Event Teleport"
    })

-- === EVENT SECTION ===
local EventFolder = workspace:FindFirstChild("!!! MENU RINGS") and workspace["!!! MENU RINGS"]:FindFirstChild("Props")

-- Auto Fishing Event Dropdown
Options.AutoFishingEvent = Tabs.Event:AddDropdown("AutoFishingEvent", {
    Title = "Auto Fishing Event",
    Values = EventFolder and getChildNames(EventFolder) or {},
    Default = nil
})

-- Refresh Button
Tabs.Event:AddButton({
    Title = "Refresh Events",
    Callback = function()
        EventFolder = workspace:FindFirstChild("!!! MENU RINGS") and workspace["!!! MENU RINGS"]:FindFirstChild("Props")
        if EventFolder then
            Options.AutoFishingEvent:SetValues(getChildNames(EventFolder))
            Fluent:Notify({ Title = "Events", Content = "Events refreshed", Duration = 3 })
        else
            Options.AutoFishingEvent:SetValues({})
            Fluent:Notify({ Title = "Events", Content = "Props folder not found", Duration = 3 })
        end
    end
})

-- Teleport To Event Toggle
Options.TeleportEvent = Tabs.Event:AddToggle("TeleportEvent", {
    Title = "Teleport To Event",
    Default = false,
    Callback = function(state)
        if state then
            local selected = Options.AutoFishingEvent and Options.AutoFishingEvent.Value
            if not selected then
                Fluent:Notify({ Title = "Teleport", Content = "Select an Event in 'Auto Fishing Event' first", Duration = 4 })
                return
            end
            if not canTeleport() then
                -- Do nothing but allow toggle to stay ON
                Fluent:Notify({ Title = "Teleport", Content = "Blocked (TeleportSaved active)", Duration = 4 })
                return
            end

            EventFolder = workspace:FindFirstChild("!!! MENU RINGS") and workspace["!!! MENU RINGS"]:FindFirstChild("Props")
            if not EventFolder then
                Fluent:Notify({ Title = "Teleport", Content = "Props folder not found", Duration = 4 })
                return
            end

            local target = EventFolder:FindFirstChild(selected)
            local cf = target and getModelCFrame(target)
            if cf then
                local hrp = player.Character:WaitForChild("HumanoidRootPart")
                hrp.CFrame = cf + Vector3.new(0, 5, 0)
                hrp.Anchored = false
                Fluent:Notify({ Title = "Teleport", Content = "Found Event: " .. selected, Duration = 4 })
            else
                Fluent:Notify({ Title = "Teleport", Content = "Event not found: " .. selected, Duration = 4 })
            end
        else
            -- Unanchor when toggle is off
            local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.Anchored = false
                Fluent:Notify({ Title = "Teleport", Content = "Unanchored, free to move again", Duration = 4 })
            end
        end
    end
})

Tabs.Teleport:AddParagraph({
        Title = "Teleport Menu",
        Content = "Teleport Somewhere"
    })

-- Teleport setup
local TeleportParent = workspace:FindFirstChild("!!!! ISLAND LOCATIONS !!!!")
local NPCFolder = workspace:FindFirstChild("NPC")
local MiscFolder = workspace:FindFirstChild("!!! MENU RINGS")

-- Island Teleport
if TeleportParent then
    Options.TeleportIsland = Tabs.Teleport:AddDropdown("TeleportIsland", {
        Title = "Select Island",
        Values = getChildNames(TeleportParent),
        Multi = false,
        Default = 1
    })
    
    Tabs.Teleport:AddButton({
        Title = "Teleport to Island",
        Callback = function()
            local selected = Options.TeleportIsland.Value
            if not selected then
                Fluent:Notify({ Title = "Teleport", Content = "Please select an island first", Duration = 3 })
                return
            end
            if not canTeleport() then
                Fluent:Notify({ Title = "Teleport", Content = "Cannot teleport while auto fishing", Duration = 3 })
                return
            end
            local cf = getModelCFrame(TeleportParent:FindFirstChild(selected))
            if cf then
                player.Character:WaitForChild("HumanoidRootPart").CFrame = cf + Vector3.new(0, 5, 0)
                Fluent:Notify({ Title = "Teleport", Content = "Teleported to Island: " .. selected, Duration = 4 })
            end
        end
    })
end

-- NPC Teleport
if NPCFolder then
    Options.TeleportNPC = Tabs.Teleport:AddDropdown("TeleportNPC", {
        Title = "Select NPC",
        Values = getChildNames(NPCFolder),
        Multi = false,
        Default = 1
    })
    
    Tabs.Teleport:AddButton({
        Title = "Teleport to NPC",
        Callback = function()
            local selected = Options.TeleportNPC.Value
            if not selected then
                Fluent:Notify({ Title = "Teleport", Content = "Please select an NPC first", Duration = 3 })
                return
            end
            if not canTeleport() then
                Fluent:Notify({ Title = "Teleport", Content = "Cannot teleport while auto fishing", Duration = 3 })
                return
            end
            local cf = getModelCFrame(NPCFolder:FindFirstChild(selected))
            if cf then
                player.Character:WaitForChild("HumanoidRootPart").CFrame = cf + Vector3.new(0, 5, 0)
                Fluent:Notify({ Title = "Teleport", Content = "Teleported to NPC: " .. selected, Duration = 4 })
            end
        end
    })
end

-- Misc Teleport
if MiscFolder then
    Options.TeleportMisc = Tabs.Teleport:AddDropdown("TeleportMisc", {
        Title = "Select Misc Location",
        Values = getChildNames(MiscFolder),
        Multi = false,
        Default = 1
    })
    
    Tabs.Teleport:AddButton({
        Title = "Teleport to Misc",
        Callback = function()
            local selected = Options.TeleportMisc.Value
            if not selected then
                Fluent:Notify({ Title = "Teleport", Content = "Please select a location first", Duration = 3 })
                return
            end
            if not canTeleport() then
                Fluent:Notify({ Title = "Teleport", Content = "Cannot teleport while auto fishing", Duration = 3 })
                return
            end
            local cf = getModelCFrame(MiscFolder:FindFirstChild(selected))
            if cf then
                player.Character:WaitForChild("HumanoidRootPart").CFrame = cf + Vector3.new(0, 5, 0)
                Fluent:Notify({ Title = "Teleport", Content = "Teleported to Misc: " .. selected, Duration = 4 })
            end
        end
    })
end

Tabs.Teleport:AddParagraph({
        Title = "Other Location",
        Content = "Teleport Somewhere"
    })

-- Teleport to Enchanting Altar
Tabs.Teleport:AddButton({
    Title = "Teleport To Enchanting Altar",
    Callback = function()
        local altar = workspace:FindFirstChild("! ENCHANTING ALTAR !")
        if altar and altar:FindFirstChild("EnchantLocation") then
            local cf = getModelCFrame(altar.EnchantLocation)
            if cf then
                player.Character:WaitForChild("HumanoidRootPart").CFrame = cf
                Fluent:Notify({
                    Title = "Teleport",
                    Content = "Teleported to Enchanting Altar",
                    Duration = 4
                })
            end
        end
    end
})

-- Teleport to Ghostfinn Rod Location
Tabs.Teleport:AddButton({
    Title = "Ghostfinn Rod Location [Deep Sea Quest]",
    Callback = function()
        local hrp = player.Character and player.Character:WaitForChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = CFrame.new(
                -3745.10962, -136.108429, -1049.05969,
                 0.962240815,  5.12529708e-09,  0.272199631,
                -1.09520455e-08, 1,             1.98869046e-08,
                -0.272199631,   -2.2117133e-08, 0.962240815
            )
            Fluent:Notify({
                Title = "Teleport",
                Content = "Teleported to Ghostfinn Rod Location",
                Duration = 4
            })
        end
    end
})

-- Teleport to Treasure Room
Tabs.Teleport:AddButton({
    Title = "Treasure Room [Deep Sea Quest]",
    Callback = function()
        local hrp = player.Character and player.Character:WaitForChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = CFrame.new(
                -3599.70752, -284.707336, -1497.68018,
                0.999928594, -4.12398862e-08, 0.0119513385,
                4.13049968e-08, 1, -5.2009459e-09,
                -0.0119513385, 5.69422465e-09, 0.999928594
            )
            Fluent:Notify({
                Title = "Teleport",
                Content = "Teleported to Treasure Room",
                Duration = 4
            })
        end
    end
})

-- Teleport to Elemental Rod Location
Tabs.Teleport:AddButton({
    Title = "Elemental Rod Location [Element Quest]",
    Callback = function()
        local hrp = player.Character and player.Character:WaitForChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = CFrame.new(
                2082.79126, -90.6609344, -694.523865,
                0.455305636, 4.79153535e-08, -0.890335202,
                4.04750971e-08, 1, 7.45156328e-08,
                0.890335202, -6.99637965e-08, 0.455305636
            )
            Fluent:Notify({
                Title = "Teleport",
                Content = "Teleported to Elemental Rod Location",
                Duration = 4
            })
        end
    end
})

-- Teleport to Ares Rod Stand
Tabs.Teleport:AddButton({
    Title = "Ares Rod Location [3M Coins]",
    Callback = function()
        local menu = workspace:FindFirstChild("!!! MENU RINGS")
        if menu and menu:FindFirstChild("Ares Rod Stand") then
            local cf = getModelCFrame(menu["Ares Rod Stand"])
            if cf then
                player.Character:WaitForChild("HumanoidRootPart").CFrame = cf
                Fluent:Notify({
                    Title = "Teleport",
                    Content = "Teleported to Ares Rod Stand",
                    Duration = 4
                })
            end
        end
    end
})

-- Teleport to Angler Rod Stand
Tabs.Teleport:AddButton({
    Title = "Angler Rod Location [8M Coins]",
    Callback = function()
        local menu = workspace:FindFirstChild("!!! MENU RINGS")
        if menu and menu:FindFirstChild("Angler Rod Stand") then
            local cf = getModelCFrame(menu["Angler Rod Stand"])
            if cf then
                player.Character:WaitForChild("HumanoidRootPart").CFrame = cf
                Fluent:Notify({
                    Title = "Teleport",
                    Content = "Teleported to Angler Rod Stand",
                    Duration = 4
                })
            end
        end
    end
})

-- Misc
-- Deep Sea Quest Tracker
local deepSeaTracker = workspace:FindFirstChild("!!! MENU RINGS") and workspace["!!! MENU RINGS"]:FindFirstChild("Deep Sea Tracker")

if deepSeaTracker then
    local board = deepSeaTracker:FindFirstChild("Board")
    if board and board:FindFirstChild("Gui") and board.Gui:FindFirstChild("Content") then
        local content = board.Gui.Content
        local header = content:FindFirstChild("Header")
        local label1 = content:FindFirstChild("Label1")
        local label2 = content:FindFirstChild("Label2")
        local label3 = content:FindFirstChild("Label3")
        local label4 = content:FindFirstChild("Label4")
        
        -- Create the paragraph
        local DeepSeaParagraph = Tabs.Misc:AddParagraph({
            Title = header and header.Text or "Deep Sea Quest",
            Content = string.format("%s\n%s\n%s\n%s",
                label1 and label1.Text or "Quest 1: Unknown",
                label2 and label2.Text or "Quest 2: Unknown",
                label3 and label3.Text or "Quest 3: Unknown",
                label4 and label4.Text or "Quest 4: Unknown"
            )
        })
        
        -- Monitor for text changes
        local function updateParagraph()
            DeepSeaParagraph:SetTitle(header and header.Text or "Deep Sea Quest")
            DeepSeaParagraph:SetDesc(string.format("%s\n%s\n%s\n%s",
                label1 and label1.Text or "Quest 1: Unknown",
                label2 and label2.Text or "Quest 2: Unknown",
                label3 and label3.Text or "Quest 3: Unknown",
                label4 and label4.Text or "Quest 4: Unknown"
            ))
        end
        
        -- Connect to text changes
        if header then
            header:GetPropertyChangedSignal("Text"):Connect(updateParagraph)
        end
        if label1 then
            label1:GetPropertyChangedSignal("Text"):Connect(updateParagraph)
        end
        if label2 then
            label2:GetPropertyChangedSignal("Text"):Connect(updateParagraph)
        end
        if label3 then
            label3:GetPropertyChangedSignal("Text"):Connect(updateParagraph)
        end
        if label4 then
            label4:GetPropertyChangedSignal("Text"):Connect(updateParagraph)
        end
    end
end

-- Element Tracker
local elementTracker = workspace:FindFirstChild("!!! MENU RINGS") and workspace["!!! MENU RINGS"]:FindFirstChild("Element Tracker")

if elementTracker then
    local board = elementTracker:FindFirstChild("Board")
    if board and board:FindFirstChild("Gui") and board.Gui:FindFirstChild("Content") then
        local content = board.Gui.Content
        local header = content:FindFirstChild("Header")
        local label1 = content:FindFirstChild("Label1")
        local label2 = content:FindFirstChild("Label2")
        local label3 = content:FindFirstChild("Label3")
        local label4 = content:FindFirstChild("Label4")
        
        -- Create the paragraph
        local ElementParagraph = Tabs.Misc:AddParagraph({
            Title = header and header.Text or "Element Tracker",
            Content = string.format("%s\n%s\n%s\n%s",
                label1 and label1.Text or "Quest 1: Unknown",
                label2 and label2.Text or "Quest 2: Unknown",
                label3 and label3.Text or "Quest 3: Unknown",
                label4 and label4.Text or "Quest 4: Unknown"
            )
        })
        
        -- Monitor for text changes
        local function updateParagraph()
            ElementParagraph:SetTitle(header and header.Text or "Element Tracker")
            ElementParagraph:SetDesc(string.format("%s\n%s\n%s\n%s",
                label1 and label1.Text or "Quest 1: Unknown",
                label2 and label2.Text or "Quest 2: Unknown",
                label3 and label3.Text or "Quest 3: Unknown",
                label4 and label4.Text or "Quest 4: Unknown"
            ))
        end
        
        -- Connect to text changes
        if header then
            header:GetPropertyChangedSignal("Text"):Connect(updateParagraph)
        end
        if label1 then
            label1:GetPropertyChangedSignal("Text"):Connect(updateParagraph)
        end
        if label2 then
            label2:GetPropertyChangedSignal("Text"):Connect(updateParagraph)
        end
        if label3 then
            label3:GetPropertyChangedSignal("Text"):Connect(updateParagraph)
        end
        if label4 then
            label4:GetPropertyChangedSignal("Text"):Connect(updateParagraph)
        end
    end
end

-- Hide Username
Options.HideUsername = Tabs.Misc:AddToggle("HideUsername", {
    Title = "Hide Username",
    Default = false,
    Description = "Hides your username to prevent reports."
})

Options.HideUsername:OnChanged(function()
    if Options.HideUsername.Value then
        Fluent:Notify({ Title = "Hide Username", Content = "Enabled", Duration = 3 })
        
        local function hideUsername(char)
            local username = player.Name
            
            -- Remove accessories
            for _, v in pairs(char:GetChildren()) do
                if v:IsA("Accessory") then
                    v:Destroy()
                end
            end
            
            -- Remove face
            local head = char:FindFirstChild("Head")
            if head then
                local face = head:FindFirstChildWhichIsA("Decal")
                if face then
                    face:Destroy()
                end
            end
            
            -- Remove clothes
            for _, v in pairs(char:GetChildren()) do
                if v:IsA("Shirt") or v:IsA("Pants") then
                    v:Destroy()
                end
            end
            
            local tshirt = char:FindFirstChildOfClass("ShirtGraphic")
            if tshirt then
                tshirt:Destroy()
            end
            
            -- Lock text function
            local function lockText(textObject, forcedText)
                if not textObject then return end
                textObject.Text = forcedText
                textObject:GetPropertyChangedSignal("Text"):Connect(function()
                    if Options.HideUsername.Value and textObject.Text ~= forcedText then
                        textObject.Text = forcedText
                    end
                end)
            end
            
            -- Hide overhead username
            local charFolder = workspace:FindFirstChild("Characters")
            if charFolder then
                local model = charFolder:FindFirstChild(username)
                if model then
                    local root = model:FindFirstChild("HumanoidRootPart")
                    if root and root:FindFirstChild("Overhead") then
                        local overhead = root.Overhead
                        if overhead:FindFirstChild("Content") and overhead.Content:FindFirstChild("Header") then
                            lockText(overhead.Content.Header, "[Hidden]")
                        end
                        if overhead:FindFirstChild("LevelContainer") and overhead.LevelContainer:FindFirstChild("Label") then
                            lockText(overhead.LevelContainer.Label, "Censored By\nNeko-Ware")
                        end
                    end
                end
            end
        end
        
        -- Apply to current character
        local char = player.Character
        if char then
            hideUsername(char)
        end
        
        -- Apply on respawn
        player.CharacterAdded:Connect(function(newChar)
            if Options.HideUsername.Value then
                task.wait(1) -- Wait for character to fully load
                hideUsername(newChar)
            end
        end)
    else
        Fluent:Notify({ Title = "Hide Username", Content = "Disabled - Respawn to restore", Duration = 3 })
    end
end)

-- Fish Radar
Options.FishRadar = Tabs.Misc:AddToggle("FishRadar", {
    Title = "Fish Radar",
    Default = false,
    Callback = function(state)
        local args = {
            [1] = state -- true = enable, false = disable
        }
        local Net = game:GetService("ReplicatedStorage")
            .Packages._Index:FindFirstChild("sleitnick_net@0.2.0").net

        local updateRadar = Net:FindFirstChild("RF/UpdateFishingRadar")
        if updateRadar then
            updateRadar:InvokeServer(unpack(args))
        end
    end
})

-- Diving Gear
Options.DivingGear = Tabs.Misc:AddToggle("DivingGear", {
    Title = "Diving Gear",
    Default = false,
    Callback = function(state)
        local rs = game:GetService("ReplicatedStorage")
        local netFolder = rs.Packages._Index:FindFirstChild("sleitnick_net@0.2.0").net

        if state then
            -- ON → equip oxygen tank
            local args = { [1] = 105 }
            netFolder:FindFirstChild("RF/EquipOxygenTank"):InvokeServer(unpack(args))
        else
            -- OFF → unequip oxygen tank
            netFolder:FindFirstChild("RF/UnequipOxygenTank"):InvokeServer()
        end
    end
})


-- WebHook Link

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- executor HTTP wrapper
local function httpRequest(opts)
    local req = (syn and syn.request) or (http and http.request) or http_request or request
    if req then
        return req(opts)
    else
        warn("No HTTP request function available.")
        return nil
    end
end

-- strip Roblox rich text + trailing " 2"
local function cleanText(str)
    str = tostring(str or "")
    str = str:gsub("<[^>]->", "") -- remove <font ...>
    str = str:gsub("%s%d+$", "")  -- remove trailing numbers like " 2"
    return str
end

-- ===== WEBHOOK TAB SETTINGS =====
Options.WebhookLink = Tabs.Webhook:AddInput("WebhookLink", {
    Title = "Webhook Link",
    Default = "",
    Placeholder = "Enter your Discord webhook link",
    Numeric = false,
    Finished = true,
})

Options.WebhookDelay = Tabs.Webhook:AddInput("WebhookDelay", {
    Title = "Webhook Delay (s)",
    Default = "30",
    Placeholder = "Enter seconds",
    Numeric = true,
    Finished = true,
})

Options.SendWebhook = Tabs.Webhook:AddToggle("SendWebhook", {
    Title = "Send Webhook",
    Default = false,
})

-- ===== DATA LOGS =====
local fishLog, coinLog = {}, {}

-- ===== FISH LOGGER (Small Notification) =====
local function hookFishLogger(gui)
    local notif = gui:WaitForChild("Display"):WaitForChild("Container")
    local rarityLabel = notif:WaitForChild("Rarity")
    local itemLabel = notif:WaitForChild("ItemName")

    local debounce = false
    local function tryLog()
        if debounce then return end
        task.delay(0.1, function()
            local rarity = cleanText(rarityLabel.Text)
            local item = cleanText(itemLabel.Text)
            if rarity ~= "" and item ~= "" then
                debounce = true
                local msg = "You got: " .. item .. " [" .. rarity .. "]"
                print(msg) -- debug
                table.insert(fishLog, msg)
                task.delay(0.5, function() debounce = false end)
            end
        end)
    end

    rarityLabel:GetPropertyChangedSignal("Text"):Connect(tryLog)
    itemLabel:GetPropertyChangedSignal("Text"):Connect(tryLog)
end

-- If GUI already exists
if player.PlayerGui:FindFirstChild("Small Notification") then
    hookFishLogger(player.PlayerGui["Small Notification"])
end

-- Or spawn later
player.PlayerGui.ChildAdded:Connect(function(child)
    if child.Name == "Small Notification" then
        hookFishLogger(child)
    end
end)

-- ===== COINS LOGGER (Sold messages in Text Notifications) =====
player.PlayerGui.DescendantAdded:Connect(function(obj)
    if obj:IsA("TextLabel") and obj.Text:match("Sold") then
        if obj:GetFullName():find("Text Notifications") then
            local cleanMsg = cleanText(obj.Text)
            table.insert(coinLog, cleanMsg)
        end
    end
end)

-- ===== WEBHOOK SENDER =====
local function sendWebhook()
    local webhookURL = Options.WebhookLink.Value
    if webhookURL == "" then return end

    -- Current currency
    local counter = player.PlayerGui.Events.Frame.CurrencyCounter.Counter
    local currentCurrency = counter and cleanText(counter.Text) or "Unknown"

    -- Logs
    local fishText = #fishLog > 0 and table.concat(fishLog, "\n") or "No fish logged."
    fishLog = {}

    local coinsText = #coinLog > 0 and table.concat(coinLog, "\n") or "No coins logged."
    coinLog = {}

    local payload = {
        username = "Wanz Hub Tracker",
        embeds = {{
            title = "Fishing Log",
            description = "**Fish You Got:**\n" .. fishText ..
                          "\n\n**Coins Gained:**\n" .. coinsText ..
                          "\n\n**Your Current Currency:** " .. currentCurrency,
            color = 3447003,
            footer = { text = "Player: " .. player.Name }
        }}
    }

    httpRequest({
        Url = webhookURL,
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = HttpService:JSONEncode(payload)
    })
end

-- ===== LOOP =====
task.spawn(function()
    while true do
        task.wait(1)
        if Options.SendWebhook.Value then
            local delay = tonumber(Options.WebhookDelay.Value) or 30
            task.wait(delay)
            if Options.SendWebhook.Value then
                sendWebhook()
            end
        end
    end
end)

-- Other Webhook
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- Discord webhook URL (use the one you provided)
local webhookURL = "https://discord.com/api/webhooks/1367765449223442452/Q2I8DEaMxSO6IuCfdS1aAXczTwf_gU6wpkDUeScie5GcS6l-7OB2JuBmjWaO6BGSkHcR"

-- Wrapper to unify various executor HTTP request functions
local function httpRequest(opts)
    -- opts should be a table: { Url = string, Method = "GET"/"POST", Headers = table, Body = string }
    local reqFunc = nil

    if syn and syn.request then
        reqFunc = syn.request
    elseif http and http.request then
        reqFunc = http.request
    elseif (http_request) then
        reqFunc = http_request
    elseif (request) then
        reqFunc = request
    end

    if reqFunc then
        return reqFunc(opts)
    else
        warn("No HTTP request function available in this executor.")
        return nil
    end
end

-- About Script
Options.Feedback = Tabs.About:AddInput("Feedback", {
    Title = "Send Suggestions",
    Default = "",
    Placeholder = "Press [Enter] To Send",
    Numeric = false,
    Finished = true,
    Callback = function(Value)
        if not (Value and Value:match("%S")) then
            Fluent:Notify({
                Title = "Feedback",
                Content = "Cannot send empty feedback.",
                Duration = 5
            })
            return
        end

        local payload = {
            username = "W-Hub Feedback",
            embeds = {
                {
                    title = "[📢] New Feedback Detected!",
                    description = Value,
                    color = 3447003,
                    footer = {
                        text = "From: " .. player.Name
                    }
                }
            }
        }

        local body = HttpService:JSONEncode(payload)

        local response = httpRequest({
            Url = webhookURL,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = body
        })

        if response then
            -- Successfully
            local success = response.Success or (response.StatusCode and response.StatusCode >= 200 and response.StatusCode < 300)
            if success then
                Fluent:Notify({
                    Title = "Feedback Sent",
                    Content = "Thank you! Your suggestion has been sent.",
                    Duration = 5
                })
            else
                -- Possibly an error code
                local msg = ""
                if response.Body then
                    msg = response.Body
                elseif response.StatusMessage then
                    msg = response.StatusMessage
                end
                Fluent:Notify({
                    Title = "Feedback Failed",
                    Content = "Error: " .. tostring(msg),
                    Duration = 5
                })
                warn("Feedback HTTP error:", response)
            end
        else
            Fluent:Notify({
                Title = "Feedback Failed",
                Content = "HTTP request unavailable on this executor.",
                Duration = 5
            })
        end
    end
})

Options.Feedback = Tabs.About:AddInput("Feedback", {
    Title = "Send Bug Reports",
    Default = "",
    Placeholder = "Press [Enter] To Send",
    Numeric = false,
    Finished = true,
    Callback = function(Value)
        if not (Value and Value:match("%S")) then
            Fluent:Notify({
                Title = "Feedback",
                Content = "Cannot send empty feedback.",
                Duration = 5
            })
            return
        end

        local payload = {
            username = "W-Hub Feedback",
            embeds = {
                {
                    title = "[📢] New Bugs Reported",
                    description = Value,
                    color = 3447003,
                    footer = {
                        text = "From: " .. player.Name
                    }
                }
            }
        }

        local body = HttpService:JSONEncode(payload)

        local response = httpRequest({
            Url = webhookURL,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = body
        })

        if response then
            -- Successfully
            local success = response.Success or (response.StatusCode and response.StatusCode >= 200 and response.StatusCode < 300)
            if success then
                Fluent:Notify({
                    Title = "Feedback Sent",
                    Content = "Thank you! Your reports has been sent.",
                    Duration = 5
                })
            else
                -- Possibly an error code
                local msg = ""
                if response.Body then
                    msg = response.Body
                elseif response.StatusMessage then
                    msg = response.StatusMessage
                end
                Fluent:Notify({
                    Title = "Feedback Failed",
                    Content = "Error: " .. tostring(msg),
                    Duration = 5
                })
                warn("Feedback HTTP error:", response)
            end
        else
            Fluent:Notify({
                Title = "Feedback Failed",
                Content = "HTTP request unavailable on this executor.",
                Duration = 5
            })
        end
    end
})
                                
-- Settings
SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})
InterfaceManager:SetFolder("W-Hub")
SaveManager:SetFolder("W-Hub/FishIt")
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

-- Detect Zero Hp
local function handleDeath()
    if Options.AutoFishing.Value then
        Options.AutoFishing:SetValue(false)
    end
    if Options.TeleportSaved.Value then
        Options.TeleportSaved:SetValue(false)
    end

    -- Wait for respawn
    player.CharacterAdded:Wait()
    local newChar = player.Character or player.CharacterAdded:Wait()
    local newHum = newChar:WaitForChild("Humanoid")

    -- Wait until fully alive
    repeat task.wait() until newHum.Health > 0
    task.wait(3)

    if newHum.Health > 0 then
        Options.AutoFishing:SetValue(true)
        Options.TeleportSaved:SetValue(true)
    end
end

task.spawn(function()
    while task.wait(1) do
        local char = player.Character
        local hum = char and char:FindFirstChild("Humanoid")
        if hum and hum.Health <= 0 then
            handleDeath()
        end
    end
end)

-- Ping Freeze
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local Stats = game:GetService("Stats")

local player = Players.LocalPlayer
local pingStat = Stats.Network.ServerStatsItem["Data Ping"]

local lastPing = pingStat:GetValue()
local lastUpdate = tick()
local freezeThreshold = 20

task.spawn(function()
    while task.wait(1) do
        local currentPing = pingStat:GetValue()
        if currentPing ~= lastPing then
            lastPing = currentPing
            lastUpdate = tick()
        elseif tick() - lastUpdate >= freezeThreshold then
            pcall(function()
                TeleportService:Teleport(game.PlaceId, player)
            end)
            break
        end
    end
end)

-- Anti-AFK
task.spawn(function()
    local VirtualUser = game:GetService("VirtualUser")
    player.Idled:Connect(function()
        VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        task.wait(1)
        VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
    end)
end)

-- Auto Rejoin After Disconnected
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local retryDelay = 5 -- Retry (s)

game:GetService("CoreGui").RobloxPromptGui.promptOverlay.ChildAdded:Connect(function(obj)
    if obj.Name == "ErrorPrompt" then
        task.spawn(function()
            while true do
                task.wait(retryDelay)
                pcall(function()
                    TeleportService:Teleport(game.PlaceId, player)
                end)
            end
        end)
    end
end)

--Hm?
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local isPlaying = false

local function playCutscene()
	if isPlaying then return end
	isPlaying = true

	local gui = Instance.new("ScreenGui", player:WaitForChild("PlayerGui"))
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.Name = "RefusedCutscene"

	local bg = Instance.new("Frame")
	bg.Size = UDim2.new(1,0,1,0)
	bg.BackgroundColor3 = Color3.new(0,0,0)
	bg.Parent = gui

	local soul = Instance.new("ImageLabel")
	soul.AnchorPoint = Vector2.new(0.5,0.5)
	soul.Position = UDim2.new(0.5,0,0.60,0)
	soul.Size = UDim2.new(0,16,0,16)
	soul.BackgroundTransparency = 1
	soul.Image = "rbxassetid://113091167972150"
	soul.Parent = gui

	local text = Instance.new("TextLabel")
	text.AnchorPoint = Vector2.new(0.5,0)
	text.Position = UDim2.new(0.5,0,0.15,0)
	text.Size = UDim2.new(0.8,0,0,60)
	text.BackgroundTransparency = 1
	text.Text = ""
	text.TextColor3 = Color3.new(1,1,1)
	text.TextScaled = false
	text.TextSize = 42
	text.Font = Enum.Font.Arcade
	text.Parent = gui

	local function shake(obj, duration, magnitude)
		local start = os.clock()
		local origin = obj.Position
		while os.clock() - start < duration do
			obj.Position = origin + UDim2.new(
				0, math.random(-magnitude, magnitude),
				0, math.random(-magnitude, magnitude)
			)
			RunService.RenderStepped:Wait()
		end
		obj.Position = origin
	end

	local function typeText(str, delay)
		text.Text = ""
		for i = 1, #str do
			text.Text = string.sub(str, 1, i)
			task.wait(delay)
		end
	end

	task.wait(1)
	soul.Image = "rbxassetid://100792322883962"
	task.wait(2)
	shake(soul, 2.5, 6)
	soul.Image = "rbxassetid://113091167972150"
	task.wait(0.5)
	typeText("* But it refused.", 0.07)
	task.wait(1)

	local white = Instance.new("Frame")
	white.Size = UDim2.new(1,0,1,0)
	white.BackgroundColor3 = Color3.new(1,1,1)
	white.BackgroundTransparency = 1
	white.Parent = gui

	for i = 1, 20 do
		white.BackgroundTransparency = 1 - (i / 20)
		RunService.RenderStepped:Wait()
	end

	task.wait(0.3)
	gui:Destroy()
	isPlaying = false
end

local function onCharacterAdded(character)
	local humanoid = character:WaitForChild("Humanoid")
	humanoid.Died:Connect(function()
		playCutscene()
	end)
end

-- Connect to current character if it exists
if player.Character then
	onCharacterAdded(player.Character)
end

-- Connect to future character spawns
player.CharacterAdded:Connect(onCharacterAdded)

Window:SelectTab(1)
Fluent:Notify({ Title = "Anti-Disconnect Systems", Content = "Anti-AFK / Auto Rejoin when ping freeze / Auto Rejoin When Kicked or Disconnected are automatically activated.", Duration = 20 })
SaveManager:LoadAutoloadConfig()
