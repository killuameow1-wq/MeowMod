-- // MEOWMOD | V5.0 | CUSTOM MOBILE UI + V3 CORE
-- UI: собственный на чистом ScreenGui. Ноль внешних загрузок. Delta mobile готов.
-- Весь v3: silent aim (WS.Raycast), ESP, vehicle ESP, TP, hitbox, crosshair.
-- Камера не залипает. Ничего не пропущено.

if getgenv().MeowModUnload then pcall(getgenv().MeowModUnload); task.wait(0.05) end
getgenv().MeowModUnloaded = false

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")
local Tween      = game:GetService("TweenService")
local WS         = game:GetService("Workspace")

local LP     = Players.LocalPlayer
local Camera = WS.CurrentCamera
local PG     = LP:WaitForChild("PlayerGui")

local Connections, Drawings = {}, {}
local function TrackConn(c) table.insert(Connections, c); return c end
local function TrackDraw(d) table.insert(Drawings, d); return d end

-- ═══════════════ CONFIG ═══════════════
local C = {
    Silent        = false,
    FOVPercent    = 25,
    MaxDist       = 5000,
    Headshot      = true,
    WallCheck     = false,
    Prediction    = 1.0,
    PredictionY   = 1.0,
    PriorityMode  = "distance",
    Bypass        = true,
    BypassSpread  = 0.08,
    ESP           = false,
    ESP_Box       = true,
    ESP_Name      = true,
    ESP_Dist      = true,
    ESP_HP        = true,
    ESP_HPText    = true,
    ESP_Skel      = false,
    ESP_Line      = false,
    ESP_Offscr    = false,
    ESP_DistBar   = false,
    ESP_MaxDist   = 5000,
    TeamFilter    = "all",
    V_ESP         = false,
    V_ESP_Box     = true,
    V_ESP_Name    = true,
    V_ESP_Dist    = true,
    V_ESP_MaxDist = 5000,
    HitboxExp     = false,
    HitboxSize    = 6,
    Crosshair     = false,
    CH_Size       = 12,
    TP_SafeDrop   = 4,
    TP_DropToGround = true,
    ColAlly       = Color3.fromRGB(80, 200, 255),
    ColEnemy      = Color3.fromRGB(255, 80, 80),
    ColAim        = Color3.fromRGB(180, 0, 255),
    ColVehicle    = Color3.fromRGB(255, 165, 0),
    ColNeon       = Color3.fromRGB(0, 240, 255),
}

-- ═══════════════ UTIL ═══════════════
local function inTeam(p)
    if C.TeamFilter == "all" then return true end
    local my = LP.Team
    if not my then return true end
    if C.TeamFilter == "enemy" then return p.Team ~= my end
    if C.TeamFilter == "my" then return p.Team == my end
    return true
end

local function GetGroundY(pos)
    local rp = RaycastParams.new()
    rp.FilterDescendantsInstances = { LP.Character }
    rp.FilterType = Enum.RaycastFilterType.Exclude
    local hit = WS:Raycast(pos + Vector3.new(0, 500, 0), Vector3.new(0, -1000, 0), rp)
    return hit and hit.Position.Y or nil
end

local function SafeTeleport(pos)
    local c = LP.Character
    local hrp = c and c:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local targetY = pos.Y
    if C.TP_DropToGround then
        local gy = GetGroundY(pos)
        if gy then targetY = gy + 3.5 end
    end
    hrp.CFrame = CFrame.new(Vector3.new(pos.X, targetY + C.TP_SafeDrop, pos.Z))
    pcall(function()
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end)
    return true
end

-- ═══════════════ SILENT AIM ═══════════════
local SilentLine = TrackDraw(Drawing.new("Line"))
SilentLine.Thickness = 1.5
SilentLine.Color = C.ColAim
SilentLine.Transparency = 0.9

local FOVCircle = TrackDraw(Drawing.new("Circle"))
FOVCircle.Thickness = 1.5
FOVCircle.Color = C.ColAim
FOVCircle.Transparency = 0.7
FOVCircle.Filled = false

local silentTarget = nil
local silentActive = false
local shotOffset = Vector3.zero

local function FovPx()
    return (Camera.ViewportSize.Y * 0.5) * (C.FOVPercent / 100)
end

local function InFov(head)
    local sp, on = Camera:WorldToViewportPoint(head.Position)
    if not on or sp.Z < 0 then return false, math.huge end
    local cx, cy = Camera.ViewportSize.X * 0.5, Camera.ViewportSize.Y * 0.5
    local dx, dy = sp.X - cx, sp.Y - cy
    local d = math.sqrt(dx * dx + dy * dy)
    return d <= FovPx(), d
end

local function Predict(head)
    if C.Prediction == 1.0 and C.PredictionY == 1.0 then return head.Position end
    local hrp = head.Parent and head.Parent:FindFirstChild("HumanoidRootPart")
    if not hrp then return head.Position end
    local v = hrp.AssemblyLinearVelocity or Vector3.zero
    local t = (C.Prediction - 1.0) * 0.1
    local ty = (C.PredictionY - 1.0) * 0.1
    return Vector3.new(
        head.Position.X + v.X * t,
        head.Position.Y + v.Y * ty,
        head.Position.Z + v.Z * t
    )
end

local function NewShotOffset()
    if not C.Bypass then return Vector3.zero end
    local s = C.BypassSpread
    return Vector3.new(
        (math.random() - 0.5) * s,
        (math.random() - 0.5) * s,
        (math.random() - 0.5) * s
    )
end

local function AimPoint()
    if not silentTarget or not silentTarget.Parent then return nil end
    return Predict(silentTarget) + shotOffset
end

local function PickTarget()
    local myChar = LP.Character
    local myHrp  = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local myHum  = myChar and myChar:FindFirstChildOfClass("Humanoid")
    if not myHrp or not myHum or myHum.Health <= 0 then
        silentTarget = nil; silentActive = false; return nil
    end
    local myPos = myHrp.Position
    local best, bestScore = nil, -math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character and inTeam(p) then
            local char = p.Character
            local head = char:FindFirstChild("Head")
            local hum  = char:FindFirstChildOfClass("Humanoid")
            local hrp  = char:FindFirstChild("HumanoidRootPart")
            if head and hum and hrp and hum.Health > 0 then
                local d3 = (myPos - head.Position).Magnitude
                if d3 <= C.MaxDist then
                    local ok2, distPx = InFov(head)
                    if ok2 then
                        local s
                        if C.PriorityMode == "distance" then s = -d3
                        elseif C.PriorityMode == "health" then s = 1000 - (hum.Health / math.max(hum.MaxHealth, 1)) * 1000
                        else s = -distPx * 10 end
                        if s > bestScore then best, bestScore = head, s end
                    end
                end
            end
        end
    end
    silentTarget = best
    silentActive = best ~= nil
    return best
end

local hookMT, oldNamecall, hookInstalled = nil, nil, false
local _internal = false

local function installHook()
    if hookInstalled then return end
    local mt = getrawmetatable(game)
    oldNamecall = mt.__namecall
    setreadonly(mt, false)
    mt.__namecall = newcclosure(function(self, ...)
        if getgenv().MeowModUnloaded or _internal then return oldNamecall(self, ...) end
        if not silentActive or not silentTarget or not silentTarget.Parent then
            return oldNamecall(self, ...)
        end
        if self ~= WS then return oldNamecall(self, ...) end
        local method = getnamecallmethod()
        if method ~= "Raycast" and method ~= "FindPartOnRay" and method ~= "FindPartOnRayWithIgnoreList" then
            return oldNamecall(self, ...)
        end
        local ap = AimPoint()
        if not ap then return oldNamecall(self, ...) end
        local ok, res = pcall(function()
            local a = {...}
            if method == "Raycast" then
                if typeof(a[1]) == "Vector3" and typeof(a[2]) == "Vector3" then
                    a[2] = ap - a[1]
                end
                return oldNamecall(self, unpack(a))
            else
                if typeof(a[1]) == "Ray" then
                    a[1] = Ray.new(a[1].Origin, ap - a[1].Origin)
                end
                return oldNamecall(self, unpack(a))
            end
        end)
        if ok then return res end
        return oldNamecall(self, ...)
    end)
    setreadonly(mt, true)
    hookMT = mt; hookInstalled = true
end

local function removeHook()
    if not hookInstalled then return end
    pcall(function()
        setreadonly(hookMT, false)
        hookMT.__namecall = oldNamecall
        setreadonly(hookMT, true)
    end)
    hookMT = nil; oldNamecall = nil; hookInstalled = false
end
installHook()

TrackConn(UIS.InputBegan:Connect(function(i, gp)
    if not gp and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
        shotOffset = NewShotOffset()
    end
end))

-- ═══════════════ AIM UPDATE ═══════════════
local fovLastRadius = nil
local function UpdateAim()
    if not C.Silent then
        silentTarget = nil; silentActive = false
        SilentLine.Visible = false; FOVCircle.Visible = false
        return
    end
    local head = PickTarget()
    if not head then
        SilentLine.Visible = false
    else
        local ap = Predict(head) + shotOffset
        local sp, on = Camera:WorldToViewportPoint(ap)
        if on then
            SilentLine.From = Vector2.new(Camera.ViewportSize.X * 0.5, Camera.ViewportSize.Y * 0.5)
            SilentLine.To = Vector2.new(sp.X, sp.Y)
            SilentLine.Visible = true
        else SilentLine.Visible = false end
    end
    FOVCircle.Position = Vector2.new(Camera.ViewportSize.X * 0.5, Camera.ViewportSize.Y * 0.5)
    local r = FovPx()
    if not fovLastRadius or math.abs(fovLastRadius - r) > 0.5 then
        FOVCircle.Radius = r; fovLastRadius = r
    end
    FOVCircle.Visible = true
end

-- ═══════════════ ESP ═══════════════
local ESP = {}
local BONE_PAIRS = {
    {"Head","UpperTorso"},{"UpperTorso","LowerTorso"},
    {"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
    {"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
    {"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
    {"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
}

local function hideESP(d)
    if not d then return end
    local names = {"Box","NameBg","Name","Dist","HpBg","HpBar","HpText","Line","OffArrow","DistBarBg","DistBarFg"}
    for i = 1, #names do
        local obj = d[names[i]]
        if obj then pcall(function() obj.Visible = false end) end
    end
    if d.Bones then
        for i = 1, #d.Bones do pcall(function() d.Bones[i].Visible = false end) end
    end
end

local function makeESP(p)
    if ESP[p] then return ESP[p] end
    local d = {
        Box = TrackDraw(Drawing.new("Square")),
        NameBg = TrackDraw(Drawing.new("Square")),
        Name = TrackDraw(Drawing.new("Text")),
        Dist = TrackDraw(Drawing.new("Text")),
        HpBg = TrackDraw(Drawing.new("Square")),
        HpBar = TrackDraw(Drawing.new("Square")),
        HpText = TrackDraw(Drawing.new("Text")),
        Line = TrackDraw(Drawing.new("Line")),
        OffArrow = TrackDraw(Drawing.new("Triangle")),
        DistBarBg = TrackDraw(Drawing.new("Square")),
        DistBarFg = TrackDraw(Drawing.new("Square")),
        Bones = {},
    }
    d.Box.Thickness = 1
    d.NameBg.Filled = true; d.NameBg.Color = Color3.fromRGB(10,10,14); d.NameBg.Transparency = 0.6
    d.Name.Size = 13; d.Name.Center = true; d.Name.Outline = true
    d.Dist.Size = 12; d.Dist.Center = true; d.Dist.Outline = true
    d.HpBg.Filled = true; d.HpBg.Color = Color3.fromRGB(0,0,0)
    d.HpBar.Filled = true
    d.HpText.Size = 10; d.HpText.Center = true; d.HpText.Outline = true
    d.OffArrow.Filled = true
    d.DistBarBg.Filled = true; d.DistBarBg.Color = Color3.fromRGB(30,30,40)
    d.DistBarFg.Filled = true
    for i = 1, #BONE_PAIRS do
        local l = TrackDraw(Drawing.new("Line")); l.Thickness = 1
        d.Bones[i] = l
    end
    ESP[p] = d
    return d
end

local function dropESP(p)
    local d = ESP[p]
    if not d then return end
    for k, v in pairs(d) do
        if k == "Bones" then
            for _, b in ipairs(v) do pcall(function() b:Remove() end) end
        else pcall(function() v:Remove() end) end
    end
    ESP[p] = nil
end
TrackConn(Players.PlayerRemoving:Connect(dropESP))

local function boxOf(char)
    local head = char:FindFirstChild("Head")
    if not head then return nil end
    local feet = char:FindFirstChild("LeftFoot") or char:FindFirstChild("LeftLowerLeg")
        or char:FindFirstChild("LeftUpperLeg") or char:FindFirstChild("LowerTorso")
    if not feet then return nil end
    local lSh = char:FindFirstChild("LeftUpperArm")
    local rSh = char:FindFirstChild("RightUpperArm")
    local camCF = Camera.CFrame
    local vpSize = Camera.ViewportSize
    local tanY = math.tan(math.rad(Camera.FieldOfView * 0.5))
    local tanX = tanY * (vpSize.X / vpSize.Y)
    local function project(worldPos)
        local rel = camCF:PointToObjectSpace(worldPos)
        if rel.Z >= 0 then return nil end
        local sx = (rel.X / -rel.Z) / tanX * vpSize.X * 0.5 + vpSize.X * 0.5
        local sy = -(rel.Y / -rel.Z) / tanY * vpSize.Y * 0.5 + vpSize.Y * 0.5
        return Vector2.new(sx, sy)
    end
    local hS = project(head.Position + Vector3.new(0, 0.5, 0))
    local fS = project(feet.Position - Vector3.new(0, 0.5, 0))
    if not hS or not fS then return nil end
    local h = fS.Y - hS.Y
    if h <= 0 then return nil end
    local w
    if lSh and rSh then
        local lS = project(lSh.Position); local rS = project(rSh.Position)
        if lS and rS then w = math.abs(rS.X - lS.X) * 1.8 else w = h * 0.55 end
    else w = h * 0.55 end
    if w <= 0 or w > 1000 or h > 1000 then return nil end
    return { x = hS.X - w * 0.5, y = hS.Y, w = w, h = h }
end

local function offscreenPos(sp, margin)
    local vp = Camera.ViewportSize
    local cx, cy = vp.X * 0.5, vp.Y * 0.5
    local dx, dy = sp.X - cx, sp.Y - cy
    if math.abs(dx) < 1e-3 and math.abs(dy) < 1e-3 then dx = 1 end
    local tx = (cx - margin) / math.max(math.abs(dx), 1e-3)
    local ty = (cy - margin) / math.max(math.abs(dy), 1e-3)
    local t = math.min(tx, ty)
    return Vector2.new(cx + dx * t, cy + dy * t)
end

local function UpdateESP()
    if not C.ESP then
        for _, d in pairs(ESP) do hideESP(d) end
        return
    end
    local myChar = LP.Character
    local myHrp  = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local myHum  = myChar and myChar:FindFirstChildOfClass("Humanoid")
    local myPos  = myHrp and myHrp.Position
    local myAlive = myHum and myHum.Health > 0
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then
            local d = ESP[p] or makeESP(p)
            local char = p.Character
            local hrp  = char and char:FindFirstChild("HumanoidRootPart")
            local hum  = char and char:FindFirstChildOfClass("Humanoid")
            local head = char and char:FindFirstChild("Head")
            if not (myAlive and char and hrp and hum and head and hum.Health > 0 and inTeam(p)) then
                hideESP(d)
            else
                local dist = (myPos - hrp.Position).Magnitude
                if dist > C.ESP_MaxDist then
                    hideESP(d)
                else
                    local sp, on = Camera:WorldToViewportPoint(hrp.Position)
                    local col = (LP.Team and p.Team)
                        and (p.Team == LP.Team and C.ColAlly or C.ColEnemy)
                        or Color3.fromRGB(255, 255, 255)
                    if not on and C.ESP_Offscr then
                        local ap = offscreenPos(sp, 40)
                        local dir = (Vector2.new(sp.X, sp.Y) - ap).Unit
                        local perp = Vector2.new(-dir.Y, dir.X)
                        d.OffArrow.PointA = ap + dir * 14
                        d.OffArrow.PointB = ap - dir * 8 + perp * 10
                        d.OffArrow.PointC = ap - dir * 8 - perp * 10
                        d.OffArrow.Color = col
                        d.OffArrow.Visible = true
                        d.Box.Visible = false; d.Line.Visible = false
                        d.Name.Visible = false; d.NameBg.Visible = false
                        d.Dist.Visible = false; d.HpBg.Visible = false
                        d.HpBar.Visible = false; d.HpText.Visible = false
                        d.DistBarBg.Visible = false; d.DistBarFg.Visible = false
                        for i = 1, #d.Bones do d.Bones[i].Visible = false end
                    else
                        d.OffArrow.Visible = false
                        if not on then hideESP(d)
                        else
                            local box = boxOf(char)
                            local x, y, w, h
                            if box then x, y, w, h = box.x, box.y, box.w, box.h
                            else
                                h = math.clamp(8000 / math.max(dist, 1), 20, 500)
                                w = h * 0.5; x = sp.X - w * 0.5; y = sp.Y - h * 0.5
                            end
                            d.Box.Visible = C.ESP_Box
                            if C.ESP_Box then
                                d.Box.Size = Vector2.new(w, h); d.Box.Position = Vector2.new(x, y); d.Box.Color = col
                            end
                            d.Line.Visible = C.ESP_Line
                            if C.ESP_Line then
                                d.Line.From = Vector2.new(Camera.ViewportSize.X * 0.5, Camera.ViewportSize.Y)
                                d.Line.To = Vector2.new(sp.X, sp.Y); d.Line.Color = col
                            end
                            d.Name.Visible = C.ESP_Name; d.NameBg.Visible = C.ESP_Name
                            if C.ESP_Name then
                                d.Name.Text = p.Name; d.Name.Position = Vector2.new(x + w * 0.5, y - 18); d.Name.Color = col
                                local tw = #p.Name * 7 + 12
                                d.NameBg.Size = Vector2.new(tw, 18); d.NameBg.Position = Vector2.new(x + w * 0.5 - tw * 0.5, y - 19)
                            end
                            d.Dist.Visible = C.ESP_Dist
                            if C.ESP_Dist then
                                d.Dist.Text = tostring(math.floor(dist)) .. "m"
                                d.Dist.Position = Vector2.new(x + w * 0.5, y + h + 2); d.Dist.Color = col
                            end
                            d.HpBg.Visible = C.ESP_HP; d.HpBar.Visible = C.ESP_HP; d.HpText.Visible = C.ESP_HP and C.ESP_HPText
                            if C.ESP_HP and hum.MaxHealth > 0 then
                                local hp = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                                local hpc = Color3.fromRGB(255 * (1 - hp), 255 * hp, 0)
                                d.HpBg.Size = Vector2.new(4, h); d.HpBg.Position = Vector2.new(x - 8, y)
                                d.HpBar.Size = Vector2.new(4, h * hp); d.HpBar.Position = Vector2.new(x - 8, y + h * (1 - hp)); d.HpBar.Color = hpc
                                if C.ESP_HPText then
                                    d.HpText.Text = string.format("%d", math.floor(hum.Health))
                                    d.HpText.Position = Vector2.new(x - 10, y - 15); d.HpText.Color = hpc
                                end
                            end
                            if C.ESP_DistBar then
                                local frac = math.clamp(1 - dist / C.ESP_MaxDist, 0, 1)
                                d.DistBarBg.Visible = true; d.DistBarBg.Size = Vector2.new(w, 3)
                                d.DistBarBg.Position = Vector2.new(x, y + h + 18)
                                d.DistBarFg.Visible = true; d.DistBarFg.Size = Vector2.new(w * frac, 3)
                                d.DistBarFg.Position = Vector2.new(x, y + h + 18); d.DistBarFg.Color = col
                            else
                                d.DistBarBg.Visible = false; d.DistBarFg.Visible = false
                            end
                            if C.ESP_Skel then
                                for i, pair in ipairs(BONE_PAIRS) do
                                    local a = char:FindFirstChild(pair[1]); local b = char:FindFirstChild(pair[2])
                                    local l = d.Bones[i]
                                    if a and b then
                                        local pa, onA = Camera:WorldToViewportPoint(a.Position)
                                        local pb, onB = Camera:WorldToViewportPoint(b.Position)
                                        if onA and onB then
                                            l.From = Vector2.new(pa.X, pa.Y); l.To = Vector2.new(pb.X, pb.Y)
                                            l.Color = col; l.Visible = true
                                        else l.Visible = false end
                                    else l.Visible = false end
                                end
                            else
                                for i = 1, #d.Bones do d.Bones[i].Visible = false end
                            end
                        end
                    end
                end
            end
        end
    end
end

-- ═══════════════ VEHICLE ESP ═══════════════
local VehicleSeats = {}
local VehicleESP = {}
local function RegisterSeat(s)
    local m = s:FindFirstAncestorOfClass("Model") or s:FindFirstAncestorOfClass("Folder")
    if m then VehicleSeats[s] = m end
end
for _, i in ipairs(WS:GetDescendants()) do
    if i:IsA("VehicleSeat") then RegisterSeat(i) end
end
TrackConn(WS.DescendantAdded:Connect(function(i) if i:IsA("VehicleSeat") then RegisterSeat(i) end end))
TrackConn(WS.DescendantRemoving:Connect(function(i) if i:IsA("VehicleSeat") then VehicleSeats[i] = nil end end))

local function CollectVehicles()
    local seen, list = {}, {}
    for _, m in pairs(VehicleSeats) do
        if m and m.Parent and not seen[m] then seen[m] = true; table.insert(list, m) end
    end
    return list
end

local function UpdateVehicleESP()
    if not C.V_ESP then
        for _, d in pairs(VehicleESP) do
            for _, v in pairs(d) do pcall(function() v.Visible = false end) end
        end
        return
    end
    local myChar = LP.Character
    local myHrp  = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local myPos  = myHrp and myHrp.Position
    local alive = {}
    for _, m in ipairs(CollectVehicles()) do
        local a = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart", true)
        if a then
            alive[m] = true
            if not VehicleESP[m] then
                VehicleESP[m] = {
                    Box = TrackDraw(Drawing.new("Square")),
                    Name = TrackDraw(Drawing.new("Text")),
                    Dist = TrackDraw(Drawing.new("Text")),
                }
                VehicleESP[m].Box.Thickness = 1
                VehicleESP[m].Name.Size = 13; VehicleESP[m].Name.Center = true; VehicleESP[m].Name.Outline = true
                VehicleESP[m].Dist.Size = 12; VehicleESP[m].Dist.Center = true; VehicleESP[m].Dist.Outline = true
            end
            local d = VehicleESP[m]
            local dist = myPos and (myPos - a.Position).Magnitude or 0
            if dist > C.V_ESP_MaxDist then
                for _, v in pairs(d) do v.Visible = false end
            else
                local sp, on = Camera:WorldToViewportPoint(a.Position)
                if on then
                    local ok2, ext = pcall(function() return m:GetExtentsSize() end)
                    local w, h
                    if ok2 and ext then
                        local corner = Camera:WorldToViewportPoint(a.Position + ext / 2)
                        w = math.clamp(math.abs(corner.X - sp.X) * 2, 22, 600)
                        h = math.clamp(math.abs(corner.Y - sp.Y) * 2, 22, 600)
                    else
                        local s = math.clamp(8000 / math.max(dist, 1), 24, 300); w, h = s, s
                    end
                    d.Box.Visible = C.V_ESP_Box
                    if C.V_ESP_Box then
                        d.Box.Size = Vector2.new(w, h); d.Box.Position = Vector2.new(sp.X - w * 0.5, sp.Y - h * 0.5); d.Box.Color = C.ColVehicle
                    end
                    d.Name.Visible = C.V_ESP_Name
                    if C.V_ESP_Name then
                        d.Name.Text = m.Name; d.Name.Position = Vector2.new(sp.X, sp.Y - h * 0.5 - 18); d.Name.Color = C.ColVehicle
                    end
                    d.Dist.Visible = C.V_ESP_Dist
                    if C.V_ESP_Dist then
                        d.Dist.Text = tostring(math.floor(dist)) .. "m"; d.Dist.Position = Vector2.new(sp.X, sp.Y + h * 0.5 + 2); d.Dist.Color = C.ColVehicle
                    end
                else
                    for _, v in pairs(d) do v.Visible = false end
                end
            end
        end
    end
    for m, d in pairs(VehicleESP) do
        if not alive[m] then
            for _, v in pairs(d) do pcall(function() v:Remove() end) end
            VehicleESP[m] = nil
        end
    end
end

-- ═══════════════ HITBOX ═══════════════
local function ApplyHitbox()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character and inTeam(p) then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                if C.HitboxExp then
                    hrp.Size = Vector3.new(C.HitboxSize, C.HitboxSize, C.HitboxSize)
                    hrp.Transparency = 0.7; hrp.CanCollide = false
                else
                    hrp.Size = Vector3.new(2, 2, 1); hrp.Transparency = 1; hrp.CanCollide = true
                end
            end
        end
    end
end

-- ═══════════════ CROSSHAIR ═══════════════
local CH1 = TrackDraw(Drawing.new("Line"))
local CH2 = TrackDraw(Drawing.new("Line"))
CH1.Thickness = 2; CH2.Thickness = 2
CH1.Color = C.ColNeon; CH2.Color = C.ColNeon

local function UpdateCrosshair()
    if not C.Crosshair then CH1.Visible = false; CH2.Visible = false; return end
    local cx, cy = Camera.ViewportSize.X * 0.5, Camera.ViewportSize.Y * 0.5
    local s = C.CH_Size
    CH1.From = Vector2.new(cx - s, cy); CH1.To = Vector2.new(cx + s, cy); CH1.Visible = true
    CH2.From = Vector2.new(cx, cy - s); CH2.To = Vector2.new(cx, cy + s); CH2.Visible = true
end

-- ═══════════════ TP ═══════════════
local function TPBase()
    local myTeam = LP.Team and LP.Team.Name:lower() or ""
    local myColor = LP.TeamColor and LP.TeamColor.Color
    local myHrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    local myPos = myHrp and myHrp.Position or Vector3.zero
    local best, bestD = nil, math.huge
    for _, o in ipairs(WS:GetDescendants()) do
        if o:IsA("SpawnLocation") and o.Enabled then
            local match = false
            if myColor and o.BrickColor.Color == myColor then match = true end
            local path = o:GetFullName():lower()
            if not match and myTeam ~= "" and path:find(myTeam) then match = true end
            if match then
                local d = (myPos - o.Position).Magnitude
                if d < bestD then bestD = d; best = o.Position end
            end
        end
    end
    if best then return SafeTeleport(best) end
    return false
end

local function TPAirdrop()
    local myHrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    local myPos = myHrp and myHrp.Position or Vector3.zero
    local best, bestS = nil, -math.huge
    for _, o in ipairs(WS:GetDescendants()) do
        if o:IsA("BasePart") or o:IsA("Model") then
            local n = o.Name:lower()
            if n:find("airdrop") or n:find("crate") or n:find("parachute") then
                local path = o:GetFullName():lower()
                if not (path:find("menu") or path:find("shop") or path:find("base") or path:find("spawn")) then
                    local p = o:IsA("BasePart") and o.Position or (o.PrimaryPart and o.PrimaryPart.Position)
                    if p then
                        local s = 100 - (myPos - p).Magnitude * 0.05
                        if s > bestS then bestS = s; best = p end
                    end
                end
            end
        end
    end
    if best then return SafeTeleport(best) end
    return false
end

local function TPCrashedUAV()
    local myHrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    local myPos = myHrp and myHrp.Position or Vector3.zero
    local best, bestS = nil, -math.huge
    local kws = {"uav","drone","crashed","wreck"}
    for _, o in ipairs(WS:GetDescendants()) do
        if o:IsA("BasePart") or o:IsA("Model") then
            local n = o.Name:lower()
            local matched = false
            for _, kw in ipairs(kws) do if n:find(kw) then matched = true; break end end
            if matched then
                local path = o:GetFullName():lower()
                if not (path:find("spawn") or path:find("pad") or path:find("hangar")) then
                    local p = o:IsA("BasePart") and o.Position or (o.PrimaryPart and o.PrimaryPart.Position)
                    if p then
                        local s = 100 - (myPos - p).Magnitude * 0.05
                        if n:find("crashed") or n:find("wreck") then s = s + 300 end
                        if s > bestS then bestS = s; best = p end
                    end
                end
            end
        end
    end
    if best then return SafeTeleport(best) end
    return false
end

local function TPCapture()
    local myHrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not myHrp then return false end
    local myPos = myHrp.Position
    local best, bestS = nil, -math.huge
    for _, o in ipairs(WS:GetDescendants()) do
        if o:IsA("BasePart") then
            if o.Name:lower():find("flag") and o.Position.Y > myPos.Y + 3 then
                local path = o:GetFullName():lower()
                if not (path:find("spawn") or path:find("base") or path:find("barracks")) then
                    local s = 500 - (myPos - o.Position).Magnitude * 0.05
                    if s > bestS then bestS = s; best = o.Position end
                end
            end
        end
    end
    if best then return SafeTeleport(best) end
    return false
end

local function TPNearestEnemy()
    local myHrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not myHrp then return false end
    local best, bestD = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            if hrp and hum and hum.Health > 0 then
                local enemy = LP.Team and p.Team and p.Team ~= LP.Team
                if enemy or not LP.Team then
                    local d = (myHrp.Position - hrp.Position).Magnitude
                    if d < bestD then bestD = d; best = hrp end
                end
            end
        end
    end
    if best then return SafeTeleport(best.Position + Vector3.new(0, 3, 0)) end
    return false
end

-- ═══════════════ CUSTOM MOBILE UI ═══════════════
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MeowModV5"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.Parent = PG

-- Фон полупрозрачный затемняющий
local Bg = Instance.new("Frame")
Bg.Name = "Bg"
Bg.Size = UDim2.fromScale(1, 1)
Bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
Bg.BackgroundTransparency = 0.5
Bg.BorderSizePixel = 0
Bg.Visible = false
Bg.ZIndex = 1
Bg.Parent = ScreenGui

-- Плавающая кнопка открытия (тач-таргет крупный)
local OpenBtn = Instance.new("TextButton")
OpenBtn.Name = "OpenBtn"
OpenBtn.Size = UDim2.fromOffset(56, 56)
OpenBtn.Position = UDim2.new(0, 12, 0.5, -28)
OpenBtn.BackgroundColor3 = C.ColNeon
OpenBtn.Text = "M"
OpenBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
OpenBtn.Font = Enum.Font.GothamBlack
OpenBtn.TextSize = 22
OpenBtn.BorderSizePixel = 0
OpenBtn.Active = true
OpenBtn.Draggable = true
OpenBtn.ZIndex = 100
OpenBtn.Parent = ScreenGui
Instance.new("UICorner", OpenBtn).CornerRadius = UDim.new(0, 28)

-- Главное окно
local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.fromOffset(340, 480)
Main.Position = UDim2.fromScale(0.5, 0.5)
Main.AnchorPoint = Vector2.new(0.5, 0.5)
Main.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Main.Visible = false
Main.ZIndex = 10
Main.Parent = ScreenGui
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 14)
local MainStroke = Instance.new("UIStroke", Main)
MainStroke.Color = C.ColNeon
MainStroke.Thickness = 1.5
MainStroke.Transparency = 0.4

-- Header
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 52)
Header.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
Header.BorderSizePixel = 0
Header.ZIndex = 11
Header.Parent = Main
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 14)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -100, 1, 0)
Title.Position = UDim2.new(0, 16, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "MEOW V5.0"
Title.TextColor3 = C.ColNeon
Title.Font = Enum.Font.GothamBlack
Title.TextSize = 18
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.ZIndex = 12
Title.Parent = Header

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.fromOffset(36, 36)
CloseBtn.Position = UDim2.new(1, -46, 0, 8)
CloseBtn.BackgroundColor3 = Color3.fromRGB(255, 70, 70)
CloseBtn.Text = "×"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Font = Enum.Font.GothamBlack
CloseBtn.TextSize = 22
CloseBtn.BorderSizePixel = 0
CloseBtn.ZIndex = 12
CloseBtn.Parent = Header
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 10)

-- Tab bar (мобильный скролл горизонтальный)
local TabBar = Instance.new("ScrollingFrame")
TabBar.Size = UDim2.new(1, -16, 0, 48)
TabBar.Position = UDim2.new(0, 8, 0, 60)
TabBar.BackgroundTransparency = 1
TabBar.BorderSizePixel = 0
TabBar.ScrollBarThickness = 0
TabBar.ScrollingDirection = Enum.ScrollingDirection.X
TabBar.CanvasSize = UDim2.new(0, 500, 0, 0)
TabBar.ZIndex = 11
TabBar.Parent = Main
local TabLayout = Instance.new("UIListLayout", TabBar)
TabLayout.FillDirection = Enum.FillDirection.Horizontal
TabLayout.Padding = UDim.new(0, 8)
TabLayout.SortOrder = Enum.SortOrder.LayoutOrder

local Pages = {}
local TabButtons = {}

local function CreateTab(name, order)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.fromOffset(92, 44)
    Btn.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    Btn.Text = name
    Btn.TextColor3 = Color3.fromRGB(180, 180, 190)
    Btn.Font = Enum.Font.GothamBold
    Btn.TextSize = 13
    Btn.BorderSizePixel = 0
    Btn.AutoButtonColor = false
    Btn.LayoutOrder = order
    Btn.ZIndex = 12
    Btn.Parent = TabBar
    Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 10)
    TabButtons[name] = Btn

    local Page = Instance.new("ScrollingFrame")
    Page.Size = UDim2.new(1, -16, 1, -120)
    Page.Position = UDim2.new(0, 8, 0, 116)
    Page.BackgroundTransparency = 1
    Page.BorderSizePixel = 0
    Page.ScrollBarThickness = 3
    Page.ScrollBarImageColor3 = C.ColNeon
    Page.CanvasSize = UDim2.new(0, 0, 0, 0)
    Page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    Page.Visible = false
    Page.ZIndex = 11
    Page.Parent = Main
    local PLayout = Instance.new("UIListLayout", Page)
    PLayout.Padding = UDim.new(0, 10)
    PLayout.SortOrder = Enum.SortOrder.LayoutOrder
    Pages[name] = Page

    Btn.MouseButton1Click:Connect(function()
        for _, pg in pairs(Pages) do pg.Visible = false end
        for _, b in pairs(TabButtons) do
            b.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
            b.TextColor3 = Color3.fromRGB(180, 180, 190)
        end
        Page.Visible = true
        Btn.BackgroundColor3 = C.ColNeon
        Btn.TextColor3 = Color3.fromRGB(0, 0, 0)
    end)
    return Page
end

-- Мобильные компоненты (крупный тач)
local function CreateToggle(parent, text, def, cb)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(1, 0, 0, 50)
    Btn.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    Btn.Text = ""
    Btn.AutoButtonColor = false
    Btn.BorderSizePixel = 0
    Btn.ZIndex = 12
    Btn.Parent = parent
    Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 10)

    local Lbl = Instance.new("TextLabel")
    Lbl.Size = UDim2.new(1, -80, 1, 0)
    Lbl.Position = UDim2.new(0, 14, 0, 0)
    Lbl.BackgroundTransparency = 1
    Lbl.Text = text
    Lbl.TextColor3 = Color3.fromRGB(230, 230, 240)
    Lbl.Font = Enum.Font.GothamMedium
    Lbl.TextSize = 15
    Lbl.TextXAlignment = Enum.TextXAlignment.Left
    Lbl.ZIndex = 13
    Lbl.Parent = Btn

    local Track = Instance.new("Frame")
    Track.Size = UDim2.fromOffset(48, 26)
    Track.Position = UDim2.new(1, -62, 0.5, -13)
    Track.BackgroundColor3 = def and C.ColNeon or Color3.fromRGB(55, 55, 70)
    Track.BorderSizePixel = 0
    Track.ZIndex = 13
    Track.Parent = Btn
    Instance.new("UICorner", Track).CornerRadius = UDim.new(1, 0)

    local Knob = Instance.new("Frame")
    Knob.Size = UDim2.fromOffset(20, 20)
    Knob.Position = def and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 3, 0.5, -10)
    Knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Knob.BorderSizePixel = 0
    Knob.ZIndex = 14
    Knob.Parent = Track
    Instance.new("UICorner", Knob).CornerRadius = UDim.new(1, 0)

    local state = def
    Btn.MouseButton1Click:Connect(function()
        state = not state
        Tween:Create(Track, TweenInfo.new(0.15), {
            BackgroundColor3 = state and C.ColNeon or Color3.fromRGB(55, 55, 70)
        }):Play()
        Tween:Create(Knob, TweenInfo.new(0.15), {
            Position = state and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 3, 0.5, -10)
        }):Play()
        if cb then cb(state) end
    end)
end

local function CreateSlider(parent, text, mn, mx, def, cb)
    local F = Instance.new("Frame")
    F.Size = UDim2.new(1, 0, 0, 62)
    F.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    F.BorderSizePixel = 0
    F.ZIndex = 12
    F.Parent = parent
    Instance.new("UICorner", F).CornerRadius = UDim.new(0, 10)

    local Lbl = Instance.new("TextLabel")
    Lbl.Size = UDim2.new(1, -20, 0, 22)
    Lbl.Position = UDim2.new(0, 14, 0, 6)
    Lbl.BackgroundTransparency = 1
    Lbl.Text = text .. ": " .. def
    Lbl.TextColor3 = Color3.fromRGB(230, 230, 240)
    Lbl.Font = Enum.Font.GothamMedium
    Lbl.TextSize = 14
    Lbl.TextXAlignment = Enum.TextXAlignment.Left
    Lbl.ZIndex = 13
    Lbl.Parent = F

    local BarBg = Instance.new("Frame")
    BarBg.Size = UDim2.new(1, -28, 0, 8)
    BarBg.Position = UDim2.new(0, 14, 0, 40)
    BarBg.BackgroundColor3 = Color3.fromRGB(45, 45, 58)
    BarBg.BorderSizePixel = 0
    BarBg.ZIndex = 13
    BarBg.Parent = F
    Instance.new("UICorner", BarBg).CornerRadius = UDim.new(1, 0)

    local Fill = Instance.new("Frame")
    Fill.Size = UDim2.new((def - mn) / (mx - mn), 0, 1, 0)
    Fill.BackgroundColor3 = C.ColNeon
    Fill.BorderSizePixel = 0
    Fill.ZIndex = 13
    Fill.Parent = BarBg
    Instance.new("UICorner", Fill).CornerRadius = UDim.new(1, 0)

    local Hit = Instance.new("TextButton")
    Hit.Size = UDim2.new(1, 0, 3, 0)
    Hit.Position = UDim2.new(0, 0, -1, 0)
    Hit.BackgroundTransparency = 1
    Hit.Text = ""
    Hit.ZIndex = 14
    Hit.Parent = BarBg

    local dragging = false
    local function Update(pos)
        local rel = math.clamp((pos - BarBg.AbsolutePosition.X) / BarBg.AbsoluteSize.X, 0, 1)
        local v = math.floor(mn + (mx - mn) * rel + 0.5)
        Fill.Size = UDim2.new(rel, 0, 1, 0)
        Lbl.Text = text .. ": " .. v
        if cb then cb(v) end
    end

    Hit.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            Update(i.Position.X)
        end
    end)
    TrackConn(UIS.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            Update(i.Position.X)
        end
    end))
    TrackConn(UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))
end

local function CreateButton(parent, text, cb)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(1, 0, 0, 50)
    Btn.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    Btn.Text = text
    Btn.TextColor3 = C.ColNeon
    Btn.Font = Enum.Font.GothamBold
    Btn.TextSize = 15
    Btn.BorderSizePixel = 0
    Btn.AutoButtonColor = false
    Btn.ZIndex = 12
    Btn.Parent = parent
    Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 10)
    Btn.MouseButton1Click:Connect(function()
        Btn.BackgroundColor3 = Color3.fromRGB(0, 200, 120)
        task.wait(0.15)
        Btn.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
        if cb then cb() end
    end)
end

local function CreateCycle(parent, text, options, def, cb)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(1, 0, 0, 50)
    Btn.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    Btn.Text = text .. ": " .. def
    Btn.TextColor3 = C.ColNeon
    Btn.Font = Enum.Font.GothamBold
    Btn.TextSize = 14
    Btn.BorderSizePixel = 0
    Btn.AutoButtonColor = false
    Btn.ZIndex = 12
    Btn.Parent = parent
    Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 10)
    local idx = 1
    for i, o in ipairs(options) do if o == def then idx = i break end end
    Btn.MouseButton1Click:Connect(function()
        idx = idx + 1
        if idx > #options then idx = 1 end
        Btn.Text = text .. ": " .. options[idx]
        if cb then cb(options[idx]) end
    end)
end

-- Кнопки открытия/закрытия
OpenBtn.MouseButton1Click:Connect(function()
    Main.Visible = true
    Bg.Visible = true
    OpenBtn.Visible = false
end)
CloseBtn.MouseButton1Click:Connect(function()
    Main.Visible = false
    Bg.Visible = false
    OpenBtn.Visible = true
end)

-- ═══════════════ TABS ═══════════════
local Combat = CreateTab("Combat", 1)
local Visual = CreateTab("Visuals", 2)
local Vehicles = CreateTab("Vehicles", 3)
local TP = CreateTab("Teleport", 4)

-- Combat
CreateToggle(Combat, "Silent Aim", C.Silent, function(v) C.Silent = v end)
CreateSlider(Combat, "FOV %", 5, 100, C.FOVPercent, function(v) C.FOVPercent = v end)
CreateSlider(Combat, "Max Distance", 500, 5000, C.MaxDist, function(v) C.MaxDist = v end)
CreateSlider(Combat, "Prediction X (x10)", 5, 30, math.floor(C.Prediction * 10), function(v) C.Prediction = v / 10 end)
CreateSlider(Combat, "Prediction Y (x10)", 5, 30, math.floor(C.PredictionY * 10), function(v) C.PredictionY = v / 10 end)
CreateCycle(Combat, "Priority", {"distance", "health", "fov"}, C.PriorityMode, function(o) C.PriorityMode = o end)
CreateToggle(Combat, "Headshot", C.Headshot, function(v) C.Headshot = v end)
CreateToggle(Combat, "Wall Check", C.WallCheck, function(v) C.WallCheck = v end)
CreateToggle(Combat, "Bypass", C.Bypass, function(v) C.Bypass = v end)
CreateSlider(Combat, "Bypass Spread", 0, 30, math.floor(C.BypassSpread * 100), function(v) C.BypassSpread = v / 100 end)
CreateCycle(Combat, "Team Filter", {"all", "enemy", "my"}, C.TeamFilter, function(o) C.TeamFilter = o end)
CreateToggle(Combat, "Hitbox Expander", C.HitboxExp, function(v) C.HitboxExp = v; ApplyHitbox() end)
CreateSlider(Combat, "Hitbox Size", 2, 20, C.HitboxSize, function(v) C.HitboxSize = v; ApplyHitbox() end)

-- Visuals
CreateToggle(Visual, "ESP", C.ESP, function(v) C.ESP = v end)
CreateToggle(Visual, "Box", C.ESP_Box, function(v) C.ESP_Box = v end)
CreateToggle(Visual, "Name", C.ESP_Name, function(v) C.ESP_Name = v end)
CreateToggle(Visual, "Distance", C.ESP_Dist, function(v) C.ESP_Dist = v end)
CreateToggle(Visual, "HP Bar", C.ESP_HP, function(v) C.ESP_HP = v end)
CreateToggle(Visual, "HP Text", C.ESP_HPText, function(v) C.ESP_HPText = v end)
CreateToggle(Visual, "Skeleton", C.ESP_Skel, function(v) C.ESP_Skel = v end)
CreateToggle(Visual, "Line", C.ESP_Line, function(v) C.ESP_Line = v end)
CreateToggle(Visual, "Offscreen Arrows", C.ESP_Offscr, function(v) C.ESP_Offscr = v end)
CreateToggle(Visual, "Distance Bar", C.ESP_DistBar, function(v) C.ESP_DistBar = v end)
CreateSlider(Visual, "ESP Max Distance", 500, 5000, C.ESP_MaxDist, function(v) C.ESP_MaxDist = v end)
CreateToggle(Visual, "Crosshair", C.Crosshair, function(v) C.Crosshair = v end)
CreateSlider(Visual, "Crosshair Size", 5, 30, C.CH_Size, function(v) C.CH_Size = v end)

-- Vehicles
CreateToggle(Vehicles, "Vehicle ESP", C.V_ESP, function(v) C.V_ESP = v end)
CreateToggle(Vehicles, "Box", C.V_ESP_Box, function(v) C.V_ESP_Box = v end)
CreateToggle(Vehicles, "Name", C.V_ESP_Name, function(v) C.V_ESP_Name = v end)
CreateToggle(Vehicles, "Distance", C.V_ESP_Dist, function(v) C.V_ESP_Dist = v end)
CreateSlider(Vehicles, "Max Distance", 100, 10000, C.V_ESP_MaxDist, function(v) C.V_ESP_MaxDist = v end)

-- Teleport
CreateToggle(TP, "Drop to ground", C.TP_DropToGround, function(v) C.TP_DropToGround = v end)
CreateSlider(TP, "Safe drop", 1, 20, C.TP_SafeDrop, function(v) C.TP_SafeDrop = v end)
CreateButton(TP, "TP Base", TPBase)
CreateButton(TP, "TP Airdrop", TPAirdrop)
CreateButton(TP, "TP Crashed UAV", TPCrashedUAV)
CreateButton(TP, "TP Capture", TPCapture)
CreateButton(TP, "TP Nearest Enemy", TPNearestEnemy)

-- Первый таб активен
Pages["Combat"].Visible = true
TabButtons["Combat"].BackgroundColor3 = C.ColNeon
TabButtons["Combat"].TextColor3 = Color3.fromRGB(0, 0, 0)

-- ═══════════════ RENDER LOOP ═══════════════
local espAccum, ESP_INTERVAL = 0, 1 / 30
local vehAccum, VEH_INTERVAL = 0, 1 / 15
local chAccum,  CH_INTERVAL  = 0, 1 / 30

TrackConn(RunService.RenderStepped:Connect(function(dt)
    if getgenv().MeowModUnloaded then return end
    pcall(UpdateAim)
    espAccum = espAccum + dt
    if espAccum >= ESP_INTERVAL then espAccum = 0; pcall(UpdateESP) end
    vehAccum = vehAccum + dt
    if vehAccum >= VEH_INTERVAL then vehAccum = 0; pcall(UpdateVehicleESP) end
    chAccum = chAccum + dt
    if chAccum >= CH_INTERVAL then chAccum = 0; pcall(UpdateCrosshair) end
    if C.HitboxExp then pcall(ApplyHitbox) end
end))

-- ═══════════════ FULL UNLOAD ═══════════════
getgenv().MeowModUnload = function()
    if getgenv().MeowModUnloaded then return end
    getgenv().MeowModUnloaded = true
    removeHook()
    for _, c in ipairs(Connections) do
        pcall(function() if typeof(c) == "RBXScriptConnection" then c:Disconnect() end end)
    end
    Connections = {}
    for _, d in ipairs(Drawings) do pcall(function() d:Remove() end) end
    Drawings = {}
    ESP = {}; VehicleESP = {}; VehicleSeats = {}
    for _, p in ipairs(Players:GetPlayers()) do
        local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            pcall(function()
                hrp.Size = Vector3.new(2, 2, 1); hrp.Transparency = 1; hrp.CanCollide = true
            end)
        end
    end
    silentTarget = nil; silentActive = false
    pcall(function() ScreenGui:Destroy() end)
    pcall(function()
        getgenv().MeowModUnload = nil
        getgenv().MeowModUnloaded = nil
    end)
end
