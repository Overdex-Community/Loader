-- Starlight “full features” demo (theo docs)
-- ⚠️ Chỉ để tham khảo API. Không hỗ trợ dùng với executor vi phạm ToS.

--[[
Docs liên quan:
- Booting libs / Returns: .Folder/.WindowKeybind/.ConfigSystem/.Notifications, v.v. 
- Window params: Name, Subtitle, Icon, LoadingSettings, ConfigurationSettings, DefaultSize...
- Tab Section / Tabs / Groupboxes
- Elements: Notifications, Buttons, Toggles, Sliders, Inputs, Texts (Label/Paragraph)
- Nested: Binds, Color Picker, Dropdown
- Extras: BuildConfigGroupbox, LoadAutoloadConfig, OnDestroy
]]

-- (Nếu bạn đang trong môi trường có Starlight):
getgenv().InterfaceName = function() return "Shouko Test Lib" end -- optional theo docs
local Starlight   = loadstring(game:HttpGet("https://raw.nebulasoftworks.xyz/starlight"))()
local NebulaIcons = loadstring(game:HttpGet("https://raw.nebulasoftworks.xyz/nebula-icon-library-loader"))()

-- Giả định Starlight/NebulaIcons đã sẵn sàng:

-- 1) Tạo WINDOW (Windows → Creation Snippet + params)
local Window = Starlight:CreateWindow({
    Name  = "MyScript",
    Subtitle = "v1.0 demo",
    Icon  = 123456789, -- ID icon (rbxassetid mà không cần prefix), theo docs

    LoadingSettings = {
        Title    = "My Script Hub",
        Subtitle = "Starlight Demo",
        -- Icon = 987654321, -- (không bắt buộc)
    },

    ConfigurationSettings = {
        FolderName = "MyScript",   -- nơi lưu config theo docs
        -- RootFolder = "MyHub",   -- (không bắt buộc)
    },

    -- DefaultSize = UDim2.fromOffset(900, 600), -- (không bắt buộc, cân nhắc vì có thể làm vỡ layout)
    -- BuildWarnings = true,
    -- InterfaceAdvertisingPrompts = false,
    -- NotifyOnCallbackError = true,
})

-- 2) TAB SECTION (có thể ẩn tiêu đề để làm dashboard gọn)
local SectionHome = Window:CreateTabSection("Home", true)  -- Visible=true
local SectionMain = Window:CreateTabSection("Main")        -- bình thường

-- 3) TABS (Tabs → Creation Snippet)
local HomeTab = SectionHome:CreateTab({
    Name    = "Dashboard",
    Icon    = NebulaIcons and NebulaIcons:GetIcon('dashboard', 'Material') or nil,
    Columns = 2,
}, "HOME")

local MainTab = SectionMain:CreateTab({
    Name    = "Main",
    Icon    = NebulaIcons and NebulaIcons:GetIcon('view_in_ar', 'Material') or nil,
    Columns = 2, -- theo khuyến nghị 1–3
}, "MAINTAB")

-- 4) GROUPBOXES (Groupboxes)
local GB_Left  = MainTab:CreateGroupbox({ Name = "Controls", Column = 1 }, "GB_LEFT")
local GB_Right = MainTab:CreateGroupbox({ Name = "Info / Preview", Column = 2 }, "GB_RIGHT")

-- 5) ELEMENTS — Notifications (global)
local _ = Starlight:Notification({
    Title   = "Hello!",
    Icon    = NebulaIcons and NebulaIcons:GetIcon('sparkle', 'Material') or nil,
    Content = "Welcome to the Starlight full-feature demo.",
    -- Duration = 5, -- nếu không set sẽ dùng “Smart Read-times” theo docs
}, "WELCOME")

-- 6) ELEMENTS — Button
local Btn = GB_Left:CreateButton({
    Name = "Run Action",
    Icon = NebulaIcons and NebulaIcons:GetIcon('check', 'Material') or nil,
    Tooltip = "Click to run an action",
    Style = 1,             -- style tuỳ chọn (1/2 theo docs)
    IndicatorStyle = 1,    -- 1 chevron / 2 fingerprint / nil none
    Callback = function()
        Starlight:Notification({
            Title = "Action",
            Content = "Button callback executed.",
            Icon = NebulaIcons and NebulaIcons:GetIcon('bolt', 'Material') or nil,
        }, "BTN_OK")
    end,
}, "BTN_RUN")

-- 7) ELEMENTS — Toggle (+ nested bind/color/dropdown demo)
local Tog = GB_Left:CreateToggle({
    Name = "Master Toggle",
    CurrentValue = false,
    Style = 2, -- 1 checkbox / 2 switch
    Tooltip = "Enable or disable a feature",
    Callback = function(on)
        Starlight:Notification({
            Title = "Toggle",
            Content = ("Master is %s"):format(on and "ON" or "OFF")
        }, "TOG_NOTE")
    end,
}, "MASTER_TOGGLE")

-- Nested: BIND (parent có thể là Label hoặc Toggle; ở đây là Toggle)
local Bind = Tog:AddBind({
    HoldToInteract   = false,
    CurrentValue     = "Q", -- theo docs: string key, MB1/MB2 cho chuột
    SyncToggleState  = true, -- đồng bộ với toggle
    -- Callback không cần lặp lại nếu parent là toggle (có thể thêm phụ trợ)
    OnChangedCallback = function(newKey)
        Starlight:Notification({ Title = "Bind Changed", Content = "New key: "..tostring(newKey) }, "BIND_CHG")
    end,
}, "MASTER_BIND")

-- Nested: COLOR PICKER (parent Label/Toggle; ở đây dùng Toggle)
local ColorPick = Tog:AddColorPicker({
    CurrentValue = Color3.fromRGB(33, 217, 64),
    -- Transparency = 0.25, -- (tuỳ chọn; nil nếu không muốn alpha)
    Callback = function(color, alpha)
        Starlight:Notification({
            Title = "Color",
            Content = ("R:%d G:%d B:%d  α:%s")
                :format(color.R*255, color.G*255, color.B*255, alpha and tostring(alpha) or "nil")
        }, "COLOR_NOTE")
    end,
}, "MASTER_COLOR")

-- Nested: DROPDOWN (parent Label/Toggle; demo đặt trên một Label riêng)
local InfoLabel = GB_Left:CreateLabel({ Name = "Mode:" }, "LBL_MODE")
local ModeDD = InfoLabel:AddDropdown({
    Options         = {"Steady", "Burst", "Wave"},
    CurrentOptions  = {"Steady"},
    MultipleOptions = false,
    Placeholder     = "Select Mode",
    -- Special = 1/2 (Players/Teams) nếu muốn danh sách đặc biệt
    Callback = function(options)
        Starlight:Notification({
            Title = "Mode",
            Content = "Selected: " .. table.concat(options, ", ")
        }, "MODE_NOTE")
    end,
}, "MODE_DD")

-- 8) ELEMENTS — Slider
local Sld = GB_Left:CreateSlider({
    Name       = "Intensity",
    Icon       = NebulaIcons and NebulaIcons:GetIcon('bar-chart', 'Lucide') or nil,
    Range      = {0, 100},
    Increment  = 1,
    Suffix     = "%",      -- hiển thị giá trị + hậu tố
    CurrentValue = 50,
    Callback = function(val)
        -- phản hồi khi thay đổi
    end,
}, "SLD_INTENSITY")

-- 9) ELEMENTS — Input (Dynamic Input)
local Inp = GB_Left:CreateInput({
    Name = "Tag",
    Icon = NebulaIcons and NebulaIcons:GetIcon('text-cursor-input', 'Lucide') or nil,
    CurrentValue = "",
    PlaceholderText = "Enter tag...",
    MaxCharacters = 24,
    Enter = true, -- chỉ callback khi nhấn Enter
    Callback = function(text)
        Starlight:Notification({
            Title = "Input",
            Content = "Tag set to: "..text
        }, "TAG_NOTE")
    end,
}, "INP_TAG")

-- 10) TEXTS — Label & Paragraph
local Lbl = GB_Right:CreateLabel({ Name = "Status: Ready" }, "LBL_STATUS")

local Para = GB_Right:CreateParagraph({
    Name    = "Notes",
    Content = [[
This is a paragraph that auto-sizes to fit content.
Use it for helpers, multi-line docs or tips.
]]
}, "PARA_NOTES")

-- 11) Divider
local _div = GB_Right:CreateDivider()

-- 12) Config Groupbox (Extras → Configurations)
-- Tạo groupbox quản lý config theo hệ flag/index của Starlight.
MainTab:BuildConfigGroupbox(2) -- cột 2; có thể truyền style (số 2) & boolean center buttons

-- 13) Tự động load config được user chọn (Extras → Configurations)
Starlight:LoadAutoloadConfig()

-- 14) OnDestroy (Extras → Finishing Your Script)
Starlight:OnDestroy(function()
    -- revert lại những thay đổi gameplay/visual bạn đã bật khi GUI đóng.
    -- ví dụ: tắt loop, xoá connections, reset biến, v.v.
end)

-- Mẹo theo Elements/Returns:
-- Mọi element/window/tab/groupbox đều có .Instance (GuiObject) và :Set({ ... }, "NEW_INDEX") để thay đổi nhanh.
-- Ví dụ đổi nhãn trạng thái sau 2s:
task.delay(2, function()
    if Lbl and Lbl.Set then
        Lbl:Set({ Name = "Status: Running" })
    end
end)
