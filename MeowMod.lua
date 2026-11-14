-- // MEOWMOD | V3.1 // MOBILE UI REBUILD + FULL UNLOAD
-- Original logic untouched. Only UI + close/unload reworked.

if getgenv().MeowModUnload then pcall(getgenv().MeowModUnload) end
if getgenv()._MeowModGui then pcall(function() getgenv()._MeowModGui:Destroy() end) end
do
    local lp = game:GetService("Players").LocalPlayer
    local old = lp and lp:FindFirstChild("PlayerGui") and lp.PlayerGui:FindFirstChild("MeowMod")
    if old then old:Destroy() end
end

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")
local WS         = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local CollSvc    = game:GetService("CollectionService")
local Http       = game:GetService("HttpService")

local LP = Players.LocalPlayer
local Camera = WS.CurrentCamera
local PG = LP:WaitForChild("PlayerGui")

-- ═══════════════ CONFIG ═══════════════
local CONFIG_PATH = "MeowMod_V3.json"
local function HasFS() return typeof(writefile) == "function" and typeof(readfile) == "function" end

local DefaultConfig = {
    SilentAim = false, FOVPercent = 25, MaxDistance = 5000,
    StrictFOV = true, ShowFOV = true, PredictionMultiplier = 1.0,
    Headshot = false, WallCheck = false, TeamFilter = "all", Bypass = true,
    ESP = false, ESP_Line = false, ESP_Box = false, ESP_Name = false,
    ESP_Dist = false, ESP_HP = false, ESP_Skeleton = false,
    ESP_Offscreen = false, ESP_DistBar = false,
    V_ESP = false, V_ESP_Box = false, V_ESP_Name = false, V_ESP_Dist = false,
    V_ESP_MaxDist = 5000,
    HitboxExpander = false, HitboxSize = 6,
    Crosshair = false, CH_Size = 12,
    TP_PlayerOffset = 5, TP_SafeDrop = 4, TP_DropToGround = true,
    ColorNeon = Color3.fromRGB(0, 240, 255),
    ColorBg = Color3.fromRGB(10, 10, 14),
    ColorPanel = Color3.fromRGB(18, 18, 24),
    ColorVehicle = Color3.fromRGB(255, 165, 0),
    ColorSilent = Color3.fromRGB(180, 0, 255),
}
local Config = {}
for k, v in pairs(DefaultConfig) do Config[k] = v end

local function SerializeConfig()
    local t = {}
    for k, v in pairs(Config) do
        if typeof(v) == "Color3" then t[k] = {"__c3", v.R, v.G, v.B}
        elseif type(v) == "boolean" or type(v) == "number" or type(v) == "string" then t[k] = v end
    end
    return t
end
local function DeserializeConfig(t)
    for k, v in pairs(t) do
        if type(v) == "table" and v[1] == "__c3" then Config[k] = Color3.new(v[2], v[3], v[4])
        elseif type(v) == "boolean" or type(v) == "number" or type(v) == "string" then Config[k] = v end
    end
end
local function LoadConfig()
    if not HasFS() then return end
    local ok, data = pcall(function()
        if not isfile(CONFIG_PATH) then return nil end
        return readfile(CONFIG_PATH)
    end)
    if not ok or not data or data == "" then return end
    local ok2, parsed = pcall(function() return Http:JSONDecode(data) end)
    if ok2 and parsed then DeserializeConfig(parsed) end
end
local function SaveConfig()
    if not HasFS() then return false end
    return pcall(function() writefile(CONFIG_PATH, Http:JSONEncode(SerializeConfig())) end)
end
LoadConfig()

-- ═══════════════ STATE ═══════════════
local Connections, Drawings = {}, {}
local function AddConn(c) table.insert(Connections, c) end
local function AddDraw(d) table.insert(Drawings, d) end

-- ═══════════════ GUI ROOT ═══════════════
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MeowMod"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 999
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = PG
getgenv()._MeowModGui = ScreenGui

-- ═══════════════ THEME ═══════════════
local THEME = {
    Bg      = Config.ColorBg,
    Panel   = Config.ColorPanel,
    Header  = Color3.fromRGB(22, 22, 32),
    Accent  = Config.ColorNeon,
    Text    = Color3.fromRGB(225, 225, 230),
    SubText = Color3.fromRGB(160, 160, 170),
    Track   = Color3.fromRGB(40, 40, 50),
    TabIdle = Color3.fromRGB(25, 25, 38),
    Danger  = Color3.fromRGB(255, 70, 90),
    Warn    = Color3.fromRGB(255, 180, 60),
}

local function corner(inst, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 8)
    c.Parent = inst
    return c
end
local function stroke(inst, color, thickness, transparency)
    local s = Instance.new("UIStroke")
    s.Color = color or THEME.Accent
    s.Thickness = thickness or 1
    s.Transparency = transparency or 0.4
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = inst
    return s
end
local function pad(inst, p)
    local u = Instance.new("UIPadding")
    u.PaddingTop = UDim.new(0, p)
    u.PaddingBottom = UDim.new(0, p)
    u.PaddingLeft = UDim.new(0, p)
    u.PaddingRight = UDim.new(0, p)
    u.Parent = inst
    return u
end

-- ═══════════════ MAIN WINDOW ═══════════════
local isOpen = false
local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, 340, 0, 500)
Main.Position = UDim2.new(0.5, -170, 0.5, -250)
Main.BackgroundColor3 = THEME.Bg
Main.BackgroundTransparency = 0.05
Main.BorderSizePixel = 0
Main.Active = true
Main.Visible = false
Main.Parent = ScreenGui
corner(Main, 14)
stroke(Main, THEME.Accent, 1.5, 0.3)
Main.ClipsDescendants = true

-- Header
local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 52)
Header.BackgroundColor3 = THEME.Header
Header.BorderSizePixel = 0
Header.Active = true
Header.Parent = Main
corner(Header, 14)

local HeaderAccent = Instance.new("Frame")
HeaderAccent.Size = UDim2.new(1, 0, 0, 2)
HeaderAccent.Position = UDim2.new(0, 0, 1, -2)
HeaderAccent.BackgroundColor3 = THEME.Accent
HeaderAccent.BorderSizePixel = 0
HeaderAccent.Parent = Header

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -140, 1, 0)
TitleLabel.Position = UDim2.new(0, 16, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "MEOW V3.1"
TitleLabel.TextColor3 = THEME.Accent
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Font = Enum.Font.GothamBlack
TitleLabel.TextSize = 18
TitleLabel.Parent = Header

local VersionBadge = Instance.new("TextLabel")
VersionBadge.Size = UDim2.new(0, 44, 0, 20)
VersionBadge.Position = UDim2.new(0, 145, 0.5, -10)
VersionBadge.BackgroundColor3 = Color3.fromRGB(30, 40, 55)
VersionBadge.Text = "MOBILE"
VersionBadge.TextColor3 = THEME.Accent
VersionBadge.Font = Enum.Font.GothamBold
VersionBadge.TextSize = 10
VersionBadge.BorderSizePixel = 0
VersionBadge.Parent = Header
corner(VersionBadge, 6)

-- Close (×)  — hides menu, shows float
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 34, 0, 34)
CloseBtn.Position = UDim2.new(1, -80, 0, 9)
CloseBtn.BackgroundColor3 = THEME.Danger
CloseBtn.Text = "×"
CloseBtn.TextColor3 = Color3.new(1, 1, 1)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 20
CloseBtn.AutoButtonColor = false
CloseBtn.BorderSizePixel = 0
CloseBtn.Parent = Header
corner(CloseBtn, 8)

-- Full unload (⏻)
local UnloadBtn = Instance.new("TextButton")
UnloadBtn.Size = UDim2.new(0, 34, 0, 34)
UnloadBtn.Position = UDim2.new(1, -42, 0, 9)
UnloadBtn.BackgroundColor3 = Color3.fromRGB(60, 30, 40)
UnloadBtn.Text = "⏻"
UnloadBtn.TextColor3 = THEME.Warn
UnloadBtn.Font = Enum.Font.GothamBold
UnloadBtn.TextSize = 18
UnloadBtn.AutoButtonColor = false
UnloadBtn.BorderSizePixel = 0
UnloadBtn.Parent = Header
corner(UnloadBtn, 8)

-- ═══════════════ TAB BAR ═══════════════
local TabBar = Instance.new("ScrollingFrame")
TabBar.Name = "TabBar"
TabBar.Size = UDim2.new(1, -20, 0, 42)
TabBar.Position = UDim2.new(0, 10, 0, 60)
TabBar.BackgroundTransparency = 1
TabBar.BorderSizePixel = 0
TabBar.ScrollBarThickness = 0
TabBar.ScrollingDirection = Enum.ScrollingDirection.X
TabBar.CanvasSize = UDim2.new(0, 0, 0, 0)
TabBar.AutomaticCanvasSize = Enum.AutomaticSize.X
TabBar.Parent = Main
local TL = Instance.new("UIListLayout", TabBar)
TL.FillDirection = Enum.FillDirection.Horizontal
TL.Padding = UDim.new(0, 6)
TL.SortOrder = Enum.SortOrder.LayoutOrder
TL.VerticalAlignment = Enum.VerticalAlignment.Center

local Pages = {}
local TabButtons = {}
local function SelectTab(name)
    for n, p in pairs(Pages) do p.Visible = (n == name) end
    for n, b in pairs(TabButtons) do
        if n == name then
            TweenService:Create(b, TweenInfo.new(0.15), {
                BackgroundColor3 = THEME.Accent
            }):Play()
            b.TextColor3 = Color3.new(0, 0, 0)
        else
            TweenService:Create(b, TweenInfo.new(0.15), {
                BackgroundColor3 = THEME.TabIdle
            }):Play()
            b.TextColor3 = THEME.SubText
        end
    end
end
local function CreateTab(name, order)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(0, 92, 0, 34)
    Btn.BackgroundColor3 = THEME.TabIdle
    Btn.Text = name
    Btn.TextColor3 = THEME.SubText
    Btn.Font = Enum.Font.GothamBold
    Btn.TextSize = 12
    Btn.LayoutOrder = order
    Btn.AutoButtonColor = false
    Btn.BorderSizePixel = 0
    Btn.Parent = TabBar
    corner(Btn, 8)
    TabButtons[name] = Btn

    local Page = Instance.new("ScrollingFrame")
    Page.Name = name
    Page.Size = UDim2.new(1, -20, 1, -112)
    Page.Position = UDim2.new(0, 10, 0, 108)
    Page.BackgroundTransparency = 1
    Page.Visible = false
    Page.CanvasSize = UDim2.new(0, 0, 0, 0)
    Page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    Page.ScrollBarThickness = 3
    Page.ScrollBarImageColor3 = THEME.Accent
    Page.BorderSizePixel = 0
    Page.Parent = Main
    local L = Instance.new("UIListLayout", Page)
    L.Padding = UDim.new(0, 8)
    L.SortOrder = Enum.SortOrder.LayoutOrder
    Pages[name] = Page

    Btn.MouseButton1Click:Connect(function() SelectTab(name) end)
end

-- ═══════════════ WIDGETS ═══════════════
local SaveDebounce = 0
local function QueueSave()
    SaveDebounce = SaveDebounce + 1
    local myId = SaveDebounce
    task.delay(0.5, function() if myId == SaveDebounce then SaveConfig() end end)
end

local function CreateToggle(parent, name, def, cb, cfgKey)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(1, 0, 0, 46)
    Btn.BackgroundColor3 = THEME.Panel
    Btn.Text = ""
    Btn.AutoButtonColor = false
    Btn.BorderSizePixel = 0
    Btn.Parent = parent
    corner(Btn, 8)

    local TLbl = Instance.new("TextLabel")
    TLbl.Size = UDim2.new(1, -80, 1, 0)
    TLbl.Position = UDim2.new(0, 14, 0, 0)
    TLbl.BackgroundTransparency = 1
    TLbl.Text = name
    TLbl.TextColor3 = THEME.Text
    TLbl.TextXAlignment = Enum.TextXAlignment.Left
    TLbl.Font = Enum.Font.GothamMedium
    TLbl.TextSize = 13
    TLbl.Parent = Btn

    local Ind = Instance.new("Frame")
    Ind.Size = UDim2.new(0, 42, 0, 24)
    Ind.Position = UDim2.new(1, -54, 0.5, -12)
    Ind.BackgroundColor3 = def and THEME.Accent or Color3.fromRGB(55, 55, 70)
    Ind.BorderSizePixel = 0
    Ind.Parent = Btn
    corner(Ind, 12)

    local Circ = Instance.new("Frame")
    Circ.Size = UDim2.new(0, 18, 0, 18)
    Circ.Position = def and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
    Circ.BackgroundColor3 = Color3.new(1, 1, 1)
    Circ.BorderSizePixel = 0
    Circ.Parent = Ind
    corner(Circ, 9)

    local State = def
    AddConn(Btn.MouseButton1Click:Connect(function()
        State = not State
        TweenService:Create(Ind, TweenInfo.new(0.15), {
            BackgroundColor3 = State and THEME.Accent or Color3.fromRGB(55, 55, 70)
        }):Play()
        TweenService:Create(Circ, TweenInfo.new(0.15), {
            Position = State and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
        }):Play()
        if cfgKey then Config[cfgKey] = State end
        if cb then cb(State) end
        QueueSave()
    end))
    return Btn
end

local function CreateSlider(parent, name, mn, mx, def, cb, cfgKey)
    local F = Instance.new("Frame")
    F.Size = UDim2.new(1, 0, 0, 60)
    F.BackgroundColor3 = THEME.Panel
    F.BorderSizePixel = 0
    F.Parent = parent
    corner(F, 8)

    local TLbl = Instance.new("TextLabel")
    TLbl.Size = UDim2.new(1, -20, 0, 22)
    TLbl.Position = UDim2.new(0, 14, 0, 6)
    TLbl.BackgroundTransparency = 1
    TLbl.Text = name .. ": " .. tostring(def)
    TLbl.TextColor3 = THEME.Text
    TLbl.TextXAlignment = Enum.TextXAlignment.Left
    TLbl.Font = Enum.Font.GothamMedium
    TLbl.TextSize = 13
    TLbl.Parent = F

    local Bg = Instance.new("Frame")
    Bg.Size = UDim2.new(1, -28, 0, 8)
    Bg.Position = UDim2.new(0, 14, 0, 38)
    Bg.BackgroundColor3 = THEME.Track
    Bg.BorderSizePixel = 0
    Bg.Parent = F
    corner(Bg, 4)

    local Fill = Instance.new("Frame")
    Fill.Size = UDim2.new((def - mn) / (mx - mn), 0, 1, 0)
    Fill.BackgroundColor3 = THEME.Accent
    Fill.BorderSizePixel = 0
    Fill.Parent = Bg
    corner(Fill, 4)

    local Hit = Instance.new("TextButton")
    Hit.Size = UDim2.new(1, 0, 4, 0)
    Hit.Position = UDim2.new(0, 0, -1.5, 0)
    Hit.BackgroundTransparency = 1
    Hit.Text = ""
    Hit.Parent = Bg

    local dragging = false
    local function Update(input)
        local pos = math.clamp((input.Position.X - Bg.AbsolutePosition.X) / Bg.AbsoluteSize.X, 0, 1)
        local v = math.floor(mn + (mx - mn) * pos)
        Fill.Size = UDim2.new(pos, 0, 1, 0)
        TLbl.Text = name .. ": " .. tostring(v)
        if cfgKey then Config[cfgKey] = v end
        if cb then cb(v) end
    end
    AddConn(Hit.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            Update(inp)
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
    return F
end

local function CreateButton(parent, name, cb, color)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(1, 0, 0, 46)
    Btn.BackgroundColor3 = color or Color3.fromRGB(30, 30, 45)
    Btn.Text = name
    Btn.TextColor3 = THEME.Accent
    Btn.Font = Enum.Font.GothamBold
    Btn.TextSize = 13
    Btn.AutoButtonColor = false
    Btn.BorderSizePixel = 0
    Btn.Parent = parent
    corner(Btn, 8)
    Btn.MouseButton1Click:Connect(function()
        Btn.BackgroundColor3 = Color3.fromRGB(0, 255, 150)
        task.wait(0.15)
        Btn.BackgroundColor3 = color or Color3.fromRGB(30, 30, 45)
        if cb then cb() end
    end)
    return Btn
end

local function CreateCycle(parent, name, options, default, cb, cfgKey)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(1, 0, 0, 46)
    Btn.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    Btn.Text = name .. ": " .. default
    Btn.TextColor3 = THEME.Accent
    Btn.Font = Enum.Font.GothamBold
    Btn.TextSize = 13
    Btn.AutoButtonColor = false
    Btn.BorderSizePixel = 0
    Btn.Parent = parent
    corner(Btn, 8)
    local idx = 1
    for i, o in ipairs(options) do
        if o == default then idx = i break end
    end
    Btn.MouseButton1Click:Connect(function()
        idx = idx + 1
        if idx > #options then idx = 1 end
        Btn.Text = name .. ": " .. options[idx]
        if cfgKey then Config[cfgKey] = options[idx] end
        if cb then cb(options[idx]) end
        QueueSave()
    end)
    return Btn
end

-- ═══════════════ TAB CREATION ═══════════════
CreateTab("Combat", 1)
CreateTab("Visuals", 2)
CreateTab("Players", 3)
CreateTab("Vehicles", 4)
CreateTab("Teleport", 5)
CreateTab("Config", 6)

-- ═══════════════ FLOAT BUTTON ═══════════════
local FloatBtn = Instance.new("TextButton")
FloatBtn.Name = "FloatBtn"
FloatBtn.Size = UDim2.new(0, 52, 0, 52)
FloatBtn.Position = UDim2.new(0, 15, 0.4, 0)
FloatBtn.BackgroundColor3 = THEME.Accent
FloatBtn.Text = "M"
FloatBtn.TextColor3 = Color3.new(0, 0, 0)
FloatBtn.Font = Enum.Font.GothamBlack
FloatBtn.TextSize = 20
FloatBtn.BorderSizePixel = 0
FloatBtn.Active = true
FloatBtn.Draggable = true
FloatBtn.Parent = ScreenGui
corner(FloatBtn, 26)
stroke(FloatBtn, Color3.new(1, 1, 1), 1, 0.7)

-- ═══════════════ OPEN / CLOSE / UNLOAD WIRING ═══════════════
local function OpenMenu()
    Main.Visible = true
    FloatBtn.Visible = false
    isOpen = true
    Main.Size = UDim2.new(0, 340, 0, 500)
    Main.BackgroundTransparency = 1
    TweenService:Create(Main, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        BackgroundTransparency = 0.05
    }):Play()
end
local function CloseMenu()
    Main.Visible = false
    FloatBtn.Visible = true
    isOpen = false
end

FloatBtn.MouseButton1Click:Connect(OpenMenu)
CloseBtn.MouseButton1Click:Connect(CloseMenu)

-- ═══════════════ UNLOAD (FULL TEARDOWN) ═══════════════
local function FullUnload()
    if getgenv()._MeowModUnloading then return end
    getgenv()._MeowModUnloading = true

    -- Config save on exit
    pcall(SaveConfig)

    -- Disconnect everything
    for _, c in pairs(Connections) do
        pcall(function()
            if typeof(c) == "RBXScriptConnection" then c:Disconnect() end
        end)
    end
    Connections = {}

    -- Unbind render steps
    for _, name in ipairs({"MeowESP", "MeowESP2", "MeowLogic"}) do
        pcall(function() RunService:UnbindFromRenderStep(name) end)
    end

    -- Remove drawings
    for _, d in pairs(Drawings) do
        pcall(function() d:Remove() end)
    end
    Drawings = {}

    -- Restore hitboxes on everyone
    for _, p in pairs(Players:GetPlayers()) do
        local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            pcall(function()
                hrp.Size = Vector3.new(2, 2, 1)
                hrp.Transparency = 1
                hrp.CanCollide = true
            end)
        end
    end

    -- Restore namecall metamethod
    pcall(function()
        local mt = getrawmetatable(game)
        setreadonly(mt, false)
        mt.__namecall = newcclosure(nil)
        setreadonly(mt, true)
    end)

    -- Nuke GUI
    pcall(function() ScreenGui:Destroy() end)
    if getgenv()._MeowModGui == ScreenGui then getgenv()._MeowModGui = nil end

    -- Clear globals
    getgenv().MeowModUnload = nil
    getgenv()._MeowModUnloading = nil
end
getgenv().MeowModUnload = FullUnload

UnloadBtn.MouseButton1Click:Connect(function()
    FullUnload()
end)

-- ═══════════════ TELEPORT (v8, unchanged) ═══════════════
local function GetGroundY(pos)
    local rp = RaycastParams.new()
    rp.FilterDescendantsInstances = {LP.Character}
    rp.FilterType = Enum.RaycastFilterType.Exclude
    local ray = Ray.new(pos + Vector3.new(0, 500, 0), Vector3.new(0, -1000, 0))
    local hit = WS:Raycast(ray.Origin, ray.Direction, rp)
    if hit then return hit.Position.Y end
    return nil
end

local function SafeTeleport(pos, label)
    local c = LP.Character
    local hrp = c and c:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local targetY = pos.Y
    if Config.TP_DropToGround then
        local groundY = GetGroundY(pos)
        if groundY then targetY = groundY + 3.5 end
    end
    hrp.CFrame = CFrame.new(Vector3.new(pos.X, targetY + (Config.TP_SafeDrop or 4), pos.Z))
    pcall(function()
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end)
    return true
end

local function TPBase()
    local myTeam = LP.Team and LP.Team.Name:lower() or ""
    local myColor = LP.TeamColor and LP.TeamColor.Color or nil
    local best, bestDist = nil, math.huge
    local myHrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    local myPos = myHrp and myHrp.Position or Vector3.zero
    for _, o in pairs(WS:GetDescendants()) do
        if o:IsA("SpawnLocation") and o.Enabled then
            local matches = false
            if myColor and o.BrickColor.Color == myColor then matches = true end
            if not matches and myTeam ~= "" then
                local path = o:GetFullName():lower()
                if path:find(myTeam) then matches = true end
            end
            if not matches and o.Neutral and myTeam == "" then matches = true end
            if matches then
                local d = (myPos - o.Position).Magnitude
                if d < bestDist then bestDist = d; best = {pos = o.Position, name = o:GetFullName()} end
            end
        end
    end
    if best then return SafeTeleport(best.pos, "Base(spawn)") end
    return false
end

local function TPAirdrop()
    local myHrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    local myPos = myHrp and myHrp.Position or Vector3.zero
    local best, bestScore = nil, -math.huge
    for _, o in pairs(WS:GetDescendants()) do
        if o and (o:IsA("BasePart") or o:IsA("Model")) then
            local n = o.Name:lower()
            if n:find("airdrop") or n:find("crate") or n:find("parachute") then
                local path = o:GetFullName():lower()
                local bad = path:find("menu") or path:find("shop") or path:find("base") or path:find("spawn")
                if not bad then
                    local p = o:IsA("BasePart") and o.Position or (o.PrimaryPart and o.PrimaryPart.Position)
                    if p then
                        local score = 100 - math.clamp((myPos - p).Magnitude * 0.05, 0, 100)
                        if score > bestScore then bestScore = score; best = p end
                    end
                end
            end
        end
    end
    if best then return SafeTeleport(best, "Airdrop") end
    return false
end

local function TPCrashedUAV()
    local myHrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    local myPos = myHrp and myHrp.Position or Vector3.zero
    local best, bestScore = nil, -math.huge
    for _, o in pairs(WS:GetDescendants()) do
        if o and (o:IsA("BasePart") or o:IsA("Model")) then
            local n = o.Name:lower()
            if n:find("uav") or n:find("drone") or n:find("crashed") or n:find("wreck") then
                local path = o:GetFullName():lower()
                local bad = path:find("spawn") or path:find("pad") or path:find("hangar")
                if not bad then
                    local p = o:IsA("BasePart") and o.Position or (o.PrimaryPart and o.PrimaryPart.Position)
                    if p then
                        local score = 100 - math.clamp((myPos - p).Magnitude * 0.05, 0, 100)
                        if score > bestScore then bestScore = score; best = p end
                    end
                end
            end
        end
    end
    if best then return SafeTeleport(best, "UAV") end
    return false
end

local function TPCapture()
    local myHrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not myHrp then return false end
    local myPos = myHrp.Position
    local best, bestScore = nil, -math.huge
    for _, o in pairs(WS:GetDescendants()) do
        if o and o:IsA("BasePart") then
            local n = o.Name:lower()
            if n:find("flag") and o.Position.Y > myPos.Y + 3 then
                local path = o:GetFullName():lower()
                local bad = path:find("spawn") or path:find("base") or path:find("barracks")
                if not bad then
                    local score = 500 - math.clamp((myPos - o.Position).Magnitude * 0.05, 0, 100)
                    if score > bestScore then bestScore = score; best = o.Position end
                end
            end
        end
    end
    if best then return SafeTeleport(best, "Capture") end
    return false
end

-- ═══════════════ WIDGET LAYOUT ═══════════════
-- Combat
CreateToggle(Pages["Combat"], "Silent Aim", Config.SilentAim, nil, "SilentAim")
CreateToggle(Pages["Combat"], "Strict FOV", Config.StrictFOV, nil, "StrictFOV")
CreateToggle(Pages["Combat"], "Show FOV Circle", Config.ShowFOV, nil, "ShowFOV")
CreateToggle(Pages["Combat"], "Headshot", Config.Headshot, nil, "Headshot")
CreateToggle(Pages["Combat"], "Wall Check", Config.WallCheck, nil, "WallCheck")
CreateToggle(Pages["Combat"], "Bypass v15", Config.Bypass, nil, "Bypass")
CreateSlider(Pages["Combat"], "FOV %", 5, 100, Config.FOVPercent, nil, "FOVPercent")
CreateSlider(Pages["Combat"], "Max Dist", 500, 5000, Config.MaxDistance, nil, "MaxDistance")
CreateSlider(Pages["Combat"], "Prediction x10", 5, 30, math.floor(Config.PredictionMultiplier * 10), function(v)
    Config.PredictionMultiplier = v / 10
end)

-- Visuals
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
                hrp.Size = Vector3.new(2, 2, 1)
                hrp.Transparency = 1
                hrp.CanCollide = true
            end
        end
    end
end, "HitboxExpander")
CreateSlider(Pages["Visuals"], "Hitbox Size", 2, 20, Config.HitboxSize, nil, "HitboxSize")
CreateToggle(Pages["Visuals"], "Crosshair", Config.Crosshair, nil, "Crosshair")
CreateSlider(Pages["Visuals"], "CH Size", 5, 30, Config.CH_Size, nil, "CH_Size")

-- Vehicles
local VehicleESP = {}
CreateToggle(Pages["Vehicles"], "Vehicle ESP", Config.V_ESP, function(v)
    Config.V_ESP = v
    if not v then
        for model, d in pairs(VehicleESP) do
            if d.Box then pcall(function() d.Box.Visible = false end) end
            if d.Name then pcall(function() d.Name.Visible = false end) end
            if d.Dist then pcall(function() d.Dist.Visible = false end) end
        end
    end
end, "V_ESP")
CreateToggle(Pages["Vehicles"], " - Box", Config.V_ESP_Box, nil, "V_ESP_Box")
CreateToggle(Pages["Vehicles"], " - Name", Config.V_ESP_Name, nil, "V_ESP_Name")
CreateToggle(Pages["Vehicles"], " - Dist", Config.V_ESP_Dist, nil, "V_ESP_Dist")
CreateSlider(Pages["Vehicles"], "Veh Max Dist", 100, 10000, Config.V_ESP_MaxDist, nil, "V_ESP_MaxDist")

-- Teleport
CreateToggle(Pages["Teleport"], "Drop to ground", Config.TP_DropToGround, nil, "TP_DropToGround")
CreateSlider(Pages["Teleport"], "Safe drop", 1, 20, Config.TP_SafeDrop, nil, "TP_SafeDrop")
CreateButton(Pages["Teleport"], "TP Base", TPBase)
CreateButton(Pages["Teleport"], "TP Airdrop", TPAirdrop)
CreateButton(Pages["Teleport"], "TP Crashed UAV", TPCrashedUAV)
CreateButton(Pages["Teleport"], "TP Capture Point", TPCapture)
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
    if best then SafeTeleport(best.Position + Vector3.new(0, 3, 0), "nearest enemy") end
end)

-- Config tab
CreateButton(Pages["Config"], "💾  Save Config", function() SaveConfig() end)
CreateButton(Pages["Config"], "📂  Load Config", function()
    LoadConfig()
    -- Widgets won't refresh labels live; a rejoin or re-execute applies values.
end)
CreateButton(Pages["Config"], "🔄  Reload Script", function()
    local src = HasFS() and nil
    FullUnload()
    -- caller re-executes; nothing else to do safely
end, Color3.fromRGB(60, 40, 60))
CreateButton(Pages["Config"], "⏻  FULL UNLOAD", function()
    FullUnload()
end, Color3.fromRGB(80, 30, 40))

-- ═══════════════ UTIL ═══════════════
local function DistToColor(d)
    local t = math.clamp(d / 400, 0, 1)
    if d <= 100 then
        local k = d / 100
        return Color3.fromRGB(math.floor(255 - k * 55), math.floor(60 + k * 120), 60)
    end
    return Color3.fromRGB(math.floor(200 * (1 - t)), math.floor(180 + 75 * t), math.floor(60 + 80 * t))
end
local function PassesTeamFilter(p)
    if Config.TeamFilter == "all" then return true end
    local myTeam = LP.Team
    if not myTeam then return true end
    if Config.TeamFilter == "my" then return p.Team == myTeam end
    if Config.TeamFilter == "enemy" then return p.Team ~= myTeam end
    return true
end

-- ═══════════════ PLAYER LIST ═══════════════
local PL = Instance.new("UIListLayout", Pages["Players"])
PL.Padding = UDim.new(0, 6)
local function UpdatePlayerList()
    for _, v in pairs(Pages["Players"]:GetChildren()) do
        if v:IsA("TextButton") then v:Destroy() end
    end
    local myHrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LP and p.Character and PassesTeamFilter(p) then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            if hrp and hum and hum.Health > 0 then
                local d = myHrp and math.floor((myHrp.Position - hrp.Position).Magnitude) or 0
                local Btn = Instance.new("TextButton")
                Btn.Size = UDim2.new(1, 0, 0, 46)
                Btn.BackgroundColor3 = THEME.Panel
                Btn.Text = "  " .. p.Name .. "  [" .. d .. "m]"
                Btn.TextColor3 = DistToColor(d)
                Btn.TextXAlignment = Enum.TextXAlignment.Left
                Btn.Font = Enum.Font.GothamMedium
                Btn.TextSize = 13
                Btn.BorderSizePixel = 0
                Btn.Parent = Pages["Players"]
                corner(Btn, 8)
                Btn.MouseButton1Click:Connect(function()
                    if hrp then
                        SafeTeleport(hrp.Position + Vector3.new(Config.TP_PlayerOffset, 3, Config.TP_PlayerOffset),
                            "player " .. p.Name)
                    end
                end)
            end
        end
    end
end
task.spawn(function() while task.wait(2) do UpdatePlayerList() end end)

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
    for _, v in pairs(Pages["Vehicles"]:GetChildren()) do
        if v:IsA("TextButton") and v:GetAttribute("isVeh") then v:Destroy() end
    end
    local myHrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not myHrp then return end
    local models = CollectUniqueModels()
    for _, model in ipairs(models) do
        local anchor = ModelAnchor(model)
        if anchor then
            local d = math.floor((myHrp.Position - anchor.Position).Magnitude)
            local Btn = Instance.new("TextButton")
            Btn:SetAttribute("isVeh", true)
            Btn.Size = UDim2.new(1, 0, 0, 46)
            Btn.BackgroundColor3 = THEME.Panel
            Btn.Text = "  " .. model.Name .. "  [" .. d .. "m]"
            Btn.TextColor3 = DistToColor(d)
            Btn.TextXAlignment = Enum.TextXAlignment.Left
            Btn.Font = Enum.Font.GothamMedium
            Btn.TextSize = 13
            Btn.BorderSizePixel = 0
            Btn.Parent = Pages["Vehicles"]
            corner(Btn, 8)
            Btn.MouseButton1Click:Connect(function()
                if anchor and anchor.Parent then
                    SafeTeleport(anchor.Position + Vector3.new(0, 6, 0), "vehicle")
                end
            end)
        end
    end
end
task.spawn(function() while task.wait(3) do UpdateVehicleList() end end)

-- ═══════════════ ESP / DRAWINGS ═══════════════
local DebugHUD = Instance.new("TextLabel")
DebugHUD.Size = UDim2.new(0, 400, 0, 30)
DebugHUD.Position = UDim2.new(0.5, -200, 1, -40)
DebugHUD.BackgroundTransparency = 1
DebugHUD.Text = "FOV Debug: --"
DebugHUD.TextColor3 = Config.ColorSilent
DebugHUD.Font = Enum.Font.Code
DebugHUD.TextSize = 14
DebugHUD.Parent = ScreenGui

local CH1 = Drawing.new("Line")
local CH2 = Drawing.new("Line")
CH1.Thickness = 2; CH2.Thickness = 2
CH1.Color = Config.ColorNeon; CH2.Color = Config.ColorNeon
AddDraw(CH1); AddDraw(CH2)

local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 1.5
FOVCircle.Transparency = 0.8
FOVCircle.Color = Config.ColorNeon
FOVCircle.Filled = false
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

local ESP = {}
local function ForceHide(d)
    if not d then return end
    local fields = {"Line","Box","NameBg","Name","Dist","HpBg","HpBar","HpText","OffArrow","DistBarBg","DistBarFg"}
    for _, k in ipairs(fields) do if d[k] then d[k].Visible = false end end
    if d.Bones then for _, b in pairs(d.Bones) do pcall(function() b.Visible = false end) end end
end

local function CreateDraw(player)
    if ESP[player] then return ESP[player] end
    local ok, tbl = pcall(function()
        local t = {
            Line = Drawing.new("Line"), Box = Drawing.new("Square"),
            NameBg = Drawing.new("Square"), Name = Drawing.new("Text"),
            Dist = Drawing.new("Text"), HpBg = Drawing.new("Square"),
            HpBar = Drawing.new("Square"), HpText = Drawing.new("Text"),
            OffArrow = Drawing.new("Triangle"),
            DistBarBg = Drawing.new("Square"), DistBarFg = Drawing.new("Square"),
            Bones = {},
        }
        for i = 1, #BONE_PAIRS do
            t.Bones[i] = Drawing.new("Line")
            t.Bones[i].Thickness = 1
        end
        return t
    end)
    if not ok or not tbl then return nil end
    tbl.Line.Thickness = 1
    tbl.Box.Thickness = 1
    tbl.NameBg.Filled = true
    tbl.NameBg.Color = Color3.fromRGB(15, 15, 22)
    tbl.NameBg.Transparency = 0.7
    tbl.Name.Size = 13; tbl.Name.Center = true; tbl.Name.Outline = true
    tbl.Dist.Size = 12; tbl.Dist.Center = true; tbl.Dist.Outline = true
    tbl.HpBg.Filled = true; tbl.HpBg.Color = Color3.new(0, 0, 0)
    tbl.HpBar.Filled = true
    tbl.HpText.Size = 10; tbl.HpText.Center = true; tbl.HpText.Outline = true
    tbl.OffArrow.Filled = true
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
    local cx, cy = vp.X / 2, vp.Y / 2
    local dx, dy = sp.X - cx, sp.Y - cy
    if math.abs(dx) < 0.001 and math.abs(dy) < 0.001 then dx = 1 end
    local tx = (cx - margin) / math.max(math.abs(dx), 0.0001)
    local ty = (cy - margin) / math.max(math.abs(dy), 0.0001)
    local t = math.min(tx, ty)
    return Vector2.new(cx + dx * t, cy + dy * t)
end

local function GetScreenBox(char, hrp)
    local ok, cf, size = pcall(function() return char:GetBoundingBox() end)
    if ok and cf and size then
        local tS, tOn = Camera:WorldToViewportPoint(cf.Position + Vector3.new(0, size.Y / 2, 0))
        local bS, bOn = Camera:WorldToViewportPoint(cf.Position - Vector3.new(0, size.Y / 2, 0))
        local lS, lOn = Camera:WorldToViewportPoint(cf.Position - Vector3.new(size.X / 2, 0, 0))
        local rS, rOn = Camera:WorldToViewportPoint(cf.Position + Vector3.new(size.X / 2, 0, 0))
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
            if h > 0 and w > 0 then return {x = hS.X - w / 2, y = hS.Y, w = w, h = h} end
        end
    end
    return nil
end

local function RenderESP()
    if not Config.ESP then
        for _, d in pairs(ESP) do ForceHide(d) end
        CH1.Visible = false; CH2.Visible = false
        FOVCircle.Visible = false
        return
    end

    if Config.Crosshair then
        local cx, cy = Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2
        local sz = Config.CH_Size
        CH1.From = Vector2.new(cx - sz, cy); CH1.To = Vector2.new(cx + sz, cy); CH1.Visible = true
        CH2.From = Vector2.new(cx, cy - sz); CH2.To = Vector2.new(cx, cy + sz); CH2.Visible = true
    else
        CH1.Visible = false; CH2.Visible = false
    end

    local myChar = LP.Character
    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local myPos = myHrp and myHrp.Position
    local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
    local playerAlive = myHum and myHum.Health > 0

    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LP then
            local d = ESP[p]
            if not playerAlive then
                if d then ForceHide(d) end
            else
                local char = p.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local head = char and char:FindFirstChild("Head")
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if not (char and hrp and head and hum and hum.Health > 0 and PassesTeamFilter(p)) then
                    if d then ForceHide(d) end
                else
                    local d3 = myPos and (myPos - hrp.Position).Magnitude or 0
                    if d3 > Config.MaxDistance then
                        if d then ForceHide(d) end
                    else
                        local sp, onScreen = Camera:WorldToViewportPoint(hrp.Position)
                        if not d then d = CreateDraw(p) end
                        if d then
                            local isEnemy = LP.Team and p.Team and p.Team ~= LP.Team
                            local color
                            if LP.Team and p.Team then
                                color = isEnemy and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(80, 200, 255)
                            else
                                color = DistToColor(d3)
                            end

                            if not onScreen and Config.ESP_Offscreen then
                                local arrPos = OffscreenArrowPos(sp, 40)
                                local dir = (Vector2.new(sp.X, sp.Y) - arrPos).Unit
                                local perp = Vector2.new(-dir.Y, dir.X)
                                d.OffArrow.PointA = arrPos + dir * 14
                                d.OffArrow.PointB = arrPos - dir * 8 + perp * 10
                                d.OffArrow.PointC = arrPos - dir * 8 - perp * 10
                                d.OffArrow.Color = color
                                ForceHide(d)
                                d.OffArrow.Visible = true
                            elseif not onScreen then
                                ForceHide(d)
                            else
                                d.OffArrow.Visible = false
                                local box = GetScreenBox(char, hrp)
                                local x, y, w, h
                                if box then
                                    x, y, w, h = box.x, box.y, box.w, box.h
                                else
                                    h = math.clamp(8000 / math.max(d3, 1), 20, 500)
                                    w = h / 2
                                    x = sp.X - w / 2
                                    y = sp.Y - h / 2
                                end

                                d.Box.Visible = Config.ESP_Box
                                if d.Box.Visible then
                                    d.Box.Size = Vector2.new(w, h)
                                    d.Box.Position = Vector2.new(x, y)
                                    d.Box.Color = color
                                end

                                d.Line.Visible = Config.ESP_Line
                                if d.Line.Visible then
                                    d.Line.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                                    d.Line.To = Vector2.new(sp.X, sp.Y)
                                    d.Line.Color = color
                                end

                                d.Name.Visible = Config.ESP_Name
                                d.NameBg.Visible = Config.ESP_Name
                                if d.Name.Visible then
                                    local prefix = ""
                                    if LP.Team and p.Team then prefix = isEnemy and "[E] " or "[A] " end
                                    d.Name.Text = prefix .. p.Name
                                    d.Name.Position = Vector2.new(x + w / 2, y - 18)
                                    d.Name.Color = color
                                    local tw = #(prefix .. p.Name) * 7
                                    d.NameBg.Size = Vector2.new(tw + 12, 18)
                                    d.NameBg.Position = Vector2.new(x + w / 2 - (tw + 12) / 2, y - 19)
                                end

                                d.Dist.Visible = Config.ESP_Dist
                                if d.Dist.Visible then
                                    d.Dist.Text = tostring(math.floor(d3)) .. "m"
                                    d.Dist.Position = Vector2.new(x + w / 2, y + h + 2)
                                    d.Dist.Color = color
                                end

                                d.HpBg.Visible = Config.ESP_HP
                                d.HpBar.Visible = Config.ESP_HP
                                d.HpText.Visible = Config.ESP_HP
                                if d.HpBar.Visible and hum.MaxHealth > 0 then
                                    local hpP = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                                    local hpColor = Color3.fromRGB(255 * (1 - hpP), 255 * hpP, 0)
                                    d.HpBg.Size = Vector2.new(4, h)
                                    d.HpBg.Position = Vector2.new(x - 8, y)
                                    d.HpBar.Size = Vector2.new(4, h * hpP)
                                    d.HpBar.Position = Vector2.new(x - 8, y + h * (1 - hpP))
                                    d.HpBar.Color = hpColor
                                    d.HpText.Text = tostring(math.floor(hum.Health)) .. "/" .. tostring(math.floor(hum.MaxHealth))
                                    d.HpText.Position = Vector2.new(x - 10, y - 15)
                                    d.HpText.Color = hpColor
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
                                        else
                                            bone.Visible = false
                                        end
                                    else
                                        bone.Visible = false
                                    end
                                end

                                if Config.ESP_DistBar then
                                    local frac = math.clamp(1 - d3 / Config.MaxDistance, 0, 1)
                                    d.DistBarBg.Visible = true
                                    d.DistBarBg.Size = Vector2.new(w, 3)
                                    d.DistBarBg.Position = Vector2.new(x, y + h + 18)
                                    d.DistBarBg.Color = Color3.fromRGB(30, 30, 40)
                                    d.DistBarFg.Visible = true
                                    d.DistBarFg.Size = Vector2.new(w * frac, 3)
                                    d.DistBarFg.Position = Vector2.new(x, y + h + 18)
                                    d.DistBarFg.Color = color
                                else
                                    d.DistBarBg.Visible = false
                                    d.DistBarFg.Visible = false
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

local function CreateVehicleDraw(model)
    if VehicleESP[model] then return VehicleESP[model] end
    local ok, tbl = pcall(function()
        return {Box = Drawing.new("Square"), Name = Drawing.new("Text"), Dist = Drawing.new("Text")}
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
        for model, d in pairs(VehicleESP) do
            if d.Box then pcall(function() d.Box.Visible = false end) end
            if d.Name then pcall(function() d.Name.Visible = false end) end
            if d.Dist then pcall(function() d.Dist.Visible = false end) end
        end
        return
    end
    local myHrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    local myPos = myHrp and myHrp.Position
    local alive = {}
    for _, model in ipairs(CollectUniqueModels()) do
        if model.Parent then
            local anchor = ModelAnchor(model)
            if anchor then
                alive[model] = true
                local d = CreateVehicleDraw(model)
                if d then
                    local pos = anchor.Position
                    local d3 = myPos and (myPos - pos).Magnitude or 0
                    if d3 > (Config.V_ESP_MaxDist or 5000) then
                        for _, v in pairs(d) do v.Visible = false end
                    else
                        local sp, onScreen = Camera:WorldToViewportPoint(pos)
                        if not onScreen then
                            for _, v in pairs(d) do v.Visible = false end
                        else
                            local extOk, ext = pcall(function() return model:GetExtentsSize() end)
                            local w, h
                            if extOk and ext then
                                local szSp = Camera:WorldToViewportPoint(pos + ext / 2)
                                w = math.clamp(math.abs(szSp.X - sp.X) * 2, 22, 600)
                                h = math.clamp(math.abs(szSp.Y - sp.Y) * 2, 22, 600)
                            else
                                local s = math.clamp(8000 / math.max(d3, 1), 24, 300)
                                w, h = s, s
                            end
                            d.Box.Visible = Config.V_ESP_Box
                            if d.Box.Visible then
                                d.Box.Size = Vector2.new(w, h)
                                d.Box.Position = Vector2.new(sp.X - w / 2, sp.Y - h / 2)
                                d.Box.Color = Config.ColorVehicle
                            end
                            d.Name.Visible = Config.V_ESP_Name
                            if d.Name.Visible then
                                d.Name.Text = model.Name
                                d.Name.Position = Vector2.new(sp.X, sp.Y - h / 2 - 18)
                                d.Name.Color = Config.ColorVehicle
                            end
                            d.Dist.Visible = Config.V_ESP_Dist
                            if d.Dist.Visible then
                                d.Dist.Text = tostring(math.floor(d3)) .. "m"
                                d.Dist.Position = Vector2.new(sp.X, sp.Y + h / 2 + 2)
                                d.Dist.Color = Config.ColorVehicle
                            end
                        end
                    end
                end
            end
        end
    end
    for model, d in pairs(VehicleESP) do
        if not alive[model] then
            for _, v in pairs(d) do pcall(function() v:Remove() end) end
            VehicleESP[model] = nil
        end
    end
end

-- ═══════════════ AIM (Silent v3 + Bypass v15) ═══════════════
local LastSwitch = 0
local SwitchCD = 0.25
local LockHysteresis = 0

local function IsVisible(head)
    local rp = RaycastParams.new()
    rp.FilterDescendantsInstances = {LP.Character, head.Parent}
    rp.FilterType = Enum.RaycastFilterType.Exclude
    return WS:Raycast(Camera.CFrame.Position, head.Position - Camera.CFrame.Position, rp) == nil
end

local function GetFovRadiusPx()
    return (Camera.ViewportSize.Y / 2) * (Config.FOVPercent / 100)
end

local function IsStrictlyInFov(head)
    local sp, on = Camera:WorldToViewportPoint(head.Position)
    if not on or sp.Z < 0 then return false, 0 end
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local targetPos = Vector2.new(sp.X, sp.Y)
    local d2 = (targetPos - screenCenter).Magnitude
    local radius = GetFovRadiusPx()
    return d2 <= radius, d2
end

local function GetTarget()
    local myChar = LP.Character
    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
    if not myHrp or not myHum or myHum.Health <= 0 then return nil, 0 end
    local myPos = myHrp.Position
    local best, bestScore = nil, -math.huge
    local bestDistPx = 0
    local now = tick()
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LP and p.Character and PassesTeamFilter(p) then
            local head = p.Character:FindFirstChild("Head")
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if head and hum and hrp and hum.Health > 0 then
                local d3 = (myPos - head.Position).Magnitude
                if d3 <= Config.MaxDistance then
                    local inFov, distPx = IsStrictlyInFov(head)
                    if inFov then
                        local hp = hum.MaxHealth > 0 and (hum.Health / hum.MaxHealth) or 1
                        local visible = (not Config.WallCheck) or IsVisible(head)
                        local score = 500 - d3
                        if visible then score = score + 100 end
                        score = score - (1 - hp) * 50
                        local look = hrp.CFrame.LookVector
                        local toMe = (myPos - hrp.Position).Unit
                        if look:Dot(toMe) > 0.3 then score = score + 500 end
                        if now - LastSwitch < SwitchCD and LockHysteresis > 0 then score = score + 50 end
                        if score > bestScore then
                            bestScore = score
                            best = head
                            bestDistPx = distPx
                        end
                    end
                end
            end
        end
    end
    if best then LockHysteresis = 1 else LockHysteresis = 0 end
    return best, bestDistPx
end

local SilentLine = Drawing.new("Line")
SilentLine.Thickness = 1.5
SilentLine.Color = Config.ColorSilent
SilentLine.Transparency = 0.8
AddDraw(SilentLine)

local isShooting = false
local silentTarget = nil
local silentActive = false
local currentDistPx = 0
local pendingShots = {}

AddConn(UIS.InputBegan:Connect(function(inp, gp)
    if not gp and (inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch) then
        isShooting = true
    end
end))
AddConn(UIS.InputEnded:Connect(function(inp, gp)
    if not gp and (inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch) then
        isShooting = false
    end
end))

local function GetBypassOffset()
    if not Config.Bypass then return Vector3.zero end
    return Vector3.new((math.random() - 0.5) * 0.1, (math.random() - 0.5) * 0.1, (math.random() - 0.5) * 0.1)
end

pcall(function()
    local mt = getrawmetatable(game)
    local oldNC = mt.__namecall
    setreadonly(mt, false)
    mt.__namecall = newcclosure(function(self, ...)
        if silentActive and silentTarget and silentTarget.Parent then
            local m = getnamecallmethod()
            local offset = GetBypassOffset()
            if m == "Raycast" then
                local a = {...}
                if typeof(a[1]) == "Vector3" then
                    local tPos = silentTarget.Position + offset
                    a[2] = tPos - a[1]
                end
                return oldNC(self, unpack(a))
            elseif m == "FindPartOnRay" or m == "FindPartOnRayWithIgnoreList" then
                local a = {...}
                if typeof(a[1]) == "Ray" then
                    local tPos = silentTarget.Position + offset
                    a[1] = Ray.new(a[1].Origin, tPos - a[1].Origin)
                end
                return oldNC(self, unpack(a))
            end
        end
        return oldNC(self, ...)
    end)
    setreadonly(mt, true)
end)

local Frames = 0
local LastFpsUpdate = tick()

local function TickLogic(dt)
    Frames = Frames + 1
    local now = tick()
    if now - LastFpsUpdate >= 1 then Frames = 0; LastFpsUpdate = now end

    for i = #pendingShots, 1, -1 do
        if tick() >= pendingShots[i].fireAt then table.remove(pendingShots, i) end
    end

    if Config.SilentAim and isShooting then
        silentTarget, currentDistPx = GetTarget()
        silentActive = silentTarget ~= nil
        if silentActive and Config.Bypass and #pendingShots == 0 then
            local delay = 0.01 + math.random() * 0.03
            if math.random() < 0.5 then task.wait(0) end
        end
        if silentTarget then
            local sp, on = Camera:WorldToViewportPoint(silentTarget.Position)
            if on then
                SilentLine.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
                SilentLine.To = Vector2.new(sp.X, sp.Y)
                SilentLine.Visible = true
                SilentLine.Color = Config.ColorSilent
            else
                SilentLine.Visible = false
            end
            FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
            FOVCircle.Radius = GetFovRadiusPx()
            FOVCircle.Visible = Config.ShowFOV
            FOVCircle.Color = Config.ColorNeon
        else
            SilentLine.Visible = false
            if Config.ShowFOV then
                FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
                FOVCircle.Radius = GetFovRadiusPx()
                FOVCircle.Visible = true
            else
                FOVCircle.Visible = false
            end
        end
        DebugHUD.Text = string.format("FOV: %.0fpx | Target: %s", GetFovRadiusPx(), silentTarget and "LOCKED" or "none")
    else
        silentActive = false
        silentTarget = nil
        SilentLine.Visible = false
        FOVCircle.Visible = false
        DebugHUD.Text = "FOV Debug: off"
    end
end

local function ApplyHitbox()
    if not Config.HitboxExpander then return end
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.Size = Vector3.new(Config.HitboxSize, Config.HitboxSize, Config.HitboxSize)
                hrp.Transparency = 0.7
                hrp.CanCollide = false
            end
        end
    end
end

RunService:BindToRenderStep("MeowESP", Enum.RenderPriority.Camera.Value + 1, RenderESP)
RunService:BindToRenderStep("MeowESP2", Enum.RenderPriority.Camera.Value + 2, RenderVehicleESP)
RunService:BindToRenderStep("MeowLogic", Enum.RenderPriority.Camera.Value + 3, function(dt)
    TickLogic(dt)
    ApplyHitbox()
end)

-- ═══════════════ FIRST TAB ═══════════════
task.spawn(function()
    task.wait(0.1)
    SelectTab("Combat")
end)

-- Auto-open on load
OpenMenu()
