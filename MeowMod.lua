-- // MEOWMOD | V4.6 | NO-CRASH SILENT (ViewportPointToRay only)
-- Убран Workspace:Raycast хук — сервер реджектил и кикал.
-- Оставлен только Camera:ViewportPointToRay / ScreenPointToRay — реальный путь
-- клиентского прицела. Всё в pcall. Reset isShooting на respawn.
-- При вылете игры старый unload вызывается через getgenv() — но при hard-kick
-- глобалы теряются, поэтому запуск скрипта чист.

if getgenv().MeowModUnload then pcall(getgenv().MeowModUnload); task.wait(0.05) end
getgenv().MeowModUnloaded = false

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")
local WS         = game:GetService("Workspace")

local LP     = Players.LocalPlayer
local Camera = WS.CurrentCamera

-- ═══════════════ РЕЕСТРЫ ═══════════════
local Connections, Drawings = {}, {}
local function TrackConn(c) table.insert(Connections, c); return c end
local function TrackDraw(d) table.insert(Drawings, d); return d end

-- ═══════════════ RAYFIELD ═══════════════
local Rayfield
do
    local ok, res = pcall(function()
        return loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
    end)
    if not ok or not res then return warn("[MeowMod] Rayfield load failed") end
    Rayfield = res
end

local Window = Rayfield:CreateWindow({
    Name = "MeowMod V4.6",
    LoadingTitle = "MeowMod",
    LoadingSubtitle = "no-crash",
    ConfigurationSaving = { Enabled = true, FolderName = "MeowMod", FileName = "v4_6" },
    KeySystem = false,
})

-- ═══════════════ CONFIG ═══════════════
local C = {
    Silent        = false,
    FOVPercent    = 25,
    MaxDist       = 5000,
    Headshot      = true,
    WallCheck     = false,
    Prediction    = 1.0,
    PredictionY   = 1.0,
    Smoothing     = 0,
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
    Hitmarker     = true,
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

-- ═══════════════ SILENT AIM STATE ═══════════════
local SilentLine = TrackDraw(Drawing.new("Line"))
SilentLine.Thickness = 1.5
SilentLine.Color = C.ColAim
SilentLine.Transparency = 0.9

local FOVCircle = TrackDraw(Drawing.new("Circle"))
FOVCircle.Thickness = 1.5
FOVCircle.Color = C.ColAim
FOVCircle.Transparency = 0.7
FOVCircle.Filled = false

local isShooting = false
local silentTarget = nil
local aimSmoothPos = nil
local lastSwitch = 0
local SWITCH_CD = 0.2
local shotOffset = Vector3.zero
local _internalRaycast = false

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

local function Visible(head)
    _internalRaycast = true
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances = { LP.Character, head.Parent }
    local hit = WS:Raycast(Camera.CFrame.Position, head.Position - Camera.CFrame.Position, rp)
    _internalRaycast = false
    return hit == nil
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

local function CurrentAimPoint()
    if not silentTarget or not silentTarget.Parent then return nil end
    local head = silentTarget:FindFirstChild("Head")
    if not head then return nil end
    return (aimSmoothPos or Predict(head)) + shotOffset
end

local function ScoreTarget(p, head, hum, hrp, d3, distPx, vis)
    local score
    if C.PriorityMode == "distance" then score = -d3
    elseif C.PriorityMode == "health" then score = 1000 - (hum.Health / math.max(hum.MaxHealth, 1)) * 1000
    elseif C.PriorityMode == "threat" then
        local look = hrp.CFrame.LookVector
        local toMe = (LP.Character.HumanoidRootPart.Position - hrp.Position).Unit
        local dot = look:Dot(toMe)
        score = dot * 500 + (dot > 0.3 and 500 or 0) - d3 * 0.5
    elseif C.PriorityMode == "fov" then score = -distPx * 10
    else score = -d3 end
    if vis then score = score + 100 else score = score - 50 end
    if p == silentTarget and tick() - lastSwitch < SWITCH_CD then score = score + 300 end
    return score
end

local function targetValid()
    if not silentTarget or not silentTarget.Parent then return false end
    local head = silentTarget:FindFirstChild("Head")
    local hum  = silentTarget:FindFirstChildOfClass("Humanoid")
    local hrp  = silentTarget:FindFirstChild("HumanoidRootPart")
    if not (head and hum and hrp and hum.Health > 0) then return false end
    local p = Players:GetPlayerFromCharacter(silentTarget)
    if not p or not inTeam(p) then return false end
    local myHrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not myHrp then return false end
    if (myHrp.Position - head.Position).Magnitude > C.MaxDist then return false end
    return InFov(head)
end

local pickCache = { head = nil, t = 0 }
local PICK_INTERVAL = 0.05

local function PickTarget()
    local now = tick()
    if now - pickCache.t < PICK_INTERVAL and pickCache.head and pickCache.head.Parent then
        return pickCache.head
    end
    pickCache.t = now
    if targetValid() then
        local head = silentTarget:FindFirstChild("Head")
        pickCache.head = head
        return head
    end
    local myChar = LP.Character
    local myHrp  = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local myHum  = myChar and myChar:FindFirstChildOfClass("Humanoid")
    if not myHrp or not myHum or myHum.Health <= 0 then
        pickCache.head = nil; silentTarget = nil; return nil
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
                        local vis = (not C.WallCheck) or Visible(head)
                        local s = ScoreTarget(p, head, hum, hrp, d3, distPx, vis)
                        if s > bestScore then best, bestScore = head, s end
                    end
                end
            end
        end
    end
    if best then
        if best.Parent ~= silentTarget then lastSwitch = tick() end
        silentTarget = best.Parent
    else
        silentTarget = nil
    end
    pickCache.head = best
    return best
end

-- ═══════════════ ХУК: только Camera:ViewportPointToRay / ScreenPointToRay ═══════════════
local hookMT, oldNamecall, hookInstalled = nil, nil, false

local function installNamecallHook()
    if hookInstalled then return end
    local mt = getrawmetatable(game)
    oldNamecall = mt.__namecall
    setreadonly(mt, false)
    mt.__namecall = newcclosure(function(self, ...)
        -- Никогда не трогаем ничего вне Camera + isShooting + живая цель
        local ok, result = pcall(function()
            if getgenv().MeowModUnloaded or _internalRaycast then return false end
            if not isShooting or not silentTarget or not silentTarget.Parent then return false end
            if self ~= Camera then return false end
            local method = getnamecallmethod()
            if method ~= "ViewportPointToRay" and method ~= "ScreenPointToRay" then return false end
            local aimPoint = CurrentAimPoint()
            if not aimPoint then return false end
            local camPos = Camera.CFrame.Position
            local dir = aimPoint - camPos
            if dir.Magnitude < 0.001 then return false end
            return Ray.new(camPos, dir.Unit * dir.Magnitude)
        end)
        if ok and result then return result end
        return oldNamecall(self, ...)
    end)
    setreadonly(mt, true)
    hookMT = mt
    hookInstalled = true
end

local function removeNamecallHook()
    if not hookInstalled then return end
    pcall(function()
        setreadonly(hookMT, false)
        hookMT.__namecall = oldNamecall
        setreadonly(hookMT, true)
    end)
    hookMT = nil; oldNamecall = nil; hookInstalled = false
end
installNamecallHook()

-- ═══════════════ INPUT ═══════════════
TrackConn(UIS.InputBegan:Connect(function(i, gp)
    if not gp and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
        isShooting = true
        shotOffset = NewShotOffset()
        pickCache.t = 0
    end
end))
TrackConn(UIS.InputEnded:Connect(function(i, gp)
    if not gp and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
        isShooting = false
    end
end))

-- Reset на респавн/смерть — иначе зависает isShooting
local function resetCombatState()
    isShooting = false
    silentTarget = nil
    aimSmoothPos = nil
    pickCache.head = nil
    pickCache.t = 0
end
TrackConn(LP.CharacterAdded:Connect(resetCombatState))
TrackConn(LP.CharacterRemoving:Connect(resetCombatState))
if LP.Character then
    local hum = LP.Character:FindFirstChildOfClass("Humanoid")
    if hum then
        TrackConn(hum.Died:Connect(resetCombatState))
    end
end

-- ═══════════════ AIM UPDATE ═══════════════
local fovLastRadius = nil
local function UpdateAim(dt)
    if not C.Silent or not isShooting then
        silentTarget = nil; aimSmoothPos = nil
        SilentLine.Visible = false; FOVCircle.Visible = false
        return
    end
    local head = PickTarget()
    if not head then
        aimSmoothPos = nil
        SilentLine.Visible = false
    else
        local raw = Predict(head) + shotOffset
        if C.Smoothing > 0 then
            local f = math.clamp(1 - C.Smoothing * dt * 10, 0, 1)
            aimSmoothPos = aimSmoothPos and aimSmoothPos:Lerp(raw, f) or raw
        else
            aimSmoothPos = raw
        end
        local sp, on = Camera:WorldToViewportPoint(aimSmoothPos)
        if on then
            SilentLine.From = Vector2.new(Camera.ViewportSize.X * 0.5, Camera.ViewportSize.Y * 0.5)
            SilentLine.To = Vector2.new(sp.X, sp.Y)
            SilentLine.Visible = true
        else SilentLine.Visible = false end
    end
    FOVCircle.Position = Vector2.new(Camera.ViewportSize.X * 0.5, Camera.ViewportSize.Y * 0.5)
    local r = FovPx()
    if not fovLastRadius or math.abs(fovLastRadius - r) > 0.5 then
        FOVCircle.Radius = r
        fovLastRadius = r
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
        else
            pcall(function() v:Remove() end)
        end
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
        local lS = project(lSh.Position)
        local rS = project(rSh.Position)
        if lS and rS then
            w = math.abs(rS.X - lS.X) * 1.8
        else w = h * 0.55 end
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
                        if not on then
                            hideESP(d)
                        else
                            local box = boxOf(char)
                            local x, y, w, h
                            if box then
                                x, y, w, h = box.x, box.y, box.w, box.h
                            else
                                h = math.clamp(8000 / math.max(dist, 1), 20, 500)
                                w = h * 0.5
                                x = sp.X - w * 0.5
                                y = sp.Y - h * 0.5
                            end
                            d.Box.Visible = C.ESP_Box
                            if C.ESP_Box then
                                d.Box.Size = Vector2.new(w, h)
                                d.Box.Position = Vector2.new(x, y)
                                d.Box.Color = col
                            end
                            d.Line.Visible = C.ESP_Line
                            if C.ESP_Line then
                                d.Line.From = Vector2.new(Camera.ViewportSize.X * 0.5, Camera.ViewportSize.Y)
                                d.Line.To = Vector2.new(sp.X, sp.Y)
                                d.Line.Color = col
                            end
                            d.Name.Visible = C.ESP_Name
                            d.NameBg.Visible = C.ESP_Name
                            if C.ESP_Name then
                                d.Name.Text = p.Name
                                d.Name.Position = Vector2.new(x + w * 0.5, y - 18)
                                d.Name.Color = col
                                local tw = #p.Name * 7 + 12
                                d.NameBg.Size = Vector2.new(tw, 18)
                                d.NameBg.Position = Vector2.new(x + w * 0.5 - tw * 0.5, y - 19)
                            end
                            d.Dist.Visible = C.ESP_Dist
                            if C.ESP_Dist then
                                d.Dist.Text = tostring(math.floor(dist)) .. "m"
                                d.Dist.Position = Vector2.new(x + w * 0.5, y + h + 2)
                                d.Dist.Color = col
                            end
                            d.HpBg.Visible = C.ESP_HP
                            d.HpBar.Visible = C.ESP_HP
                            d.HpText.Visible = C.ESP_HP and C.ESP_HPText
                            if C.ESP_HP and hum.MaxHealth > 0 then
                                local hp = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                                local hpc = Color3.fromRGB(255 * (1 - hp), 255 * hp, 0)
                                d.HpBg.Size = Vector2.new(4, h)
                                d.HpBg.Position = Vector2.new(x - 8, y)
                                d.HpBar.Size = Vector2.new(4, h * hp)
                                d.HpBar.Position = Vector2.new(x - 8, y + h * (1 - hp))
                                d.HpBar.Color = hpc
                                if C.ESP_HPText then
                                    d.HpText.Text = string.format("%d", math.floor(hum.Health))
                                    d.HpText.Position = Vector2.new(x - 10, y - 15)
                                    d.HpText.Color = hpc
                                end
                            end
                            if C.ESP_DistBar then
                                local frac = math.clamp(1 - dist / C.ESP_MaxDist, 0, 1)
                                d.DistBarBg.Visible = true
                                d.DistBarBg.Size = Vector2.new(w, 3)
                                d.DistBarBg.Position = Vector2.new(x, y + h + 18)
                                d.DistBarFg.Visible = true
                                d.DistBarFg.Size = Vector2.new(w * frac, 3)
                                d.DistBarFg.Position = Vector2.new(x, y + h + 18)
                                d.DistBarFg.Color = col
                            else
                                d.DistBarBg.Visible = false
                                d.DistBarFg.Visible = false
                            end
                            if C.ESP_Skel then
                                for i, pair in ipairs(BONE_PAIRS) do
                                    local a = char:FindFirstChild(pair[1])
                                    local b = char:FindFirstChild(pair[2])
                                    local l = d.Bones[i]
                                    if a and b then
                                        local pa, onA = Camera:WorldToViewportPoint(a.Position)
                                        local pb, onB = Camera:WorldToViewportPoint(b.Position)
                                        if onA and onB then
                                            l.From = Vector2.new(pa.X, pa.Y)
                                            l.To = Vector2.new(pb.X, pb.Y)
                                            l.Color = col
                                            l.Visible = true
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
                        local s = math.clamp(8000 / math.max(dist, 1), 24, 300)
                        w, h = s, s
                    end
                    d.Box.Visible = C.V_ESP_Box
                    if C.V_ESP_Box then
                        d.Box.Size = Vector2.new(w, h)
                        d.Box.Position = Vector2.new(sp.X - w * 0.5, sp.Y - h * 0.5)
                        d.Box.Color = C.ColVehicle
                    end
                    d.Name.Visible = C.V_ESP_Name
                    if C.V_ESP_Name then
                        d.Name.Text = m.Name
                        d.Name.Position = Vector2.new(sp.X, sp.Y - h * 0.5 - 18)
                        d.Name.Color = C.ColVehicle
                    end
                    d.Dist.Visible = C.V_ESP_Dist
                    if C.V_ESP_Dist then
                        d.Dist.Text = tostring(math.floor(dist)) .. "m"
                        d.Dist.Position = Vector2.new(sp.X, sp.Y + h * 0.5 + 2)
                        d.Dist.Color = C.ColVehicle
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
                    hrp.Transparency = 0.7
                    hrp.CanCollide = false
                else
                    hrp.Size = Vector3.new(2, 2, 1)
                    hrp.Transparency = 1
                    hrp.CanCollide = true
                end
            end
        end
    end
end

-- ═══════════════ CROSSHAIR + HITMARKER ═══════════════
local CH1 = TrackDraw(Drawing.new("Line"))
local CH2 = TrackDraw(Drawing.new("Line"))
CH1.Thickness = 2; CH2.Thickness = 2
CH1.Color = C.ColNeon; CH2.Color = C.ColNeon

local Hitmarker = TrackDraw(Drawing.new("Text"))
Hitmarker.Text = "+"
Hitmarker.Size = 24
Hitmarker.Center = true
Hitmarker.Outline = true
Hitmarker.Color = Color3.fromRGB(255, 50, 50)
Hitmarker.Visible = false
local hitmarkerUntil = 0

local function UpdateCrosshair()
    if not C.Crosshair then
        CH1.Visible = false; CH2.Visible = false
        return
    end
    local cx, cy = Camera.ViewportSize.X * 0.5, Camera.ViewportSize.Y * 0.5
    local s = C.CH_Size
    CH1.From = Vector2.new(cx - s, cy); CH1.To = Vector2.new(cx + s, cy); CH1.Visible = true
    CH2.From = Vector2.new(cx, cy - s); CH2.To = Vector2.new(cx, cy + s); CH2.Visible = true
end

local function FlashHitmarker()
    if not C.Hitmarker then return end
    local cx, cy = Camera.ViewportSize.X * 0.5, Camera.ViewportSize.Y * 0.5
    Hitmarker.Position = Vector2.new(cx, cy)
    Hitmarker.Visible = true
    hitmarkerUntil = tick() + 0.15
end

TrackConn(WS.DescendantAdded:Connect(function(inst)
    if inst:IsA("Humanoid") then
        local char = inst.Parent
        if char and char:FindFirstChild("HumanoidRootPart") and Players:GetPlayerFromCharacter(char) then
            TrackConn(inst.HealthChanged:Connect(function(hp)
                if hp < inst.MaxHealth and Players:GetPlayerFromCharacter(char) ~= LP then
                    FlashHitmarker()
                end
            end))
        end
    end
end))

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

-- ═══════════════ UI ═══════════════
local Combat = Window:CreateTab("Combat")
local Visual = Window:CreateTab("Visuals")
local Vehicles = Window:CreateTab("Vehicles")
local TP = Window:CreateTab("Teleport")
local Settings = Window:CreateTab("Settings")

Combat:CreateToggle({ Name = "Silent Aim", CurrentValue = C.Silent, Flag = "silent", Callback = function(v) C.Silent = v end })
Combat:CreateSlider({ Name = "FOV %", Range = {5, 100}, Increment = 1, Suffix = "%", CurrentValue = C.FOVPercent, Flag = "fov", Callback = function(v) C.FOVPercent = v end })
Combat:CreateSlider({ Name = "Max Distance", Range = {500, 5000}, Increment = 100, Suffix = "m", CurrentValue = C.MaxDist, Flag = "maxdist", Callback = function(v) C.MaxDist = v end })
Combat:CreateSlider({ Name = "Prediction X (x10)", Range = {5, 30}, Increment = 1, CurrentValue = math.floor(C.Prediction * 10), Flag = "predx", Callback = function(v) C.Prediction = v / 10 end })
Combat:CreateSlider({ Name = "Prediction Y (x10)", Range = {5, 30}, Increment = 1, CurrentValue = math.floor(C.PredictionY * 10), Flag = "predy", Callback = function(v) C.PredictionY = v / 10 end })
Combat:CreateSlider({ Name = "Smoothing %", Range = {0, 95}, Increment = 1, Suffix = "%", CurrentValue = math.floor(C.Smoothing * 100), Flag = "smooth", Callback = function(v) C.Smoothing = v / 100 end })
Combat:CreateDropdown({ Name = "Priority", Options = {"distance", "health", "threat", "fov"}, CurrentOption = {C.PriorityMode}, Flag = "prio", Callback = function(o) C.PriorityMode = o[1] end })
Combat:CreateToggle({ Name = "Headshot", CurrentValue = C.Headshot, Flag = "headshot", Callback = function(v) C.Headshot = v end })
Combat:CreateToggle({ Name = "Wall Check", CurrentValue = C.WallCheck, Flag = "wall", Callback = function(v) C.WallCheck = v end })
Combat:CreateToggle({ Name = "Bypass", CurrentValue = C.Bypass, Flag = "bypass", Callback = function(v) C.Bypass = v end })
Combat:CreateSlider({ Name = "Bypass Spread", Range = {0, 30}, Increment = 1, CurrentValue = math.floor(C.BypassSpread * 100), Flag = "bspread", Callback = function(v) C.BypassSpread = v / 100 end })
Combat:CreateDropdown({ Name = "Team Filter", Options = {"all", "enemy", "my"}, CurrentOption = {C.TeamFilter}, Flag = "team", Callback = function(o) C.TeamFilter = o[1] end })
Combat:CreateToggle({ Name = "Hitbox Expander", CurrentValue = C.HitboxExp, Flag = "hitbox", Callback = function(v) C.HitboxExp = v; ApplyHitbox() end })
Combat:CreateSlider({ Name = "Hitbox Size", Range = {2, 20}, Increment = 1, CurrentValue = C.HitboxSize, Flag = "hbsize", Callback = function(v) C.HitboxSize = v; ApplyHitbox() end })
Combat:CreateToggle({ Name = "Hitmarker", CurrentValue = C.Hitmarker, Flag = "hitmark", Callback = function(v) C.Hitmarker = v end })
Combat:CreateColorPicker({ Name = "Aim Color", Color = C.ColAim, Flag = "aimcol", Callback = function(c) C.ColAim = c; SilentLine.Color = c; FOVCircle.Color = c end })

Visual:CreateToggle({ Name = "ESP", CurrentValue = C.ESP, Flag = "esp", Callback = function(v) C.ESP = v end })
Visual:CreateToggle({ Name = "Box", CurrentValue = C.ESP_Box, Flag = "espbox", Callback = function(v) C.ESP_Box = v end })
Visual:CreateToggle({ Name = "Name", CurrentValue = C.ESP_Name, Flag = "espname", Callback = function(v) C.ESP_Name = v end })
Visual:CreateToggle({ Name = "Distance", CurrentValue = C.ESP_Dist, Flag = "espdist", Callback = function(v) C.ESP_Dist = v end })
Visual:CreateToggle({ Name = "HP Bar", CurrentValue = C.ESP_HP, Flag = "esphp", Callback = function(v) C.ESP_HP = v end })
Visual:CreateToggle({ Name = "HP Text", CurrentValue = C.ESP_HPText, Flag = "esphpt", Callback = function(v) C.ESP_HPText = v end })
Visual:CreateToggle({ Name = "Skeleton", CurrentValue = C.ESP_Skel, Flag = "espskel", Callback = function(v) C.ESP_Skel = v end })
Visual:CreateToggle({ Name = "Line", CurrentValue = C.ESP_Line, Flag = "espline", Callback = function(v) C.ESP_Line = v end })
Visual:CreateToggle({ Name = "Offscreen Arrows", CurrentValue = C.ESP_Offscr, Flag = "espoff", Callback = function(v) C.ESP_Offscr = v end })
Visual:CreateToggle({ Name = "Distance Bar", CurrentValue = C.ESP_DistBar, Flag = "espdb", Callback = function(v) C.ESP_DistBar = v end })
Visual:CreateSlider({ Name = "ESP Max Distance", Range = {500, 5000}, Increment = 100, Suffix = "m", CurrentValue = C.ESP_MaxDist, Flag = "espmax", Callback = function(v) C.ESP_MaxDist = v end })
Visual:CreateToggle({ Name = "Crosshair", CurrentValue = C.Crosshair, Flag = "ch", Callback = function(v) C.Crosshair = v end })
Visual:CreateSlider({ Name = "Crosshair Size", Range = {5, 30}, Increment = 1, CurrentValue = C.CH_Size, Flag = "chsize", Callback = function(v) C.CH_Size = v end })
Visual:CreateColorPicker({ Name = "Ally Color", Color = C.ColAlly, Flag = "colally", Callback = function(c) C.ColAlly = c end })
Visual:CreateColorPicker({ Name = "Enemy Color", Color = C.ColEnemy, Flag = "colenemy", Callback = function(c) C.ColEnemy = c end })
Visual:CreateColorPicker({ Name = "Crosshair Color", Color = C.ColNeon, Flag = "colch", Callback = function(c) C.ColNeon = c; CH1.Color = c; CH2.Color = c end })

Vehicles:CreateToggle({ Name = "Vehicle ESP", CurrentValue = C.V_ESP, Flag = "vesp", Callback = function(v) C.V_ESP = v end })
Vehicles:CreateToggle({ Name = "Box", CurrentValue = C.V_ESP_Box, Flag = "vespbox", Callback = function(v) C.V_ESP_Box = v end })
Vehicles:CreateToggle({ Name = "Name", CurrentValue = C.V_ESP_Name, Flag = "vespname", Callback = function(v) C.V_ESP_Name = v end })
Vehicles:CreateToggle({ Name = "Distance", CurrentValue = C.V_ESP_Dist, Flag = "vespdist", Callback = function(v) C.V_ESP_Dist = v end })
Vehicles:CreateSlider({ Name = "Max Distance", Range = {100, 10000}, Increment = 100, Suffix = "m", CurrentValue = C.V_ESP_MaxDist, Flag = "vespmax", Callback = function(v) C.V_ESP_MaxDist = v end })
Vehicles:CreateColorPicker({ Name = "Color", Color = C.ColVehicle, Flag = "colveh", Callback = function(c) C.ColVehicle = c end })

TP:CreateToggle({ Name = "Drop to ground", CurrentValue = C.TP_DropToGround, Flag = "tpdrop", Callback = function(v) C.TP_DropToGround = v end })
TP:CreateSlider({ Name = "Safe drop", Range = {1, 20}, Increment = 1, CurrentValue = C.TP_SafeDrop, Flag = "tpsafe", Callback = function(v) C.TP_SafeDrop = v end })
TP:CreateButton({ Name = "TP Base", Callback = TPBase })
TP:CreateButton({ Name = "TP Airdrop", Callback = TPAirdrop })
TP:CreateButton({ Name = "TP Crashed UAV", Callback = TPCrashedUAV })
TP:CreateButton({ Name = "TP Capture", Callback = TPCapture })
TP:CreateButton({ Name = "TP Nearest Enemy", Callback = TPNearestEnemy })

Settings:CreateButton({ Name = "Save Config", Callback = function() Rayfield:SaveConfiguration() end })
Settings:CreateButton({ Name = "Full Unload", Callback = function()
    local fn = getgenv().MeowModUnload
    if fn then fn() end
end })

-- ═══════════════ RENDER LOOP ═══════════════
local espAccum, ESP_INTERVAL = 0, 1 / 30
local vehAccum, VEH_INTERVAL = 0, 1 / 15
local chAccum,  CH_INTERVAL  = 0, 1 / 30

TrackConn(RunService.RenderStepped:Connect(function(dt)
    if getgenv().MeowModUnloaded then return end
    pcall(function() UpdateAim(dt) end)
    espAccum = espAccum + dt
    if espAccum >= ESP_INTERVAL then espAccum = 0; pcall(UpdateESP) end
    vehAccum = vehAccum + dt
    if vehAccum >= VEH_INTERVAL then vehAccum = 0; pcall(UpdateVehicleESP) end
    chAccum = chAccum + dt
    if chAccum >= CH_INTERVAL then chAccum = 0; pcall(UpdateCrosshair) end
    if Hitmarker.Visible and tick() > hitmarkerUntil then Hitmarker.Visible = false end
    if C.HitboxExp then pcall(ApplyHitbox) end
end))

-- ═══════════════ FULL UNLOAD ═══════════════
getgenv().MeowModUnload = function()
    if getgenv().MeowModUnloaded then return end
    getgenv().MeowModUnloaded = true
    removeNamecallHook()
    for _, c in ipairs(Connections) do
        pcall(function() if typeof(c) == "RBXScriptConnection" then c:Disconnect() end end)
    end
    Connections = {}
    for _, d in ipairs(Drawings) do
        pcall(function() d:Remove() end)
    end
    Drawings = {}
    ESP = {}
    VehicleESP = {}
    VehicleSeats = {}
    for _, p in ipairs(Players:GetPlayers()) do
        local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            pcall(function()
                hrp.Size = Vector3.new(2, 2, 1)
                hrp.Transparency = 1
                hrp.CanCollide = true
            end)
        end
    end
    silentTarget = nil; aimSmoothPos = nil; isShooting = false
    pcall(function() Rayfield:Destroy() end)
    pcall(function()
        getgenv().MeowModUnload = nil
        getgenv().MeowModUnloaded = nil
    end)
end

Rayfield:Notify({
    Title = "MeowMod V4.6",
    Content = "No-crash build. Raycast hook removed.",
    Duration = 5,
})
