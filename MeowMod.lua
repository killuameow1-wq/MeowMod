-- // MEOWMOD | V44.0 FINAL // Monolithic build
-- Load via loadstring(raw.github...)() or paste into Delta directly.
-- ESP, AI v10, aim v4, bypass v10, teleport v5, UI v4, logs v4.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local WS = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local CollSvc = game:GetService("CollectionService")
local Http = game:GetService("HttpService")

local LP = Players.LocalPlayer
local Camera = WS.CurrentCamera
local PG = LP:WaitForChild("PlayerGui")

-- ═══════════════ CONFIG ═══════════════
local CONFIG_PATH = "MeowMod_V44.json"
local function HasFS() return typeof(writefile) == "function" and typeof(readfile) == "function" end

local DefaultConfig = {
    Aimbot = false, SilentAim = false,
    AimKey = Enum.UserInputType.MouseButton2,
    FOV = 260, MaxDistance = 5000,
    StrictFOV = true,
    Smoothness = 0.22, PredictionMultiplier = 1.0,
    SmartTarget = false, TargetLock = false,
    Headshot = false, WallCheck = false,
    Bypass = false, ShowFOV = false, DynamicFOV = false,
    AdaptiveFOV = false, SnapClose = false,
    TeamFilter = "all",
    ESP = false, ESP_Line = false, ESP_Box = false,
    ESP_Name = false, ESP_Dist = false, ESP_HP = false,
    ESP_Skeleton = false, ESP_Offscreen = false, ESP_DistBar = false,
    V_ESP = false, V_ESP_Box = false, V_ESP_Name = false, V_ESP_Dist = false,
    V_ESP_MaxDist = 5000,
    HitboxExpander = false, HitboxSize = 6,
    Crosshair = false, CH_Size = 12,
    TP_PlayerOffset = 5, TP_SafeDrop = 4,
    TP_CaptureKeywords = {"capture","flag","zone","point","control","objective","flagzone","controlpoint","cap"},
    TP_CaptureBlacklist = {"airdroppad","airdropp","cargo","planecrate","plane","vehicle","seat","heli","air","cargo","table","chair","desk","bunker","gui","menu","decor","furniture","props","minimap","interior","spawnpoint"},
    ColorNeon = Color3.fromRGB(0, 240, 255),
    ColorBg = Color3.fromRGB(10, 10, 14),
    ColorPanel = Color3.fromRGB(18, 18, 24),
    ColorVehicle = Color3.fromRGB(255, 165, 0),
}
local Config = {}
for k, v in pairs(DefaultConfig) do
    if type(v) == "table" then
        local c = {}
        for i, vv in ipairs(v) do c[i] = vv end
        Config[k] = c
    else Config[k] = v end
end

local function SerializeConfig()
    local t = {}
    for k, v in pairs(Config) do
        if typeof(v) == "Color3" then t[k] = {"__c3", v.R, v.G, v.B}
        elseif type(v) == "table" then
            local arr = {"__arr"}
            for i, vv in ipairs(v) do table.insert(arr, vv) end
            t[k] = arr
        elseif type(v) == "boolean" or type(v) == "number" or type(v) == "string" then t[k] = v end
    end
    return t
end
local function DeserializeConfig(t)
    for k, v in pairs(t) do
        if type(v) == "table" and v[1] == "__c3" then Config[k] = Color3.new(v[2], v[3], v[4])
        elseif type(v) == "table" and v[1] == "__arr" then
            local arr = {}
            for i = 2, #v do table.insert(arr, v[i]) end
            Config[k] = arr
        elseif type(v) == "boolean" or type(v) == "number" or type(v) == "string" then Config[k] = v end
    end
end
local function LoadConfig()
    if not HasFS() then return false end
    local ok, data = pcall(function()
        if not isfile(CONFIG_PATH) then return nil end
        return readfile(CONFIG_PATH)
    end)
    if not ok or not data or data == "" then return false end
    local ok2, parsed = pcall(function() return Http:JSONDecode(data) end)
    if ok2 and parsed then DeserializeConfig(parsed); return true end
    return false
end
local function SaveConfig()
    if not HasFS() then return false end
    return pcall(function() writefile(CONFIG_PATH, Http:JSONEncode(SerializeConfig())) end)
end
LoadConfig()

-- ═══════════════ LOGGER v4 ═══════════════
local ErrorLogs = {}
local LogBox = nil
local LogFilter = "all"
local LogCounters = {}
local LogChipLabels = {}
local MaxLogs = 500
local LOG_COLORS = {
    AIM = Color3.fromRGB(255,100,100), ESP = Color3.fromRGB(100,200,255),
    VEH = Color3.fromRGB(255,165,0), AI = Color3.fromRGB(180,120,255),
    TP = Color3.fromRGB(120,255,180), CONFIG = Color3.fromRGB(0,240,200),
    CORE = Color3.fromRGB(255,80,80), SYS = Color3.fromRGB(255,200,50),
    PERF = Color3.fromRGB(255,120,200),
}
local function LogColor(cat) return LOG_COLORS[cat] or Color3.fromRGB(200,200,200) end

local function LogError(msg, cat)
    cat = cat or "SYS"
    local line = "["..os.date("%H:%M:%S").."] ["..cat.."] "..tostring(msg)
    table.insert(ErrorLogs, {text = line, cat = cat, ts = tick()})
    while #ErrorLogs > MaxLogs do table.remove(ErrorLogs, 1) end
    LogCounters[cat] = (LogCounters[cat] or 0) + 1
    if LogChipLabels[cat] then LogChipLabels[cat].Text = cat..": "..LogCounters[cat] end
    if LogBox then
        pcall(function()
            if LogFilter ~= "all" and LogFilter ~= cat then return end
            local tl = Instance.new("TextLabel")
            tl.Size = UDim2.new(1,0,0,18); tl.BackgroundTransparency = 1
            tl.Text = line; tl.TextSize = 11
            tl.TextXAlignment = Enum.TextXAlignment.Left
            tl.Font = Enum.Font.Code
            tl.TextColor3 = LogColor(cat)
            tl.Parent = LogBox
            if LogBox.CanvasPosition.Y >= LogBox.AbsoluteCanvasSize.Y - 200 then
                task.defer(function()
                    pcall(function() LogBox.CanvasPosition = Vector2.new(0, LogBox.AbsoluteCanvasSize.Y) end)
                end)
            end
        end)
    end
end

local function RebuildLogs()
    if not LogBox then return end
    for _, v in pairs(LogBox:GetChildren()) do
        if v:IsA("TextLabel") then v:Destroy() end
    end
    for _, e in ipairs(ErrorLogs) do
        if LogFilter == "all" or LogFilter == e.cat then
            pcall(function()
                local tl = Instance.new("TextLabel")
                tl.Size = UDim2.new(1,0,0,18); tl.BackgroundTransparency = 1
                tl.Text = e.text; tl.TextSize = 11
                tl.TextXAlignment = Enum.TextXAlignment.Left
                tl.Font = Enum.Font.Code
                tl.TextColor3 = LogColor(e.cat)
                tl.Parent = LogBox
            end)
        end
    end
end

if PG:FindFirstChild("MeowMod") then PG.MeowMod:Destroy() end
if PG:FindFirstChild("MeowESP") then PG.MeowESP:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MeowMod"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.Parent = PG

local Connections, Drawings = {}, {}
local function AddConn(c) table.insert(Connections, c) end
local function AddDraw(d) table.insert(Drawings, d) end

-- ═══════════════ UI v4 ═══════════════
local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 720, 0, 560)
Main.Position = UDim2.new(0.5, -360, 0.5, -280)
Main.BackgroundColor3 = Config.ColorBg
Main.BackgroundTransparency = 0.02
Main.BorderSizePixel = 0
Main.Active = true; Main.Draggable = true
Main.Parent = ScreenGui
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 16)
local MS = Instance.new("UIStroke", Main)
MS.Color = Config.ColorNeon; MS.Thickness = 2; MS.Transparency = 0.2

local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 64)
Header.BackgroundColor3 = Color3.fromRGB(22, 22, 32)
Header.BackgroundTransparency = 0.05
Header.BorderSizePixel = 0
Header.ClipsDescendants = true
Header.Parent = Main
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 16)
local HGrad = Instance.new("UIGradient", Header)
HGrad.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(30,30,45)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(22,22,32)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(30,30,45))
}
HGrad.Rotation = 15

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -320, 1, 0)
TitleLabel.Position = UDim2.new(0, 20, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "MEOW | V44.0"
TitleLabel.TextColor3 = Config.ColorNeon
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Font = Enum.Font.GothamBlack
TitleLabel.TextSize = 19
TitleLabel.Parent = Header

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(0, 120, 0, 34)
StatusLabel.Position = UDim2.new(1, -250, 0, 15)
StatusLabel.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
StatusLabel.BackgroundTransparency = 0.4
StatusLabel.Text = "AI: READY"
StatusLabel.TextColor3 = Color3.fromRGB(120,120,120)
StatusLabel.Font = Enum.Font.GothamBold
StatusLabel.TextSize = 12
StatusLabel.Parent = Header
Instance.new("UICorner", StatusLabel).CornerRadius = UDim.new(0, 8)

local PerfLabel = Instance.new("TextLabel")
PerfLabel.Size = UDim2.new(0, 120, 0, 34)
PerfLabel.Position = UDim2.new(1, -380, 0, 15)
PerfLabel.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
PerfLabel.BackgroundTransparency = 0.4
PerfLabel.Text = "FPS: --"
PerfLabel.TextColor3 = Color3.fromRGB(180,180,180)
PerfLabel.Font = Enum.Font.GothamBold
PerfLabel.TextSize = 12
PerfLabel.Parent = Header
Instance.new("UICorner", PerfLabel).CornerRadius = UDim.new(0, 8)

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 34, 0, 34)
CloseBtn.Position = UDim2.new(1, -44, 0, 15)
CloseBtn.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
CloseBtn.Text = "×"; CloseBtn.TextColor3 = Color3.fromRGB(255,255,255)
CloseBtn.Font = Enum.Font.GothamBold; CloseBtn.TextSize = 18
CloseBtn.Parent = Header
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 8)

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 34, 0, 34)
MinBtn.Position = UDim2.new(1, -86, 0, 15)
MinBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
MinBtn.Text = "-"; MinBtn.TextColor3 = Color3.fromRGB(255,255,255)
MinBtn.Font = Enum.Font.GothamBold; MinBtn.TextSize = 18
MinBtn.Parent = Header
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 8)

local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(1, -40, 0, 40)
TabBar.Position = UDim2.new(0, 20, 0, 74)
TabBar.BackgroundTransparency = 1
TabBar.Parent = Main
local TL = Instance.new("UIListLayout", TabBar)
TL.FillDirection = Enum.FillDirection.Horizontal
TL.Padding = UDim.new(0, 8)
TL.SortOrder = Enum.SortOrder.LayoutOrder

local Pages = {}
local ActiveTabBtn = nil
local function CreateTab(name, order)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(0, 96, 1, 0)
    Btn.BackgroundColor3 = Color3.fromRGB(25,25,38)
    Btn.BackgroundTransparency = 0.15
    Btn.Text = name
    Btn.TextColor3 = Color3.fromRGB(160,160,170)
    Btn.Font = Enum.Font.GothamBold
    Btn.TextSize = 12
    Btn.LayoutOrder = order
    Btn.AutoButtonColor = false
    Btn.Parent = TabBar
    Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 8)
    local Ind = Instance.new("Frame")
    Ind.Size = UDim2.new(0.6, 0, 0, 3)
    Ind.Position = UDim2.new(0.2, 0, 1, -3)
    Ind.BackgroundColor3 = Config.ColorNeon
    Ind.Visible = false
    Ind.BorderSizePixel = 0
    Ind.Parent = Btn
    Instance.new("UICorner", Ind).CornerRadius = UDim.new(1, 0)

    local Page = Instance.new("ScrollingFrame")
    Page.Size = UDim2.new(0, 490, 1, -140)
    Page.Position = UDim2.new(0, 20, 0, 124)
    Page.BackgroundTransparency = 1
    Page.Visible = false
    Page.CanvasSize = UDim2.new(0, 0, 0, 0)
    Page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    Page.ScrollBarThickness = 3
    Page.ScrollBarImageColor3 = Config.ColorNeon
    Page.ScrollingDirection = Enum.ScrollingDirection.Y
    Page.Parent = Main
    local L = Instance.new("UIListLayout", Page)
    L.Padding = UDim.new(0, 8)
    L.SortOrder = Enum.SortOrder.LayoutOrder
    Pages[name] = Page

    Btn.MouseButton1Click:Connect(function()
        for _, p in pairs(Pages) do p.Visible = false end
        for _, b in pairs(TabBar:GetChildren()) do
            if b:IsA("TextButton") then
                b.BackgroundColor3 = Color3.fromRGB(25,25,38)
                b.BackgroundTransparency = 0.15
                b.TextColor3 = Color3.fromRGB(160,160,170)
                local ind = b:FindFirstChildOfClass("Frame")
                if ind then ind.Visible = false end
            end
        end
        Page.Visible = true
        Btn.BackgroundColor3 = Config.ColorNeon
        Btn.BackgroundTransparency = 0
        Btn.TextColor3 = Color3.fromRGB(0,0,0)
        Ind.Visible = true
        ActiveTabBtn = Btn
    end)
end

local function Save()
    if SaveConfig() then LogError("Config saved", "CONFIG")
    else LogError("Config save failed (no fs)", "CONFIG") end
end
local SaveDebounce = 0
local function QueueSave()
    SaveDebounce = SaveDebounce + 1
    local myId = SaveDebounce
    task.delay(0.5, function() if myId == SaveDebounce then Save() end end)
end

local function CreateToggle(parent, name, def, cb, cfgKey)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(1, 0, 0, 44)
    Btn.BackgroundColor3 = Config.ColorPanel
    Btn.BackgroundTransparency = 0.35
    Btn.Text = ""; Btn.AutoButtonColor = false
    Btn.Parent = parent
    Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 10)
    local st = Instance.new("UIStroke", Btn)
    st.Color = Color3.fromRGB(45,45,60); st.Thickness = 1; st.Transparency = 0.4
    local TLbl = Instance.new("TextLabel")
    TLbl.Size = UDim2.new(1, -80, 1, 0)
    TLbl.Position = UDim2.new(0, 16, 0, 0)
    TLbl.BackgroundTransparency = 1
    TLbl.Text = name
    TLbl.TextColor3 = Color3.fromRGB(225,225,230)
    TLbl.TextXAlignment = Enum.TextXAlignment.Left
    TLbl.Font = Enum.Font.GothamMedium
    TLbl.TextSize = 13
    TLbl.Parent = Btn
    local Ind = Instance.new("Frame")
    Ind.Size = UDim2.new(0, 40, 0, 22)
    Ind.Position = UDim2.new(1, -54, 0.5, -11)
    Ind.BackgroundColor3 = def and Config.ColorNeon or Color3.fromRGB(55,55,70)
    Ind.Parent = Btn
    Instance.new("UICorner", Ind).CornerRadius = UDim.new(1, 0)
    local Circ = Instance.new("Frame")
    Circ.Size = UDim2.new(0, 18, 0, 18)
    Circ.Position = def and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
    Circ.BackgroundColor3 = Color3.fromRGB(255,255,255)
    Circ.Parent = Ind
    Instance.new("UICorner", Circ).CornerRadius = UDim.new(1, 0)
    local State = def
    Btn.MouseEnter:Connect(function()
        TweenService:Create(Btn, TweenInfo.new(0.12), {BackgroundTransparency = 0.15}):Play()
        st.Transparency = 0.15
    end)
    Btn.MouseLeave:Connect(function()
        TweenService:Create(Btn, TweenInfo.new(0.12), {BackgroundTransparency = 0.35}):Play()
        st.Transparency = 0.4
    end)
    AddConn(Btn.MouseButton1Click:Connect(function()
        State = not State
        TweenService:Create(Ind, TweenInfo.new(0.15), {
            BackgroundColor3 = State and Config.ColorNeon or Color3.fromRGB(55,55,70)
        }):Play()
        TweenService:Create(Circ, TweenInfo.new(0.15), {
            Position = State and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
        }):Play()
        if cfgKey then Config[cfgKey] = State end
        if cb then cb(State) end
        QueueSave()
    end))
end

local function CreateSlider(parent, name, mn, mx, def, cb, cfgKey)
    local F = Instance.new("Frame")
    F.Size = UDim2.new(1, 0, 0, 54)
    F.BackgroundColor3 = Config.ColorPanel
    F.BackgroundTransparency = 0.35
    F.Parent = parent
    Instance.new("UICorner", F).CornerRadius = UDim.new(0, 10)
    local TLbl = Instance.new("TextLabel")
    TLbl.Size = UDim2.new(1, -30, 0, 22)
    TLbl.Position = UDim2.new(0, 16, 0, 6)
    TLbl.BackgroundTransparency = 1
    TLbl.Text = name..": "..tostring(def)
    TLbl.TextColor3 = Color3.fromRGB(225,225,230)
    TLbl.TextXAlignment = Enum.TextXAlignment.Left
    TLbl.Font = Enum.Font.GothamMedium
    TLbl.TextSize = 13
    TLbl.Parent = F
    local Bg = Instance.new("Frame")
    Bg.Size = UDim2.new(1, -30, 0, 6)
    Bg.Position = UDim2.new(0, 16, 0, 36)
    Bg.BackgroundColor3 = Color3.fromRGB(40,40,50)
    Bg.Parent = F
    Instance.new("UICorner", Bg).CornerRadius = UDim.new(1, 0)
    local Fill = Instance.new("Frame")
    Fill.Size = UDim2.new((def-mn)/(mx-mn), 0, 1, 0)
    Fill.BackgroundColor3 = Config.ColorNeon
    Fill.Parent = Bg
    Instance.new("UICorner", Fill).CornerRadius = UDim.new(1, 0)
    local Hit = Instance.new("TextButton")
    Hit.Size = UDim2.new(1, 0, 4, 0)
    Hit.Position = UDim2.new(0, 0, -1.5, 0)
    Hit.BackgroundTransparency = 1
    Hit.Text = ""
    Hit.Parent = Bg
    local dragging = false
    local function Update(input)
        local pos = math.clamp((input.Position.X - Bg.AbsolutePosition.X)/Bg.AbsoluteSize.X, 0, 1)
        local v = math.floor(mn + (mx-mn)*pos)
        Fill.Size = UDim2.new(pos, 0, 1, 0)
        TLbl.Text = name..": "..tostring(v)
        if cfgKey then Config[cfgKey] = v end
        if cb then cb(v) end
    end
    AddConn(Hit.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = true; Update(inp)
        end
    end))
    AddConn(UIS.InputChanged:Connect(function(inp)
        if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
            Update(inp)
        end
    end))
    AddConn(UIS.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            if dragging then QueueSave() end
            dragging = false
        end
    end))
end

local function CreateButton(parent, name, cb)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(1, 0, 0, 44)
    Btn.BackgroundColor3 = Color3.fromRGB(30,30,45)
    Btn.Text = name; Btn.TextColor3 = Config.ColorNeon
    Btn.Font = Enum.Font.GothamBold; Btn.TextSize = 13
    Btn.AutoButtonColor = false
    Btn.Parent = parent
    Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 10)
    local st = Instance.new("UIStroke", Btn)
    st.Color = Config.ColorNeon; st.Thickness = 1; st.Transparency = 0.75
    Btn.MouseEnter:Connect(function()
        TweenService:Create(Btn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(40,40,60)}):Play()
        st.Transparency = 0.3
    end)
    Btn.MouseLeave:Connect(function()
        TweenService:Create(Btn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(30,30,45)}):Play()
        st.Transparency = 0.75
    end)
    Btn.MouseButton1Click:Connect(function()
        TweenService:Create(Btn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(0,255,150)}):Play()
        task.wait(0.2)
        TweenService:Create(Btn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(30,30,45)}):Play()
        if cb then cb() end
    end)
end

local function CreateCycle(parent, name, options, default, cb, cfgKey)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(1, 0, 0, 44)
    Btn.BackgroundColor3 = Color3.fromRGB(30,30,45)
    Btn.Text = name..": "..default
    Btn.TextColor3 = Config.ColorNeon
    Btn.Font = Enum.Font.GothamBold; Btn.TextSize = 13
    Btn.AutoButtonColor = false
    Btn.Parent = parent
    Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 10)
    local st = Instance.new("UIStroke", Btn)
    st.Color = Config.ColorNeon; st.Thickness = 1; st.Transparency = 0.75
    local idx = 1
    for i, o in ipairs(options) do if o == default then idx = i break end end
    Btn.MouseEnter:Connect(function()
        TweenService:Create(Btn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(40,40,60)}):Play()
        st.Transparency = 0.3
    end)
    Btn.MouseLeave:Connect(function()
        TweenService:Create(Btn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(30,30,45)}):Play()
        st.Transparency = 0.75
    end)
    Btn.MouseButton1Click:Connect(function()
        idx = idx + 1; if idx > #options then idx = 1 end
        Btn.Text = name..": "..options[idx]
        if cfgKey then Config[cfgKey] = options[idx] end
        if cb then cb(options[idx]) end
        QueueSave()
    end)
end

-- Target HUD
local TargetHUD = Instance.new("Frame")
TargetHUD.Size = UDim2.new(0, 210, 0, 110)
TargetHUD.Position = UDim2.new(1, -230, 0, 124)
TargetHUD.BackgroundColor3 = Config.ColorPanel
TargetHUD.BackgroundTransparency = 0.3
TargetHUD.BorderSizePixel = 0
TargetHUD.Parent = Main
Instance.new("UICorner", TargetHUD).CornerRadius = UDim.new(0, 10)
local THUD_Stroke = Instance.new("UIStroke", TargetHUD)
THUD_Stroke.Color = Config.ColorNeon; THUD_Stroke.Thickness = 1; THUD_Stroke.Transparency = 0.5

local THUD_Title = Instance.new("TextLabel")
THUD_Title.Size = UDim2.new(1, -20, 0, 22)
THUD_Title.Position = UDim2.new(0, 10, 0, 10)
THUD_Title.BackgroundTransparency = 1
THUD_Title.Text = "TARGET: NONE"
THUD_Title.TextColor3 = Config.ColorNeon
THUD_Title.Font = Enum.Font.GothamBold
THUD_Title.TextSize = 12
THUD_Title.TextXAlignment = Enum.TextXAlignment.Left
THUD_Title.TextTruncate = Enum.TextTruncate.AtEnd
THUD_Title.Parent = TargetHUD

local THUD_HPBg = Instance.new("Frame")
THUD_HPBg.Size = UDim2.new(1, -20, 0, 9)
THUD_HPBg.Position = UDim2.new(0, 10, 0, 44)
THUD_HPBg.BackgroundColor3 = Color3.fromRGB(40,40,50)
THUD_HPBg.Parent = TargetHUD
Instance.new("UICorner", THUD_HPBg).CornerRadius = UDim.new(0, 4)
local THUD_HPFill = Instance.new("Frame")
THUD_HPFill.Size = UDim2.new(1, 0, 1, 0)
THUD_HPFill.BackgroundColor3 = Color3.fromRGB(0,255,140)
THUD_HPFill.Parent = THUD_HPBg
Instance.new("UICorner", THUD_HPFill).CornerRadius = UDim.new(0, 4)
local THUD_Dist = Instance.new("TextLabel")
THUD_Dist.Size = UDim2.new(1, -20, 0, 22)
THUD_Dist.Position = UDim2.new(0, 10, 0, 62)
THUD_Dist.BackgroundTransparency = 1
THUD_Dist.Text = "DIST: --"
THUD_Dist.TextColor3 = Color3.fromRGB(200,200,200)
THUD_Dist.Font = Enum.Font.GothamMedium
THUD_Dist.TextSize = 12
THUD_Dist.TextXAlignment = Enum.TextXAlignment.Left
THUD_Dist.Parent = TargetHUD

CreateTab("Combat", 1); CreateTab("Visuals", 2); CreateTab("Players", 3)
CreateTab("Vehicles", 4); CreateTab("Teleport", 5); CreateTab("Logs", 6)
task.spawn(function()
    task.wait(0.1)
    for _, b in pairs(TabBar:GetChildren()) do
        if b:IsA("TextButton") and b.Text == "Combat" then
            Pages["Combat"].Visible = true
            b.BackgroundColor3 = Config.ColorNeon
            b.BackgroundTransparency = 0
            b.TextColor3 = Color3.fromRGB(0,0,0)
            local ind = b:FindFirstChildOfClass("Frame")
            if ind then ind.Visible = true end
        end
    end
end)

-- ═══════════════ TELEPORT v5 ═══════════════
local function SafeTeleport(pos, label)
    local c = LP.Character
    local hrp = c and c:FindFirstChild("HumanoidRootPart")
    if not hrp then LogError("No HRP", "TP"); return false end
    hrp.CFrame = CFrame.new(pos + Vector3.new(0, Config.TP_SafeDrop or 4, 0))
    pcall(function()
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end)
    LogError("TP -> "..label, "TP")
    return true
end

-- v5: keyword по ИМЕНИ, blacklist по полному пути, whitelist по маркерам,
-- score учитывает размер/контекст/близость, топ-3 логируется.
local function FindCandidates(keyword, blacklist, whitelist)
    local kwLow = keyword:lower()
    local out = {}
    local myHrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    local myPos = myHrp and myHrp.Position or Vector3.zero

    for _, o in pairs(WS:GetDescendants()) do
        if o and (o:IsA("BasePart") or o:IsA("Model")) and o.Name:lower():find(kwLow) then
            local chain = {}
            local parent = o
            while parent and parent ~= WS do
                table.insert(chain, parent.Name:lower())
                parent = parent.Parent
            end
            local chainStr = table.concat(chain, "/")

            local isBlack = false
            for _, b in ipairs(blacklist or {}) do
                if chainStr:find(b:lower()) then isBlack = true break end
            end

            if not isBlack then
                local isWhite = true
                if whitelist and #whitelist > 0 then
                    isWhite = false
                    for _, w in ipairs(whitelist) do
                        if chainStr:find(w:lower()) then isWhite = true break end
                    end
                end
                if isWhite then
                    local p, size
                    if o:IsA("BasePart") then p = o.Position; size = o.Size.Magnitude
                    else
                        local pr = o.PrimaryPart or o:FindFirstChildWhichIsA("BasePart")
                        if pr then p = pr.Position; size = pr.Size.Magnitude end
                    end
                    if p then
                        local score = 1000
                        if o.Name:lower() == kwLow then score = score + 200 end
                        if chainStr:find("capturepoint") then score = score + 250 end
                        if chainStr:find("capture") and not chainStr:find("capturetable") then score = score + 150 end
                        if chainStr:find("objective") then score = score + 120 end
                        if chainStr:find("flag") then score = score + 100 end
                        if chainStr:find("zone") then score = score + 80 end
                        if chainStr:find("trigger") then score = score + 60 end
                        if chainStr:find("control") then score = score + 60 end
                        if chainStr:find("decor") then score = score - 300 end
                        if chainStr:find("furniture") then score = score - 400 end
                        if chainStr:find("props") then score = score - 200 end
                        if chainStr:find("table") then score = score - 500 end
                        if chainStr:find("chair") then score = score - 500 end
                        if chainStr:find("bunker") then score = score - 400 end
                        if chainStr:find("minimap") then score = score - 500 end
                        if chainStr:find("interior") then score = score - 200 end
                        if chainStr:find("spawn") then score = score - 200 end
                        local dist = (myPos - p).Magnitude
                        score = score - math.min(dist * 0.05, 200)
                        if size and size > 5 then score = score + 50 end
                        if size and size > 15 then score = score + 50 end
                        table.insert(out, {part = o, pos = p, score = score, name = chainStr, dist = dist})
                    end
                end
            end
        end
    end
    table.sort(out, function(a, b) return a.score > b.score end)
    return out
end

local function TeleportSmart(keyword, blacklist, whitelist)
    local candidates = FindCandidates(keyword, blacklist, whitelist)
    if #candidates == 0 then
        LogError("TP '"..keyword.."': no candidates", "TP")
        return false
    end
    local pick = candidates[1]
    local top3 = ""
    for i = 1, math.min(3, #candidates) do
        top3 = top3.." | "..candidates[i].name.." ("..math.floor(candidates[i].score)..")"
    end
    return SafeTeleport(pick.pos, keyword.." -> "..pick.name.." [top:"..top3.."]")
end

-- Fallback: raw find без whitelist (если whitelist всё отверг)
local function RawTeleportKeyword(keyword, blacklist)
    local kwLow = keyword:lower()
    local best, bestD = nil, math.huge
    local myHrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    local myPos = myHrp and myHrp.Position or Vector3.zero
    for _, o in pairs(WS:GetDescendants()) do
        if o and (o:IsA("BasePart") or o:IsA("Model")) then
            local n = o.Name:lower()
            if n:find(kwLow) then
                local chain = n
                local pr = o.Parent
                while pr and pr ~= WS do
                    chain = chain.."/"..pr.Name:lower()
                    pr = pr.Parent
                end
                local bad = false
                for _, b in ipairs(blacklist or {}) do
                    if chain:find(b:lower()) then bad = true break end
                end
                if not bad then
                    local p
                    if o:IsA("BasePart") then p = o.Position
                    else
                        local ppr = o.PrimaryPart or o:FindFirstChildWhichIsA("BasePart")
                        if ppr then p = ppr.Position end
                    end
                    if p then
                        local d = (myPos - p).Magnitude
                        if d < bestD then bestD = d; best = {pos = p, name = chain} end
                    end
                end
            end
        end
    end
    if best then
        return SafeTeleport(best.pos, keyword.." (raw) -> "..best.name)
    end
    LogError("TP '"..keyword.."' raw: not found", "TP")
    return false
end

-- Универсальный: сначала умный, если пусто — raw
local function TeleportWithFallback(keyword, blacklist, whitelist)
    local ok = TeleportSmart(keyword, blacklist, whitelist)
    if not ok then
        LogError("Smart TP failed for '"..keyword.."', trying raw...", "TP")
        ok = RawTeleportKeyword(keyword, blacklist)
    end
    return ok
end

-- ═══════════════ UI CONTROLS ═══════════════
CreateToggle(Pages["Combat"], "Aimbot (hold RMB)", Config.Aimbot, nil, "Aimbot")
CreateToggle(Pages["Combat"], "Silent Aim", Config.SilentAim, nil, "SilentAim")
CreateToggle(Pages["Combat"], "Strict FOV", Config.StrictFOV, nil, "StrictFOV")
CreateToggle(Pages["Combat"], "Dynamic FOV", Config.DynamicFOV, nil, "DynamicFOV")
CreateToggle(Pages["Combat"], "Adaptive FOV", Config.AdaptiveFOV, nil, "AdaptiveFOV")
CreateToggle(Pages["Combat"], "Snap Close", Config.SnapClose, nil, "SnapClose")
CreateToggle(Pages["Combat"], "Target Lock", Config.TargetLock, nil, "TargetLock")
CreateToggle(Pages["Combat"], "Headshot", Config.Headshot, nil, "Headshot")
CreateToggle(Pages["Combat"], "Wall Check", Config.WallCheck, nil, "WallCheck")
CreateToggle(Pages["Combat"], "Smart Target", Config.SmartTarget, nil, "SmartTarget")
CreateToggle(Pages["Combat"], "Bypass v10", Config.Bypass, nil, "Bypass")
CreateToggle(Pages["Combat"], "Show FOV", Config.ShowFOV, nil, "ShowFOV")
CreateSlider(Pages["Combat"], "FOV", 50, 800, Config.FOV, nil, "FOV")
CreateSlider(Pages["Combat"], "Max Dist", 500, 5000, Config.MaxDistance, nil, "MaxDistance")
CreateSlider(Pages["Combat"], "Smooth x100", 5, 50, math.floor(Config.Smoothness*100), function(v) Config.Smoothness = v/100 end)
CreateSlider(Pages["Combat"], "Prediction x10", 5, 30, math.floor(Config.PredictionMultiplier*10), function(v) Config.PredictionMultiplier = v/10 end)

CreateToggle(Pages["Visuals"], "ESP", Config.ESP, nil, "ESP")
CreateToggle(Pages["Visuals"], " - Line", Config.ESP_Line, nil, "ESP_Line")
CreateToggle(Pages["Visuals"], " - Box", Config.ESP_Box, nil, "ESP_Box")
CreateToggle(Pages["Visuals"], " - Name", Config.ESP_Name, nil, "ESP_Name")
CreateToggle(Pages["Visuals"], " - Dist", Config.ESP_Dist, nil, "ESP_Dist")
CreateToggle(Pages["Visuals"], " - HP", Config.ESP_HP, nil, "ESP_HP")
CreateToggle(Pages["Visuals"], " - Skeleton", Config.ESP_Skeleton, nil, "ESP_Skeleton")
CreateToggle(Pages["Visuals"], " - Offscreen", Config.ESP_Offscreen, nil, "ESP_Offscreen")
CreateToggle(Pages["Visuals"], " - Dist Bar", Config.ESP_DistBar, nil, "ESP_DistBar")
CreateCycle(Pages["Visuals"], "Team Filter", {"all", "enemy", "my"}, Config.TeamFilter, nil, "TeamFilter")
CreateToggle(Pages["Visuals"], "Hitbox Expander", Config.HitboxExpander, function(v)
    Config.HitboxExpander = v
    if not v then
        for _, p in pairs(Players:GetPlayers()) do
            local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.Size = Vector3.new(2,2,1); hrp.Transparency = 1; hrp.CanCollide = true
            end
        end
    end
end, "HitboxExpander")
CreateSlider(Pages["Visuals"], "Hitbox Size", 2, 20, Config.HitboxSize, nil, "HitboxSize")
CreateToggle(Pages["Visuals"], "Crosshair", Config.Crosshair, nil, "Crosshair")
CreateSlider(Pages["Visuals"], "CH Size", 5, 30, Config.CH_Size, nil, "CH_Size")

CreateToggle(Pages["Vehicles"], "Vehicle ESP", Config.V_ESP, nil, "V_ESP")
CreateToggle(Pages["Vehicles"], " - Box", Config.V_ESP_Box, nil, "V_ESP_Box")
CreateToggle(Pages["Vehicles"], " - Name", Config.V_ESP_Name, nil, "V_ESP_Name")
CreateToggle(Pages["Vehicles"], " - Dist", Config.V_ESP_Dist, nil, "V_ESP_Dist")
CreateSlider(Pages["Vehicles"], "Veh Max Dist", 100, 10000, Config.V_ESP_MaxDist, nil, "V_ESP_MaxDist")

CreateButton(Pages["Teleport"], "TP Base", function()
    TeleportWithFallback("Base",
        {"Airdrop","Cargo","Spawn","Plane","Vehicle","Seat","Heli","Air","Bunker","Table","Chair"},
        {"base","spawn","hq","barracks"})
end)
CreateButton(Pages["Teleport"], "TP Airdrop", function()
    TeleportWithFallback("Airdrop",
        {"Base","Cargo","Plane","Vehicle","Table","Chair","Bunker"},
        {"airdrop","drop","crate","parachute"})
end)
CreateButton(Pages["Teleport"], "TP Capture Point", function()
    -- v5: whitelist заменён на явный набор маркеров, fallback на raw
    TeleportWithFallback("Capture",
        {"airdroppad","airdropp","cargo","plane","vehicle","seat","heli","air",
         "table","chair","desk","bunker","gui","menu","decor","furniture","props",
         "minimap","interior","spawnpoint","airdrop"},
        {"capture","flag","zone","point","trigger","objective","control","cap"})
end)
CreateButton(Pages["Teleport"], "TP Nearest Enemy", function()
    local myHrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not myHrp then return end
    local best, bestD = nil, math.huge
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            if hrp and hum and hum.Health > 0 then
                local isEnemy = LP.Team and p.Team and p.Team ~= LP.Team
                if isEnemy or not LP.Team then
                    local d = (myHrp.Position - hrp.Position).Magnitude
                    if d < bestD then bestD = d; best = hrp end
                end
            end
        end
    end
    if best then SafeTeleport(best.Position + Vector3.new(0, 3, 0), "nearest enemy @ "..math.floor(bestD).."m")
    else LogError("No enemy", "TP") end
end)
CreateButton(Pages["Teleport"], "TP Scan Capture (debug)", function()
    local cands = FindCandidates("Capture",
        {"airdroppad","cargo","plane","vehicle","seat","heli","air","table","chair","desk","bunker"},
        {"capture","flag","zone","point","trigger","objective","control","cap"})
    LogError("Scan Capture: "..#cands.." candidates found", "TP")
    for i = 1, math.min(10, #cands) do
        LogError("  "..i..". "..cands[i].name.." (score "..math.floor(cands[i].score)..", dist "..math.floor(cands[i].dist).."m)", "TP")
    end
end)

-- ═══════════════ UTIL ═══════════════
local function DistToColor(d)
    local t = math.clamp(d/400, 0, 1)
    if d <= 100 then
        local k = d/100
        return Color3.fromRGB(math.floor(255-k*55), math.floor(60+k*120), 60)
    end
    return Color3.fromRGB(math.floor(200*(1-t)), math.floor(180+75*t), math.floor(60+80*t))
end
local function PassesTeamFilter(p)
    if Config.TeamFilter == "all" then return true end
    local myTeam = LP.Team
    if not myTeam then return true end
    if Config.TeamFilter == "my" then return p.Team == myTeam end
    if Config.TeamFilter == "enemy" then return p.Team ~= myTeam end
    return true
end

-- ═══════════════ LOCK TARGET ═══════════════
local ForcedTarget = nil
local function SetForcedTarget(p)
    if ForcedTarget == p then ForcedTarget = nil; LogError("Lock released", "AI")
    else ForcedTarget = p; LogError("Locked -> "..tostring(p and p.Name or "nil"), "AI") end
end

-- ═══════════════ PLAYER LIST v2 ═══════════════
local PL = Instance.new("UIListLayout", Pages["Players"])
PL.Padding = UDim.new(0, 6)
local function UpdatePlayerList()
    local myHrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    local seen = {}
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LP and p.Character and PassesTeamFilter(p) then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            if hrp and hum and hum.Health > 0 then
                seen[p] = true
                local d = myHrp and math.floor((myHrp.Position - hrp.Position).Magnitude) or 0
                local Row = Pages["Players"]:FindFirstChild(tostring(p.UserId))
                local isNew = false
                if not Row or not Row:IsA("Frame") then
                    Row = Instance.new("Frame")
                    Row.Name = tostring(p.UserId)
                    Row:SetAttribute("isPlayer", true)
                    Row.Size = UDim2.new(1, 0, 0, 36)
                    Row.Parent = Pages["Players"]
                    Instance.new("UICorner", Row).CornerRadius = UDim.new(0, 8)
                    isNew = true
                end
                Row.BackgroundColor3 = (ForcedTarget == p) and Color3.fromRGB(60,40,90) or Config.ColorPanel
                Row.BackgroundTransparency = 0.3
                if isNew then
                    local NameBtn = Instance.new("TextButton")
                    NameBtn.Name = "NameBtn"
                    NameBtn.Size = UDim2.new(1, -70, 1, 0)
                    NameBtn.BackgroundTransparency = 1
                    NameBtn.TextXAlignment = Enum.TextXAlignment.Left
                    NameBtn.Font = Enum.Font.GothamMedium
                    NameBtn.TextSize = 13
                    NameBtn.Parent = Row
                    NameBtn.MouseButton1Click:Connect(function()
                        local ch = p.Character
                        local hrp2 = ch and ch:FindFirstChild("HumanoidRootPart")
                        if hrp2 then
                            SafeTeleport(hrp2.Position + Vector3.new(Config.TP_PlayerOffset, 3, Config.TP_PlayerOffset),
                                "player "..p.Name)
                        end
                    end)
                    local LockBtn = Instance.new("TextButton")
                    LockBtn.Name = "LockBtn"
                    LockBtn.Size = UDim2.new(0, 60, 1, 0)
                    LockBtn.Position = UDim2.new(1, -64, 0, 0)
                    LockBtn.TextColor3 = Color3.fromRGB(255,255,255)
                    LockBtn.Font = Enum.Font.GothamBold
                    LockBtn.TextSize = 11
                    LockBtn.AutoButtonColor = false
                    LockBtn.Parent = Row
                    Instance.new("UICorner", LockBtn).CornerRadius = UDim.new(0, 6)
                    LockBtn.MouseButton1Click:Connect(function()
                        SetForcedTarget(p); UpdatePlayerList()
                    end)
                end
                local NameBtn = Row:FindFirstChild("NameBtn")
                local LockBtn = Row:FindFirstChild("LockBtn")
                if NameBtn then
                    NameBtn.Text = "  "..p.Name.."  ["..d.."m]"
                    NameBtn.TextColor3 = DistToColor(d)
                end
                if LockBtn then
                    LockBtn.BackgroundColor3 = (ForcedTarget == p) and Color3.fromRGB(180,80,255) or Color3.fromRGB(40,40,55)
                    LockBtn.Text = (ForcedTarget == p) and "UNLOCK" or "LOCK"
                end
            end
        end
    end
    -- Удаляем строки для игроков которых больше нет
    for _, Row in pairs(Pages["Players"]:GetChildren()) do
        if Row:IsA("Frame") and Row:GetAttribute("isPlayer") then
            local uid = tonumber(Row.Name)
            local found = false
            for p, _ in pairs(seen) do
                if p.UserId == uid then found = true break end
            end
            if not found then Row:Destroy() end
        end
    end
end
task.spawn(function() while task.wait(1.5) do pcall(UpdatePlayerList) end end)

-- ═══════════════ VEHICLES ═══════════════
local VehicleSeats = {}
local function GetVehicleModel(seat)
    return seat:FindFirstAncestorOfClass("Model") or seat:FindFirstAncestorOfClass("Folder")
end
local function ModelAnchor(model)
    if model.PrimaryPart then return model.PrimaryPart end
    return model:FindFirstChildWhichIsA("BasePart", true)
end
local function RegisterSeat(seat)
    if VehicleSeats[seat] then return end
    local model = GetVehicleModel(seat)
    if model then VehicleSeats[seat] = model end
end
local function UnregisterSeat(seat) VehicleSeats[seat] = nil end
local function ScanAllVehicles()
    pcall(function()
        for _, inst in ipairs(CollSvc:GetTagged("VehicleSeat")) do
            if inst:IsA("VehicleSeat") then RegisterSeat(inst) end
        end
    end)
    for _, inst in ipairs(WS:GetDescendants()) do
        if inst:IsA("VehicleSeat") then RegisterSeat(inst) end
    end
end
ScanAllVehicles()
AddConn(WS.DescendantAdded:Connect(function(inst)
    if inst:IsA("VehicleSeat") then RegisterSeat(inst) end
end))
AddConn(WS.DescendantRemoving:Connect(function(inst)
    if inst:IsA("VehicleSeat") then UnregisterSeat(inst) end
end))
task.spawn(function() while task.wait(5) do if Config.V_ESP then pcall(ScanAllVehicles) end end end)

local function CollectUniqueModels()
    local seen, list = {}, {}
    for _, model in pairs(VehicleSeats) do
        if model and model.Parent and not seen[model] then
            seen[model] = true
            table.insert(list, model)
        end
    end
    return list
end

local VL = Instance.new("UIListLayout", Pages["Vehicles"])
VL.Padding = UDim.new(0, 6)
local function UpdateVehicleList()
    local myHrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not myHrp then return end
    local seen = {}
    local models = CollectUniqueModels()
    table.sort(models, function(a, b)
        local pa = ModelAnchor(a); local pb = ModelAnchor(b)
        if not pa or not pb then return false end
        return (myHrp.Position - pa.Position).Magnitude < (myHrp.Position - pb.Position).Magnitude
    end)
    for _, model in ipairs(models) do
        local anchor = ModelAnchor(model)
        if anchor then
            seen[model] = true
            local d = math.floor((myHrp.Position - anchor.Position).Magnitude)
            local Row = Pages["Vehicles"]:FindFirstChild(model:GetDebugId() or model.Name)
            local uid = tostring(model)
            local Btn = Pages["Vehicles"]:FindFirstChild("veh_"..uid)
            if not Btn then
                Btn = Instance.new("TextButton")
                Btn.Name = "veh_"..uid
                Btn:SetAttribute("isVeh", true)
                Btn.Size = UDim2.new(1, 0, 0, 36)
                Btn.BackgroundColor3 = Config.ColorPanel
                Btn.BackgroundTransparency = 0.3
                Btn.TextXAlignment = Enum.TextXAlignment.Left
                Btn.Font = Enum.Font.GothamMedium
                Btn.TextSize = 13
                Btn.Parent = Pages["Vehicles"]
                Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 8)
                Btn.MouseButton1Click:Connect(function()
                    local anc = ModelAnchor(model)
                    if anc and anc.Parent then
                        SafeTeleport(anc.Position + Vector3.new(0, 6, 0), "vehicle "..model.Name)
                    end
                end)
            end
            Btn.Text = "  "..model.Name.."  ["..d.."m]"
            Btn.TextColor3 = DistToColor(d)
        end
    end
    for _, v in pairs(Pages["Vehicles"]:GetChildren()) do
        if v:IsA("TextButton") and v:GetAttribute("isVeh") then
            local found = false
            for model, _ in pairs(seen) do
                if v.Name == "veh_"..tostring(model) then found = true break end
            end
            if not found then v:Destroy() end
        end
    end
end
task.spawn(function() while task.wait(2.5) do pcall(UpdateVehicleList) end end)

-- ═══════════════ LOGS CHIPS ═══════════════
local ChipsBar = Instance.new("Frame")
ChipsBar.Size = UDim2.new(1, 0, 0, 32)
ChipsBar.BackgroundTransparency = 1
ChipsBar.Parent = Pages["Logs"]
local ChipsLayout = Instance.new("UIListLayout", ChipsBar)
ChipsLayout.FillDirection = Enum.FillDirection.Horizontal
ChipsLayout.Padding = UDim.new(0, 4)
ChipsLayout.SortOrder = Enum.SortOrder.LayoutOrder

local function MakeChip(cat, order)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(0, 66, 1, 0)
    Btn.BackgroundColor3 = Color3.fromRGB(30,30,45)
    Btn.Text = cat..": 0"
    Btn.TextColor3 = LogColor(cat)
    Btn.Font = Enum.Font.GothamBold; Btn.TextSize = 11
    Btn.AutoButtonColor = false
    Btn.LayoutOrder = order
    Btn.Parent = ChipsBar
    Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 6)
    LogChipLabels[cat] = Btn
    Btn.MouseButton1Click:Connect(function()
        LogFilter = (LogFilter == cat) and "all" or cat
        RebuildLogs()
        for _, c in pairs(LogChipLabels) do c.BackgroundColor3 = Color3.fromRGB(30,30,45) end
        if LogFilter ~= "all" and LogChipLabels[LogFilter] then
            LogChipLabels[LogFilter].BackgroundColor3 = Color3.fromRGB(0,100,120)
        end
    end)
end
MakeChip("AIM", 1); MakeChip("ESP", 2); MakeChip("AI", 3)
MakeChip("TP", 4); MakeChip("CONFIG", 5); MakeChip("SYS", 6)

LogBox = Instance.new("ScrollingFrame")
LogBox.Size = UDim2.new(1, 0, 1, -80)
LogBox.Position = UDim2.new(0, 0, 0, 38)
LogBox.BackgroundTransparency = 1
LogBox.CanvasSize = UDim2.new(0, 0, 0, 0)
LogBox.AutomaticCanvasSize = Enum.AutomaticSize.Y
LogBox.ScrollBarThickness = 2
LogBox.ScrollBarImageColor3 = Config.ColorNeon
LogBox.Parent = Pages["Logs"]
Instance.new("UIListLayout", LogBox).Padding = UDim.new(0, 4)

local CopyBtn = Instance.new("TextButton")
CopyBtn.Size = UDim2.new(1, 0, 0, 35)
CopyBtn.Position = UDim2.new(0, 0, 1, -35)
CopyBtn.BackgroundColor3 = Color3.fromRGB(0,200,100)
CopyBtn.Text = "Copy Logs"; CopyBtn.TextColor3 = Color3.fromRGB(255,255,255)
CopyBtn.Font = Enum.Font.GothamBold; CopyBtn.TextSize = 13
CopyBtn.Parent = Pages["Logs"]
Instance.new("UICorner", CopyBtn).CornerRadius = UDim.new(0, 8)
CopyBtn.MouseButton1Click:Connect(function()
    local parts = {}
    for _, e in ipairs(ErrorLogs) do
        if LogFilter == "all" or LogFilter == e.cat then
            table.insert(parts, e.text)
        end
    end
    if setclipboard then
        setclipboard(table.concat(parts, "\n"))
        CopyBtn.Text = "Copied!"
        task.wait(1); CopyBtn.Text = "Copy Logs"
    end
end)

-- ═══════════════ UNLOAD ═══════════════
local function Unload()
    for _, c in pairs(Connections) do
        if typeof(c) == "RBXScriptConnection" then c:Disconnect() end
    end
    for _, d in pairs(Drawings) do pcall(function() d:Remove() end) end
    for _, p in pairs(Players:GetPlayers()) do
        local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.Size = Vector3.new(2,2,1); hrp.Transparency = 1; hrp.CanCollide = true
        end
    end
    pcall(function()
        RunService:UnbindFromRenderStep("MeowESP")
        RunService:UnbindFromRenderStep("MeowLogic")
    end)
    ScreenGui:Destroy()
end
AddConn(CloseBtn.MouseButton1Click:Connect(Unload))

local min = false
AddConn(MinBtn.MouseButton1Click:Connect(function()
    min = not min
    Main.Size = min and UDim2.new(0,720,0,64) or UDim2.new(0,720,0,560)
    for _, v in pairs(Main:GetChildren()) do
        if v:IsA("ScrollingFrame") or v == TabBar or v == TargetHUD then
            v.Visible = not min
        end
    end
end))

-- ═══════════════ CROSSHAIR ═══════════════
local CH1 = Drawing.new("Line")
local CH2 = Drawing.new("Line")
CH1.Thickness = 2; CH2.Thickness = 2
CH1.Color = Config.ColorNeon; CH2.Color = Config.ColorNeon
AddDraw(CH1); AddDraw(CH2)

-- ═══════════════ ESP ═══════════════
local ESP = {}
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 1.5; FOVCircle.Transparency = 0.8
FOVCircle.Color = Config.ColorNeon; FOVCircle.Filled = false
AddDraw(FOVCircle)

local BONE_PAIRS = {
    {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"},
    {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"},
    {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"},
    {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"},
    {"RightLowerLeg", "RightFoot"},
}

local function ForceHide(d)
    if not d then return end
    if d.Line then d.Line.Visible = false end
    if d.Box then d.Box.Visible = false end
    if d.NameBg then d.NameBg.Visible = false end
    if d.Name then d.Name.Visible = false end
    if d.Dist then d.Dist.Visible = false end
    if d.HpBg then d.HpBg.Visible = false end
    if d.HpBar then d.HpBar.Visible = false end
    if d.OffArrow then d.OffArrow.Visible = false end
    if d.DistBarBg then d.DistBarBg.Visible = false end
    if d.DistBarFg then d.DistBarFg.Visible = false end
    if d.Bones then for _, b in pairs(d.Bones) do pcall(function() b.Visible = false end) end end
end

local ESP_FAILS = {}
local function CreateDraw(player)
    if ESP[player] then return ESP[player] end
    local ok, tbl = pcall(function()
        local t = {
            Line = Drawing.new("Line"), Box = Drawing.new("Square"),
            NameBg = Drawing.new("Square"), Name = Drawing.new("Text"),
            Dist = Drawing.new("Text"), HpBg = Drawing.new("Square"),
            HpBar = Drawing.new("Square"), OffArrow = Drawing.new("Triangle"),
            DistBarBg = Drawing.new("Square"), DistBarFg = Drawing.new("Square"),
            Bones = {},
        }
        for i = 1, #BONE_PAIRS do
            t.Bones[i] = Drawing.new("Line"); t.Bones[i].Thickness = 1
        end
        return t
    end)
    if not ok or not tbl then
        ESP_FAILS[player] = (ESP_FAILS[player] or 0) + 1
        if ESP_FAILS[player] == 1 then LogError("CreateDraw fail "..tostring(player), "ESP") end
        return nil
    end
    tbl.Line.Thickness = 1; tbl.Box.Thickness = 1
    tbl.NameBg.Filled = true; tbl.NameBg.Color = Color3.fromRGB(15,15,22); tbl.NameBg.Transparency = 0.7
    tbl.Name.Size = 13; tbl.Name.Center = true; tbl.Name.Outline = true
    tbl.Dist.Size = 12; tbl.Dist.Center = true; tbl.Dist.Outline = true
    tbl.HpBg.Filled = true; tbl.HpBg.Color = Color3.fromRGB(0,0,0)
    tbl.HpBar.Filled = true; tbl.OffArrow.Filled = true
    tbl.DistBarBg.Filled = true; tbl.DistBarFg.Filled = true
    for k, v in pairs(tbl) do if k ~= "Bones" then AddDraw(v) end end
    for _, b in pairs(tbl.Bones) do AddDraw(b) end
    ESP[player] = tbl
    return tbl
end
local function RemoveDraw(player)
    if ESP[player] then
        for k, v in pairs(ESP[player]) do
            if k == "Bones" then
                for _, b in pairs(v) do pcall(function() b:Remove() end) end
            else pcall(function() v:Remove() end) end
        end
        ESP[player] = nil
    end
end
AddConn(Players.PlayerRemoving:Connect(RemoveDraw))

local function OffscreenArrowPos(sp, margin)
    local vp = Camera.ViewportSize
    local cx, cy = vp.X/2, vp.Y/2
    local dx, dy = sp.X - cx, sp.Y - cy
    if math.abs(dx) < 0.001 and math.abs(dy) < 0.001 then dx = 1 end
    local tx = (cx - margin) / math.max(math.abs(dx), 0.0001)
    local ty = (cy - margin) / math.max(math.abs(dy), 0.0001)
    local t = math.min(tx, ty)
    return Vector2.new(cx + dx*t, cy + dy*t)
end

local function GetScreenBox(char, hrp)
    local ok, cf, size = pcall(function() return char:GetBoundingBox() end)
    if ok and cf and size then
        local tS, tOn = Camera:WorldToViewportPoint(cf.Position + Vector3.new(0, size.Y/2, 0))
        local bS, bOn = Camera:WorldToViewportPoint(cf.Position - Vector3.new(0, size.Y/2, 0))
        local lS, lOn = Camera:WorldToViewportPoint(cf.Position - Vector3.new(size.X/2, 0, 0))
        local rS, rOn = Camera:WorldToViewportPoint(cf.Position + Vector3.new(size.X/2, 0, 0))
        if tOn and bOn and lOn and rOn then
            local w = math.abs(rS.X - lS.X)
            local h = math.abs(bS.Y - tS.Y)
            if w > 0 and h > 0 and w < 800 and h < 800 then
                return {x = lS.X, y = tS.Y, w = w, h = h}
            end
        end
    end
    local head = char:FindFirstChild("Head")
    local lLeg = char:FindFirstChild("LeftFoot") or char:FindFirstChild("LeftLowerLeg")
    if head and lLeg then
        local hS, hOn = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
        local fS, fOn = Camera:WorldToViewportPoint(lLeg.Position - Vector3.new(0, 0.5, 0))
        if hOn and fOn then
            local h = math.abs(fS.Y - hS.Y)
            local lSh = char:FindFirstChild("LeftUpperArm")
            local rSh = char:FindFirstChild("RightUpperArm")
            local w
            if lSh and rSh then
                local lS2 = Camera:WorldToViewportPoint(lSh.Position)
                local rS2 = Camera:WorldToViewportPoint(rSh.Position)
                w = math.abs(rS2.X - lS2.X) * 1.6
            else w = h * 0.5 end
            if h > 0 and w > 0 then return {x = hS.X - w/2, y = hS.Y, w = w, h = h} end
        end
    end
    return nil
end

local RenderESP_Errored = false
local function RenderESP()
    if Config.Crosshair then
        local cx, cy = Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2
        local sz = Config.CH_Size
        CH1.From = Vector2.new(cx-sz, cy); CH1.To = Vector2.new(cx+sz, cy); CH1.Visible = true
        CH2.From = Vector2.new(cx, cy-sz); CH2.To = Vector2.new(cx, cy+sz); CH2.Visible = true
    else
        CH1.Visible = false; CH2.Visible = false
    end
    local currentFov = Config.FOV
    if Config.DynamicFOV and Config.Aimbot and UIS:IsMouseButtonPressed(Config.AimKey) then
        currentFov = Config.FOV * 0.7
    end
    FOVCircle.Visible = Config.ShowFOV
    if Config.ShowFOV then
        FOVCircle.Position = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
        FOVCircle.Radius = currentFov
    end

    local myChar = LP.Character
    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local myPos = myHrp and myHrp.Position
    local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
    local playerAlive = myHum and myHum.Health > 0
    local ForcedTarget = ForcedTarget
    local rendered = 0

    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LP then
            local ok, err = pcall(function()
                local d = ESP[p]
                if not Config.ESP or not playerAlive then
                    if d then ForceHide(d) end; return
                end
                local char = p.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local head = char and char:FindFirstChild("Head")
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if not (char and hrp and head and hum and hum.Health > 0 and PassesTeamFilter(p)) then
                    if d then ForceHide(d) end; return
                end
                local d3 = myPos and (myPos - hrp.Position).Magnitude or 0
                if d3 > Config.MaxDistance then
                    if d then ForceHide(d) end; return
                end
                local sp, onScreen = Camera:WorldToViewportPoint(hrp.Position)
                if not d then d = CreateDraw(p); if not d then return end end

                local isEnemy = LP.Team and p.Team and p.Team ~= LP.Team
                local color
                if LP.Team and p.Team then
                    color = isEnemy and Color3.fromRGB(255,80,80) or Color3.fromRGB(80,200,255)
                else color = DistToColor(d3) end
                if p == ForcedTarget then color = Color3.fromRGB(200,120,255) end

                if not onScreen and Config.ESP_Offscreen then
                    local arrPos = OffscreenArrowPos(sp, 40)
                    local dir = (Vector2.new(sp.X, sp.Y) - arrPos).Unit
                    local perp = Vector2.new(-dir.Y, dir.X)
                    d.OffArrow.PointA = arrPos + dir*14
                    d.OffArrow.PointB = arrPos - dir*8 + perp*10
                    d.OffArrow.PointC = arrPos - dir*8 - perp*10
                    d.OffArrow.Color = color
                    d.OffArrow.Visible = true
                    if d.Line then d.Line.Visible = false end
                    if d.Box then d.Box.Visible = false end
                    if d.Name then d.Name.Visible = false end
                    if d.NameBg then d.NameBg.Visible = false end
                    if d.Dist then d.Dist.Visible = false end
                    if d.HpBg then d.HpBg.Visible = false end
                    if d.HpBar then d.HpBar.Visible = false end
                    if d.DistBarBg then d.DistBarBg.Visible = false end
                    if d.DistBarFg then d.DistBarFg.Visible = false end
                    for _, b in pairs(d.Bones) do b.Visible = false end
                    return
                else d.OffArrow.Visible = false end

                if not onScreen then ForceHide(d); return end

                local box = GetScreenBox(char, hrp)
                local x, y, w, h
                if box then x, y, w, h = box.x, box.y, box.w, box.h
                else
                    h = math.clamp(8000 / math.max(d3, 1), 20, 500)
                    w = h / 2
                    x = sp.X - w/2
                    y = sp.Y - h/2
                end

                d.Box.Visible = Config.ESP_Box
                if d.Box.Visible then
                    d.Box.Size = Vector2.new(w, h)
                    d.Box.Position = Vector2.new(x, y)
                    d.Box.Color = color
                end
                d.Line.Visible = Config.ESP_Line
                if d.Line.Visible then
                    d.Line.From = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y)
                    d.Line.To = Vector2.new(sp.X, sp.Y)
                    d.Line.Color = color
                end
                d.Name.Visible = Config.ESP_Name
                d.NameBg.Visible = Config.ESP_Name
                if d.Name.Visible then
                    local prefix = ""
                    if LP.Team and p.Team then
                        prefix = isEnemy and "[E] " or "[A] "
                    end
                    d.Name.Text = (p == ForcedTarget and "🔒 " or "")..prefix..p.Name
                    d.Name.Position = Vector2.new(x + w/2, y-18)
                    d.Name.Color = color
                    local tw = #(prefix..p.Name)*7
                    d.NameBg.Size = Vector2.new(tw+12, 18)
                    d.NameBg.Position = Vector2.new(x + w/2 - (tw+12)/2, y-19)
                end
                d.Dist.Visible = Config.ESP_Dist
                if d.Dist.Visible then
                    d.Dist.Text = tostring(math.floor(d3)).."m"
                    d.Dist.Position = Vector2.new(x + w/2, y+h+2)
                    d.Dist.Color = color
                end
                d.HpBg.Visible = Config.ESP_HP
                d.HpBar.Visible = Config.ESP_HP
                if d.HpBar.Visible and hum.MaxHealth > 0 then
                    local hpP = math.clamp(hum.Health/hum.MaxHealth, 0, 1)
                    d.HpBg.Size = Vector2.new(3, h); d.HpBg.Position = Vector2.new(x-6, y)
                    d.HpBar.Size = Vector2.new(3, h*hpP); d.HpBar.Position = Vector2.new(x-6, y+h*(1-hpP))
                    d.HpBar.Color = Color3.fromRGB(255*(1-hpP), 255*hpP, 0)
                end
                for i, pair in ipairs(BONE_PAIRS) do
                    local a = char:FindFirstChild(pair[1])
                    local b = char:FindFirstChild(pair[2])
                    local bone = d.Bones[i]
                    if Config.ESP_Skeleton and a and b then
                        local pa, onA = Camera:WorldToViewportPoint(a.Position)
                        local pb, onB = Camera:WorldToViewportPoint(b.Position)
                        if onA and onB then
                            bone.From = Vector2.new(pa.X, pa.Y)
                            bone.To = Vector2.new(pb.X, pb.Y)
                            bone.Color = color
                            bone.Visible = true
                        else bone.Visible = false end
                    else bone.Visible = false end
                end
                if Config.ESP_DistBar then
                    local frac = math.clamp(1 - d3/Config.MaxDistance, 0, 1)
                    d.DistBarBg.Visible = true
                    d.DistBarBg.Size = Vector2.new(w, 3)
                    d.DistBarBg.Position = Vector2.new(x, y+h+18)
                    d.DistBarBg.Color = Color3.fromRGB(30,30,40)
                    d.DistBarFg.Visible = true
                    d.DistBarFg.Size = Vector2.new(w*frac, 3)
                    d.DistBarFg.Position = Vector2.new(x, y+h+18)
                    d.DistBarFg.Color = color
                else
                    d.DistBarBg.Visible = false
                    d.DistBarFg.Visible = false
                end
                rendered = rendered + 1
            end)
            if not ok and not RenderESP_Errored then
                LogError("ESP "..tostring(p)..": "..tostring(err), "ESP")
                RenderESP_Errored = true
            end
        end
    end
end

-- ═══════════════ VEHICLE ESP v2 ═══════════════
local VehicleESP = {}
local function CreateVehicleDraw(model)
    if VehicleESP[model] then return VehicleESP[model] end
    local ok, tbl = pcall(function()
        return {
            Box = Drawing.new("Square"), Name = Drawing.new("Text"), Dist = Drawing.new("Text"),
        }
    end)
    if not ok or not tbl then return nil end
    tbl.Box.Thickness = 1
    tbl.Name.Size = 13; tbl.Name.Center = true; tbl.Name.Outline = true
    tbl.Dist.Size = 12; tbl.Dist.Center = true; tbl.Dist.Outline = true
    for _, v in pairs(tbl) do AddDraw(v) end
    VehicleESP[model] = tbl
    return tbl
end

local function RenderVehicleESP()
    if not Config.V_ESP then
        for _, d in pairs(VehicleESP) do
            for _, v in pairs(d) do v.Visible = false end
        end
        return
    end
    local myHrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    local myPos = myHrp and myHrp.Position
    local alive = {}
    for _, model in ipairs(CollectUniqueModels()) do
        local ok, err = pcall(function()
            if not model.Parent then return end
            local anchor = ModelAnchor(model)
            if not anchor then return end
            alive[model] = true
            local d = CreateVehicleDraw(model)
            if not d then return end
            local pos = anchor.Position
            local d3 = myPos and (myPos - pos).Magnitude or 0
            if d3 > (Config.V_ESP_MaxDist or 5000) then
                for _, v in pairs(d) do v.Visible = false end; return
            end
            local sp, onScreen = Camera:WorldToViewportPoint(pos)
            if not onScreen then
                for _, v in pairs(d) do v.Visible = false end; return
            end
            local extOk, ext = pcall(function() return model:GetExtentsSize() end)
            local w, h
            if extOk and ext then
                local szSp = Camera:WorldToViewportPoint(pos + ext/2)
                w = math.clamp(math.abs(szSp.X - sp.X)*2, 22, 600)
                h = math.clamp(math.abs(szSp.Y - sp.Y)*2, 22, 600)
            else
                local s = math.clamp(8000/math.max(d3,1), 24, 300)
                w, h = s, s
            end
            d.Box.Visible = Config.V_ESP_Box
            if d.Box.Visible then
                d.Box.Size = Vector2.new(w, h)
                d.Box.Position = Vector2.new(sp.X - w/2, sp.Y - h/2)
                d.Box.Color = Config.ColorVehicle
            end
            d.Name.Visible = Config.V_ESP_Name
            if d.Name.Visible then
                d.Name.Text = model.Name
                d.Name.Position = Vector2.new(sp.X, sp.Y - h/2 - 18)
                d.Name.Color = Config.ColorVehicle
            end
            d.Dist.Visible = Config.V_ESP_Dist
            if d.Dist.Visible then
                d.Dist.Text = tostring(math.floor(d3)).."m"
                d.Dist.Position = Vector2.new(sp.X, sp.Y + h/2 + 2)
                d.Dist.Color = Config.ColorVehicle
            end
        end)
        if not ok then LogError("Veh "..tostring(model)..": "..tostring(err), "VEH") end
    end
    for model, d in pairs(VehicleESP) do
        if not alive[model] then
            for _, v in pairs(d) do pcall(function() v:Remove() end) end
            VehicleESP[model] = nil
        end
    end
end

-- ═══════════════ AI v10 ═══════════════
local ThreatHeat = {}
local AutoTarget = nil
local LastSwitch = 0
local LastValidLockAt = 0
local LastScan = 0
local SwitchCD = 0.3
local SwitchThreshold = 1.4
local ScanInterval = 0.08
local HeatDecayAge = 3.0
local SwitchHistory = {}
local ThrashMode = false
local LastAimReason = ""

local function IsVisible(head)
    local rp = RaycastParams.new()
    rp.FilterDescendantsInstances = {LP.Character, head.Parent}
    rp.FilterType = Enum.RaycastFilterType.Exclude
    return WS:Raycast(Camera.CFrame.Position, head.Position - Camera.CFrame.Position, rp) == nil
end

local function DecayHeat(now)
    for p, h in pairs(ThreatHeat) do
        local age = now - h.ts
        if age > HeatDecayAge then ThreatHeat[p] = nil
        else h.score = h.score * math.exp(-age * 0.7) end
    end
end

local function UpdateHeat(p, d3, attacking, hp, visible, isEnemy, centerDist)
    local h = ThreatHeat[p]
    if not h then h = {score = 0, ts = 0, attacking = false} ThreatHeat[p] = h end
    h.ts = tick()
    h.attacking = attacking
    local raw = 0
    raw = raw + math.max(0, 600 - d3) * 0.6
    if attacking then raw = raw + 400 end
    raw = raw + (1 - hp) * 200
    if visible then raw = raw + 100 end
    if isEnemy then raw = raw * 1.3 end
    if centerDist then raw = raw * math.clamp(1 + (Config.FOV - centerDist) / Config.FOV, 0.5, 1.5) end
    h.score = h.score * 0.65 + raw * 0.35
end

local function IsInFov(head, mPos, currentFov)
    local sp, on = Camera:WorldToViewportPoint(head.Position)
    if not on then return nil end
    local d2 = (Vector2.new(sp.X, sp.Y) - mPos).Magnitude
    if Config.StrictFOV then
        if d2 > currentFov then return nil end
    else
        if d2 > currentFov and (head.Position - Camera.CFrame.Position).Magnitude > 150 then return nil end
    end
    return {distPx = d2, sp = sp}
end

local function GetTarget()
    local ForcedTarget = ForcedTarget
    if ForcedTarget then
        local ch = ForcedTarget.Character
        local head = ch and ch:FindFirstChild("Head")
        local hum = ch and ch:FindFirstChildOfClass("Humanoid")
        local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
        if head and hum and hrp and hum.Health > 0 then
            local myHrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
            if myHrp and (myHrp.Position - head.Position).Magnitude <= Config.MaxDistance then
                return head
            end
        end
        ForcedTarget = nil
        LogError("Locked target lost", "AI")
    end

    local mPos = UIS:GetMouseLocation()
    local myChar = LP.Character
    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
    if not myHrp or not myHum or myHum.Health <= 0 then AutoTarget = nil; return nil end
    local myPos = myHrp.Position

    local fov = Config.FOV
    if Config.DynamicFOV and UIS:IsMouseButtonPressed(Config.AimKey) then fov = fov * 0.6 end
    local now = tick()

    local recent = 0
    local newHist = {}
    for _, t in ipairs(SwitchHistory) do
        if now - t < 0.5 then table.insert(newHist, t); recent = recent + 1 end
    end
    SwitchHistory = newHist
    ThrashMode = recent >= 3

    if Config.TargetLock and AutoTarget then
        local ch = AutoTarget.Parent
        local h = ch and ch:FindFirstChildOfClass("Humanoid")
        local r = ch and ch:FindFirstChild("HumanoidRootPart")
        local stillValid = false
        if h and r and h.Health > 0 then
            local fovCheck = IsInFov(AutoTarget, mPos, fov + 100)
            local d3 = (myPos - AutoTarget.Position).Magnitude
            if fovCheck and d3 <= Config.MaxDistance then stillValid = true; LastValidLockAt = now end
        end
        if stillValid then return AutoTarget end
        if now - LastValidLockAt > 0.2 then AutoTarget = nil end
    elseif not Config.TargetLock then AutoTarget = nil end

    if now - LastScan >= ScanInterval then
        LastScan = now
        DecayHeat(now)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LP and p.Character and PassesTeamFilter(p) then
                local head = p.Character:FindFirstChild("Head")
                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if head and hum and hrp and hum.Health > 0 then
                    local d3 = (myPos - head.Position).Magnitude
                    if d3 <= Config.MaxDistance then
                        local look = hrp.CFrame.LookVector
                        local toMe = (myPos - hrp.Position).Unit
                        local attacking = look:Dot(toMe) > 0.2
                        local hp = hum.MaxHealth > 0 and (hum.Health/hum.MaxHealth) or 1
                        local visible = (not Config.WallCheck) or IsVisible(head)
                        local isEnemy = LP.Team and p.Team and p.Team ~= LP.Team
                        local sp = Camera:WorldToViewportPoint(head.Position)
                        local centerDist = (Vector2.new(sp.X, sp.Y) - mPos).Magnitude
                        UpdateHeat(p, d3, attacking, hp, visible, isEnemy, centerDist)
                    end
                end
            end
        end
    end

    local best, bestScore = nil, -math.huge
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LP and p.Character and PassesTeamFilter(p) then
            local head = p.Character:FindFirstChild("Head")
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            if head and hum and hum.Health > 0 then
                local d3 = (myPos - head.Position).Magnitude
                if d3 <= Config.MaxDistance then
                    local fovCheck = IsInFov(head, mPos, fov)
                    if fovCheck then
                        local h = ThreatHeat[p]
                        local score = h and h.score or ((500 - d3) * 0.5)
                        if h and h.attacking and d3 < 80 then score = score + 600 end
                        if score > bestScore then bestScore = score; best = head end
                    end
                end
            end
        end
    end

    if Config.TargetLock and best and AutoTarget and best ~= AutoTarget then
        local effCD = ThrashMode and (SwitchCD * 2) or SwitchCD
        if now - LastSwitch < effCD then best = AutoTarget
        else
            local oldP = Players:GetPlayerFromCharacter(AutoTarget.Parent)
            local newP = Players:GetPlayerFromCharacter(best.Parent)
            local oldScore = (oldP and ThreatHeat[oldP] and ThreatHeat[oldP].score) or 0
            local newScore = (newP and ThreatHeat[newP] and ThreatHeat[newP].score) or 0
            local thr = ThrashMode and (SwitchThreshold * 1.5) or SwitchThreshold
            if oldScore * thr > newScore then best = AutoTarget
            else LastSwitch = now; table.insert(SwitchHistory, now) end
        end
    end
    if Config.TargetLock then AutoTarget = best end
    return best
end

-- ═══════════════ AIM v4 ═══════════════
local CamLocked = false
local function LockCamera()
    if not CamLocked then Camera.CameraType = Enum.CameraType.Scriptable; CamLocked = true end
end
local function UnlockCamera()
    if CamLocked then Camera.CameraType = Enum.CameraType.Custom; CamLocked = false end
end

local Jitter = Vector3.zero
local JitterTimer = 0
local SkipFrames = 0
local MicroPauseUntil = 0
local AimStartAt = 0
local LastAimTarget = nil
local LastShotAt = 0

local function AimUpdate(target, dt)
    if not target or not target.Parent then UnlockCamera(); LastAimTarget = nil; return false end
    local hum = target.Parent:FindFirstChildOfClass("Humanoid")
    local hrp = target.Parent:FindFirstChild("HumanoidRootPart")
    if not hum or hum.Health <= 0 or not hrp then UnlockCamera(); LastAimTarget = nil; return false end

    if target ~= LastAimTarget then AimStartAt = tick(); LastAimTarget = target end
    LockCamera()

    local aimPart = Config.Headshot and target or hrp
    local origin = Camera.CFrame.Position
    local vel = aimPart.AssemblyLinearVelocity
    local speed = vel.Magnitude
    local ping = LP:GetNetworkPing()
    local d3 = (origin - aimPart.Position).Magnitude
    local bulletSpeed = 500
    local t = ping + d3 / bulletSpeed

    local predicted
    if speed < 3 then predicted = aimPart.Position
    else predicted = aimPart.Position + vel * (t * Config.PredictionMultiplier) end
    predicted = predicted + Vector3.new(0, t * 4, 0)

    local now = tick()

    if Config.Bypass then
        if now - LastShotAt < 0.06 then return true end
        if now < MicroPauseUntil then return true end
        if SkipFrames > 0 then SkipFrames = SkipFrames - 1; return true end
        if speed > 8 and math.random() > 0.988 then SkipFrames = math.random(1, 2) end
        if d3 < 100 and math.random() > 0.996 then MicroPauseUntil = now + 0.05 end
        JitterTimer = JitterTimer + dt
        if JitterTimer >= 0.4 then
            JitterTimer = 0
            Jitter = Vector3.new(
                (math.random() - 0.5) * 0.007,
                (math.random() - 0.5) * 0.007,
                (math.random() - 0.5) * 0.003
            )
        end
    end

    local sp = Camera:WorldToViewportPoint(predicted)
    local mPos = UIS:GetMouseLocation()
    local offCenter = (Vector2.new(sp.X, sp.Y) - mPos).Magnitude

    if Config.SnapClose and (d3 < 60 or offCenter < Config.FOV * 0.25) then
        Camera.CFrame = CFrame.lookAt(origin, predicted + Jitter)
        return true
    end

    local since = now - AimStartAt
    local fadeIn = 1.0
    if since < 0.08 then fadeIn = 0.5 + (since / 0.08) * 0.5 end

    local alpha = Config.Smoothness
    if Config.AdaptiveFOV then alpha = alpha * math.clamp(1 + offCenter / 500, 0.7, 1.8) end
    alpha = math.clamp(alpha * (dt * 60) * fadeIn, 0.03, 0.85)
    Camera.CFrame = Camera.CFrame:Lerp(CFrame.lookAt(origin, predicted + Jitter), alpha)
    return true
end

-- ═══════════════ SILENT AIM ═══════════════
local isShooting = false
local silentTarget = nil
local silentActive = false
AddConn(UIS.InputBegan:Connect(function(inp, gp)
    if not gp and (inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch) then
        isShooting = true
        LastShotAt = tick()
    end
end))
AddConn(UIS.InputEnded:Connect(function(inp, gp)
    if not gp and (inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch) then isShooting = false end
end))

pcall(function()
    local mt = getrawmetatable(game)
    local oldNC = mt.__namecall
    setreadonly(mt, false)
    mt.__namecall = newcclosure(function(self, ...)
        if silentActive and silentTarget and silentTarget.Parent then
            local m = getnamecallmethod()
            if m == "Raycast" then
                local a = {...}
                if typeof(a[1]) == "Vector3" then a[2] = silentTarget.Position - a[1] end
                return oldNC(self, unpack(a))
            elseif m == "FindPartOnRay" or m == "FindPartOnRayWithIgnoreList" then
                local a = {...}
                if typeof(a[1]) == "Ray" then
                    a[1] = Ray.new(a[1].Origin, silentTarget.Position - a[1].Origin)
                end
                return oldNC(self, unpack(a))
            end
        end
        return oldNC(self, ...)
    end)
    setreadonly(mt, true)
end)

-- ═══════════════ FPS v2 ═══════════════
local Frames = 0
local LastFpsUpdate = tick()
local function UpdateFps()
    Frames = Frames + 1
    local now = tick()
    if now - LastFpsUpdate >= 1 then
        if PerfLabel then
            PerfLabel.Text = "FPS: "..Frames
            PerfLabel.TextColor3 = Frames >= 50 and Color3.fromRGB(120,255,140)
                or Frames >= 30 and Color3.fromRGB(255,200,80)
                or Color3.fromRGB(255,100,100)
        end
        Frames = 0; LastFpsUpdate = now
    end
end

-- ═══════════════ LOGIC TICK ═══════════════
local function TickLogic(dt)
    UpdateFps()

    if Config.SilentAim and isShooting then
        silentTarget = GetTarget(); silentActive = silentTarget ~= nil
    else silentTarget = nil; silentActive = false end

    if Config.HitboxExpander then
        for _, p in pairs(Players:GetPlayers()) do
            pcall(function()
                local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    hrp.Size = Vector3.new(Config.HitboxSize, Config.HitboxSize, Config.HitboxSize)
                    hrp.Transparency = 0.7; hrp.CanCollide = false; hrp.Massless = true
                end
            end)
        end
    end

    local myChar = LP.Character
    local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")

    if not myHum or myHum.Health <= 0 then
        UnlockCamera()
        for _, d in pairs(ESP) do ForceHide(d) end
        for _, d in pairs(VehicleESP) do for _, v in pairs(d) do v.Visible = false end end
        CH1.Visible = false; CH2.Visible = false; FOVCircle.Visible = false
        AutoTarget = nil
        if StatusLabel then StatusLabel.Text = "AI: DEAD"; StatusLabel.TextColor3 = Color3.fromRGB(255,0,0) end
        if THUD_Title then THUD_Title.Text = "TARGET: NONE" end
        return
    end

    if Config.Aimbot and UIS:IsMouseButtonPressed(Config.AimKey) then
        local target = GetTarget()
        if target then
            local isManual = ForcedTarget ~= nil
            if StatusLabel then
                StatusLabel.Text = isManual and "AI: MANUAL" or "AI: LOCKED"
                StatusLabel.TextColor3 = isManual and Color3.fromRGB(200,120,255) or Color3.fromRGB(255,80,80)
            end
            local tP = Players:GetPlayerFromCharacter(target.Parent)
            if tP then
                local hum = target.Parent:FindFirstChildOfClass("Humanoid")
                local hrp = target.Parent:FindFirstChild("HumanoidRootPart")
                if hum and hrp and THUD_Title then
                    THUD_Title.Text = (isManual and "🔒 " or "").."TARGET: "..tP.Name
                    local mx = hum.MaxHealth > 0 and hum.MaxHealth or 100
                    local hpP = math.clamp(hum.Health/mx, 0, 1)
                    THUD_HPFill:TweenSize(UDim2.new(hpP,0,1,0), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.1, true)
                    THUD_HPFill.BackgroundColor3 = Color3.fromRGB(255*(1-hpP), 255*hpP, 0)
                    local myHrp = myChar:FindFirstChild("HumanoidRootPart")
                    local d = myHrp and math.floor((myHrp.Position - hrp.Position).Magnitude) or 0
                    THUD_Dist.Text = "DIST: "..d.."m"
                end
            end
            AimUpdate(target, dt)
        else
            UnlockCamera()
            if StatusLabel then StatusLabel.Text = "AI: SCANNING"; StatusLabel.TextColor3 = Config.ColorNeon end
            if THUD_Title then THUD_Title.Text = "TARGET: NONE" end
        end
    else
        UnlockCamera(); AutoTarget = nil; LastAimTarget = nil
        if StatusLabel then StatusLabel.Text = "AI: STANDBY"; StatusLabel.TextColor3 = Color3.fromRGB(120,120,120) end
        if THUD_Title then THUD_Title.Text = "TARGET: NONE" end
    end
end

-- ═══════════════ RENDER BINDING ═══════════════
local function RenderTick()
    if Config.ESP or Config.ShowFOV or Config.Crosshair or Config.HitboxExpander then RenderESP() end
    if Config.V_ESP then RenderVehicleESP() end
end

pcall(function()
    RunService:BindToRenderStep("MeowESP", Enum.RenderPriority.Camera.Value - 1, RenderTick)
end)
pcall(function()
    RunService:BindToRenderStep("MeowLogic", Enum.RenderPriority.Camera.Value + 1, function(dt)
        pcall(TickLogic, dt)
    end)
end)

LogError("MeowMod V44.0 loaded", "SYS")
LogError("Готово. Все фичи выключены по дефолту.", "SYS")
