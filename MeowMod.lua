-- // MEOW MOD // COMPACT MOBILE BUILD
-- заливается на github, грузится через loadstring(game:HttpGet("RAW_URL"))()

if getgenv().UnloadMeow then pcall(getgenv().UnloadMeow) end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local WS = game:GetService("Workspace")
local LP = Players.LocalPlayer
local Cam = WS.CurrentCamera
local PG = LP:WaitForChild("PlayerGui")

local C = {
    Silent = false,
    ESP = false,
    Box = true,
    Name = true,
    Dist = true,
    FOV = 25,
    MaxDist = 5000,
    ColAim = Color3.fromRGB(180, 0, 255),
}

-- ═════ UI ═════
local SG = Instance.new("ScreenGui")
SG.Name = "MeowCompact"
SG.ResetOnSpawn = false
SG.Parent = PG

local Btn = Instance.new("TextButton")
Btn.Size = UDim2.fromOffset(50, 50)
Btn.Position = UDim2.new(0, 15, 0.4, 0)
Btn.BackgroundColor3 = C.ColAim
Btn.Text = "M"
Btn.TextColor3 = Color3.new(1,1,1)
Btn.Font = Enum.Font.GothamBlack
Btn.TextSize = 22
Btn.BorderSizePixel = 0
Btn.Draggable = true
Btn.Parent = SG
Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 25)

local Main = Instance.new("Frame")
Main.Size = UDim2.fromOffset(300, 400)
Main.Position = UDim2.fromScale(0.5, 0.5)
Main.AnchorPoint = Vector2.new(0.5, 0.5)
Main.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
Main.BorderSizePixel = 0
Main.Draggable = true
Main.Visible = false
Main.Parent = SG
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 12)
local Stroke = Instance.new("UIStroke", Main)
Stroke.Color = C.ColAim
Stroke.Thickness = 1.5

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 44)
Title.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
Title.Text = "MEOW COMPACT"
Title.TextColor3 = C.ColAim
Title.Font = Enum.Font.GothamBlack
Title.TextSize = 16
Title.BorderSizePixel = 0
Title.Parent = Main
Instance.new("UICorner", Title).CornerRadius = UDim.new(0, 12)

local Close = Instance.new("TextButton")
Close.Size = UDim2.fromOffset(32, 32)
Close.Position = UDim2.new(1, -40, 0, 6)
Close.BackgroundColor3 = Color3.fromRGB(255, 70, 70)
Close.Text = "×"
Close.TextColor3 = Color3.new(1,1,1)
Close.Font = Enum.Font.GothamBlack
Close.TextSize = 20
Close.BorderSizePixel = 0
Close.Parent = Main
Instance.new("UICorner", Close).CornerRadius = UDim.new(0, 8)

local Scroll = Instance.new("ScrollingFrame")
Scroll.Size = UDim2.new(1, -16, 1, -60)
Scroll.Position = UDim2.new(0, 8, 0, 52)
Scroll.BackgroundTransparency = 1
Scroll.ScrollBarThickness = 3
Scroll.ScrollBarImageColor3 = C.ColAim
Scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
Scroll.Parent = Main
Instance.new("UIListLayout", Scroll).Padding = UDim.new(0, 8)

local function Toggle(text, def, cb)
    local B = Instance.new("TextButton")
    B.Size = UDim2.new(1, 0, 0, 46)
    B.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    B.Text = ""
    B.AutoButtonColor = false
    B.BorderSizePixel = 0
    B.Parent = Scroll
    Instance.new("UICorner", B).CornerRadius = UDim.new(0, 8)
    local T = Instance.new("TextLabel")
    T.Size = UDim2.new(1, -70, 1, 0)
    T.Position = UDim2.new(0, 12, 0, 0)
    T.BackgroundTransparency = 1
    T.Text = text
    T.TextColor3 = Color3.fromRGB(230,230,240)
    T.Font = Enum.Font.GothamMedium
    T.TextSize = 14
    T.TextXAlignment = Enum.TextXAlignment.Left
    T.Parent = B
    local Ind = Instance.new("Frame")
    Ind.Size = UDim2.fromOffset(42, 24)
    Ind.Position = UDim2.new(1, -52, 0.5, -12)
    Ind.BackgroundColor3 = def and C.ColAim or Color3.fromRGB(55,55,70)
    Ind.BorderSizePixel = 0
    Ind.Parent = B
    Instance.new("UICorner", Ind).CornerRadius = UDim.new(1, 0)
    local Knob = Instance.new("Frame")
    Knob.Size = UDim2.fromOffset(18, 18)
    Knob.Position = def and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
    Knob.BackgroundColor3 = Color3.new(1,1,1)
    Knob.BorderSizePixel = 0
    Knob.Parent = Ind
    Instance.new("UICorner", Knob).CornerRadius = UDim.new(1, 0)
    local st = def
    B.MouseButton1Click:Connect(function()
        st = not st
        Ind.BackgroundColor3 = st and C.ColAim or Color3.fromRGB(55,55,70)
        Knob.Position = st and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
        if cb then cb(st) end
    end)
end

local function Slider(text, mn, mx, def, cb)
    local F = Instance.new("Frame")
    F.Size = UDim2.new(1, 0, 0, 56)
    F.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    F.BorderSizePixel = 0
    F.Parent = Scroll
    Instance.new("UICorner", F).CornerRadius = UDim.new(0, 8)
    local T = Instance.new("TextLabel")
    T.Size = UDim2.new(1, -20, 0, 20)
    T.Position = UDim2.new(0, 12, 0, 6)
    T.BackgroundTransparency = 1
    T.Text = text..": "..def
    T.TextColor3 = Color3.fromRGB(230,230,240)
    T.Font = Enum.Font.GothamMedium
    T.TextSize = 13
    T.TextXAlignment = Enum.TextXAlignment.Left
    T.Parent = F
    local Bg = Instance.new("Frame")
    Bg.Size = UDim2.new(1, -24, 0, 6)
    Bg.Position = UDim2.new(0, 12, 0, 38)
    Bg.BackgroundColor3 = Color3.fromRGB(45,45,58)
    Bg.BorderSizePixel = 0
    Bg.Parent = F
    Instance.new("UICorner", Bg).CornerRadius = UDim.new(1, 0)
    local Fill = Instance.new("Frame")
    Fill.Size = UDim2.new((def-mn)/(mx-mn), 0, 1, 0)
    Fill.BackgroundColor3 = C.ColAim
    Fill.BorderSizePixel = 0
    Fill.Parent = Bg
    Instance.new("UICorner", Fill).CornerRadius = UDim.new(1, 0)
    local Hit = Instance.new("TextButton")
    Hit.Size = UDim2.new(1, 0, 3, 0)
    Hit.Position = UDim2.new(0, 0, -1, 0)
    Hit.BackgroundTransparency = 1
    Hit.Text = ""
    Hit.Parent = Bg
    local dr = false
    local function Upd(p)
        local r = math.clamp((p - Bg.AbsolutePosition.X) / Bg.AbsoluteSize.X, 0, 1)
        local v = math.floor(mn + (mx-mn) * r + 0.5)
        Fill.Size = UDim2.new(r, 0, 1, 0)
        T.Text = text..": "..v
        if cb then cb(v) end
    end
    Hit.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dr = true; Upd(i.Position.X)
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if dr and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            Upd(i.Position.X)
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dr = false end
    end)
end

Toggle("Silent Aim", C.Silent, function(v) C.Silent = v end)
Toggle("ESP", C.ESP, function(v) C.ESP = v end)
Toggle("Box", C.Box, function(v) C.Box = v end)
Toggle("Name", C.Name, function(v) C.Name = v end)
Toggle("Distance", C.Dist, function(v) C.Dist = v end)
Slider("FOV %", 5, 100, C.FOV, function(v) C.FOV = v end)
Slider("Max Dist", 500, 5000, C.MaxDist, function(v) C.MaxDist = v end)

Btn.MouseButton1Click:Connect(function() Main.Visible = true; Btn.Visible = false end)
Close.MouseButton1Click:Connect(function() Main.Visible = false; Btn.Visible = true end)

-- ═════ SILENT AIM ═════
local SL = Drawing.new("Line")
SL.Thickness = 1.5
SL.Color = C.ColAim
SL.Transparency = 0.9

local FC = Drawing.new("Circle")
FC.Thickness = 1.5
FC.Color = C.ColAim
FC.Transparency = 0.7
FC.Filled = false

local target = nil
local active = false
local offset = Vector3.zero

local function FovPx() return (Cam.ViewportSize.Y * 0.5) * (C.FOV / 100) end

local function InFov(head)
    local sp, on = Cam:WorldToViewportPoint(head.Position)
    if not on or sp.Z < 0 then return false, math.huge end
    local cx, cy = Cam.ViewportSize.X * 0.5, Cam.ViewportSize.Y * 0.5
    local dx, dy = sp.X - cx, sp.Y - cy
    local d = math.sqrt(dx*dx + dy*dy)
    return d <= FovPx(), d
end

local function Pick()
    local mc = LP.Character
    local mh = mc and mc:FindFirstChild("HumanoidRootPart")
    local mhum = mc and mc:FindFirstChildOfClass("Humanoid")
    if not mh or not mhum or mhum.Health <= 0 then target = nil; active = false; return nil end
    local myPos = mh.Position
    local best, bestS = nil, -math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            local head = p.Character:FindFirstChild("Head")
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            if head and hum and hum.Health > 0 then
                local d3 = (myPos - head.Position).Magnitude
                if d3 <= C.MaxDist then
                    local ok, distPx = InFov(head)
                    if ok then
                        local s = -distPx
                        if s > bestS then best, bestS = head, s end
                    end
                end
            end
        end
    end
    target = best
    active = best ~= nil
    return best
end

local mt = getrawmetatable(game)
local oldNC = mt.__namecall
setreadonly(mt, false)
mt.__namecall = newcclosure(function(self, ...)
    if not active or not target or not target.Parent or self ~= WS then
        return oldNC(self, ...)
    end
    local m = getnamecallmethod()
    if m ~= "Raycast" and m ~= "FindPartOnRay" then
        return oldNC(self, ...)
    end
    local a = {...}
    local tp = target.Position + offset
    if m == "Raycast" and typeof(a[1]) == "Vector3" then
        a[2] = tp - a[1]
    elseif m == "FindPartOnRay" and typeof(a[1]) == "Ray" then
        a[1] = Ray.new(a[1].Origin, tp - a[1].Origin)
    end
    return oldNC(self, unpack(a))
end)
setreadonly(mt, true)

UIS.InputBegan:Connect(function(i, gp)
    if not gp and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
        offset = Vector3.new((math.random()-0.5)*0.1, (math.random()-0.5)*0.1, (math.random()-0.5)*0.1)
    end
end)

-- ═════ ESP ═════
local ESP = {}

local function hideAll(d)
    if not d then return end
    for _, k in ipairs({"Box","Name","Dist","NameBg"}) do
        if d[k] then d[k].Visible = false end
    end
end

local function makeESP()
    local d = {
        Box = Drawing.new("Square"),
        NameBg = Drawing.new("Square"),
        Name = Drawing.new("Text"),
        Dist = Drawing.new("Text"),
    }
    d.Box.Thickness = 1
    d.NameBg.Filled = true
    d.NameBg.Color = Color3.fromRGB(15,15,22)
    d.NameBg.Transparency = 0.6
    d.Name.Size = 13; d.Name.Center = true; d.Name.Outline = true
    d.Dist.Size = 12; d.Dist.Center = true; d.Dist.Outline = true
    return d
end

local function boxOf(char)
    local head = char:FindFirstChild("Head")
    local feet = char:FindFirstChild("LeftFoot") or char:FindFirstChild("LeftLowerLeg")
    if not head or not feet then return nil end
    local hS, hOn = Cam:WorldToViewportPoint(head.Position + Vector3.new(0,0.5,0))
    local fS, fOn = Cam:WorldToViewportPoint(feet.Position - Vector3.new(0,0.5,0))
    if not hOn or not fOn then return nil end
    local h = fS.Y - hS.Y
    if h <= 0 then return nil end
    local w = h * 0.55
    return { x = hS.X - w/2, y = hS.Y, w = w, h = h }
end

-- ═════ LOOP ═════
local espAcc = 0

RunService.RenderStepped:Connect(function(dt)
    -- AIM
    if C.Silent then
        local head = Pick()
        FC.Position = Vector2.new(Cam.ViewportSize.X*0.5, Cam.ViewportSize.Y*0.5)
        FC.Radius = FovPx()
        FC.Visible = true
        if head then
            local sp, on = Cam:WorldToViewportPoint(head.Position)
            if on then
                SL.From = Vector2.new(Cam.ViewportSize.X*0.5, Cam.ViewportSize.Y*0.5)
                SL.To = Vector2.new(sp.X, sp.Y)
                SL.Visible = true
            else SL.Visible = false end
        else SL.Visible = false end
    else
        SL.Visible = false
        FC.Visible = false
        target = nil; active = false
    end

    -- ESP
    espAcc = espAcc + dt
    if espAcc >= 1/30 then
        espAcc = 0
        if C.ESP then
            local myChar = LP.Character
            local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
            local myPos = myHrp and myHrp.Position
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LP then
                    local d = ESP[p] or makeESP()
                    if not ESP[p] then ESP[p] = d end
                    local char = p.Character
                    local hrp = char and char:FindFirstChild("HumanoidRootPart")
                    local hum = char and char:FindFirstChildOfClass("Humanoid")
                    if hrp and hum and hum.Health > 0 and myPos then
                        local dist = (myPos - hrp.Position).Magnitude
                        if dist <= C.MaxDist then
                            local sp, on = Cam:WorldToViewportPoint(hrp.Position)
                            if on then
                                local box = boxOf(char)
                                local x, y, w, h
                                if box then x,y,w,h = box.x, box.y, box.w, box.h
                                else
                                    h = math.clamp(8000/math.max(dist,1), 20, 500)
                                    w = h*0.55; x = sp.X - w/2; y = sp.Y - h/2
                                end
                                local col = (LP.Team and p.Team and p.Team == LP.Team) and Color3.fromRGB(80,200,255) or Color3.fromRGB(255,80,80)
                                d.Box.Visible = C.Box
                                if C.Box then
                                    d.Box.Size = Vector2.new(w,h)
                                    d.Box.Position = Vector2.new(x,y)
                                    d.Box.Color = col
                                end
                                d.Name.Visible = C.Name
                                d.NameBg.Visible = C.Name
                                if C.Name then
                                    d.Name.Text = p.Name
                                    d.Name.Position = Vector2.new(x+w/2, y-18)
                                    d.Name.Color = col
                                    local tw = #p.Name*7+12
                                    d.NameBg.Size = Vector2.new(tw, 18)
                                    d.NameBg.Position = Vector2.new(x+w/2-tw/2, y-19)
                                end
                                d.Dist.Visible = C.Dist
                                if C.Dist then
                                    d.Dist.Text = math.floor(dist).."m"
                                    d.Dist.Position = Vector2.new(x+w/2, y+h+2)
                                    d.Dist.Color = col
                                end
                            else hideAll(d) end
                        else hideAll(d) end
                    else hideAll(d) end
                end
            end
        else
            for _, d in pairs(ESP) do hideAll(d) end
        end
    end
end)

-- ═════ UNLOAD ═════
getgenv().UnloadMeow = function()
    if setreadonly and mt then
        pcall(function()
            setreadonly(mt, false)
            mt.__namecall = oldNC
            setreadonly(mt, true)
        end)
    end
    for _, d in pairs(ESP) do
        for _, v in pairs(d) do pcall(function() v:Remove() end) end
    end
    pcall(function() SL:Remove() end)
    pcall(function() FC:Remove() end)
    pcall(function() SG:Destroy() end)
end
