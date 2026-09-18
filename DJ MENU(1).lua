--// DJ MENU - ESP + AIMBOT + OUTROS
--// Tema: Azul Escuro + Preto | Mobile
--// Animação de abertura v2 (tela branca 2s + som do raio) + Auto-destroy
--// v4: Skeleton ESP + Aimbot 1-50 + Invis Players

--// ===== AUTO-DESTROY =====
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local existing = PlayerGui:FindFirstChild("DJ_Menu")
if existing then existing:Destroy() end
local existingIntro = PlayerGui:FindFirstChild("DJ_Intro")
if existingIntro then existingIntro:Destroy() end

for _, p in ipairs(Players:GetPlayers()) do
    if p.Character then
        local hl = p.Character:FindFirstChild("ESP_Highlight")
        if hl then hl:Destroy() end
    end
end

--// ===== SERVIÇOS =====
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Camera = workspace.CurrentCamera

local hasDrawing = pcall(function() return Drawing.new("Circle") end)

--// Cores
local DARK_BG = Color3.fromRGB(10, 10, 14)
local DARK_BG2 = Color3.fromRGB(18, 18, 26)
local DARK_BG3 = Color3.fromRGB(24, 24, 34)
local BLUE = Color3.fromRGB(0, 120, 255)
local BLUE_LIGHT = Color3.fromRGB(60, 160, 255)
local BLUE_DARK = Color3.fromRGB(0, 70, 180)
local PURPLE = Color3.fromRGB(170, 0, 255)
local TEXT_WHITE = Color3.fromRGB(240, 240, 240)
local TEXT_DIM = Color3.fromRGB(140, 140, 160)

--// Variáveis
local aimbotEnabled = false
local aimbotLevel = 5
local fovSize = 100
local aimTarget = "Cabeça"
local teamCheckEnabled = false
local panelScale = 100
local ignoredPlayers = {}

local espEnabled = { WallChams = false, Name = false, Distance = false, Skeleton = false, InvisPlayers = false }
local espObjects = {}
local skeletonObjects = {}
local invisOriginalState = {} -- guarda Transparency original de cada player

local VflyEnabled, FlySpeed = false, 60
local CurrentVehicle, BodyVel, BodyGyro = nil, nil, nil
local vflyInputs = { Gas = false, Re = false }
local noclipEnabled = false
local noclipOriginalState = {}

--// Utils
local function IsSameTeam(player)
    if not teamCheckEnabled then return false end
    if not player or not player.Team then return false end
    if not LocalPlayer.Team then return false end
    return player.Team == LocalPlayer.Team
end

local function IsIgnored(player)
    if ignoredPlayers[player] then return true end
    if ignoredPlayers[player.Name] then return true end
    return false
end

local function WorldToScreen(position)
    local sp, onScreen = Camera:WorldToViewportPoint(position)
    if sp.Z <= 0 then return Vector2.new(sp.X, sp.Y), false end
    return Vector2.new(sp.X, sp.Y), onScreen
end

local function GetDistance(a, b) return (a - b).Magnitude end

local function GetTargetPart(player)
    local char = player.Character
    if not char then return nil end
    if aimTarget == "Cabeça" then return char:FindFirstChild("Head") end
    return char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
end

local function GetLocalRoot()
    if not LocalPlayer.Character then return nil end
    return LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
end

local function GetClosestPlayerToCrosshair()
    local closest, closestDist = nil, fovSize
    local mousePos = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            if not IsSameTeam(player) and not IsIgnored(player) then
                local char = player.Character
                local hum = char:FindFirstChildOfClass("Humanoid")
                if not hum or hum.Health > 0 then
                    local tp = GetTargetPart(player)
                    if tp then
                        local pos, onScreen = WorldToScreen(tp.Position)
                        if onScreen then
                            local d = (pos - mousePos).Magnitude
                            if d < closestDist then
                                closestDist = d
                                closest = player
                            end
                        end
                    end
                end
            end
        end
    end
    return closest
end

--// Aimbot (nível 1-50)
RunService.RenderStepped:Connect(function()
    if not aimbotEnabled then return end
    local target = GetClosestPlayerToCrosshair()
    if not target then return end
    local tp = GetTargetPart(target)
    if not tp then return end
    local targetPos = tp.Position
    if aimbotLevel >= 50 then
        Camera.CFrame = CFrame.new(Camera.CFrame.Position, targetPos)
    else
        local smooth = aimbotLevel / 50
        if smooth < 0.02 then smooth = 0.02 end
        local cp = Camera.CFrame.Position
        local lv = (targetPos - cp).Unit
        Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(cp, cp + lv), smooth)
    end
end)

--// ESP - Highlight
local function CreateHighlightForPlayer(player)
    if player == LocalPlayer then return end
    local char = player.Character
    if not char then return end
    local old = char:FindFirstChild("ESP_Highlight")
    if old then old:Destroy() end
    local hl = Instance.new("Highlight")
    hl.Name = "ESP_Highlight"
    hl.Adornee = char
    hl.FillColor = BLUE
    hl.OutlineColor = BLUE_LIGHT
    hl.FillTransparency = 0.85
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = char
end

--// ESP - Textos
local function CreateESPForPlayer(player)
    if player == LocalPlayer then return end
    if espObjects[player] then return end
    if not hasDrawing then return end
    local d = { Name = Drawing.new("Text"), Distance = Drawing.new("Text") }
    d.Name.Size = 16; d.Name.Center = true; d.Name.Outline = true; d.Name.Color = BLUE; d.Name.Visible = false
    d.Distance.Size = 14; d.Distance.Center = true; d.Distance.Outline = true; d.Distance.Color = BLUE; d.Distance.Visible = false
    espObjects[player] = d
end

--// ===== INVIS PLAYERS (75% invisível) =====
local INVIS_TRANSPARENCY = 0.75

local function ApplyInvisToPlayer(player)
    if player == LocalPlayer then return end
    local char = player.Character
    if not char then return end
    -- Percorre todas as partes e acessórios
    for _, obj in ipairs(char:GetDescendants()) do
        if obj:IsA("BasePart") or obj:IsA("Decal") then
            -- Guarda o valor original só uma vez
            if invisOriginalState[obj] == nil then
                invisOriginalState[obj] = obj.Transparency
            end
            obj.Transparency = INVIS_TRANSPARENCY
        end
    end
end

local function RevertInvisFromPlayer(player)
    local char = player.Character
    if not char then return end
    for _, obj in ipairs(char:GetDescendants()) do
        if (obj:IsA("BasePart") or obj:IsA("Decal")) and invisOriginalState[obj] ~= nil then
            obj.Transparency = invisOriginalState[obj]
        end
    end
end

local function RevertAllInvis()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            RevertInvisFromPlayer(player)
        end
    end
    invisOriginalState = {}
end

-- Aplica/remove Invis em todos os players quando o toggle muda
local function UpdateInvisForAll()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            if espEnabled.InvisPlayers then
                ApplyInvisToPlayer(player)
            end
        end
    end
end

--// SKELETON ESP
local skeletonBones = {
    R6 = {
        {"Head", "Torso"},
        {"Torso", "Left Arm"},
        {"Torso", "Right Arm"},
        {"Torso", "Left Leg"},
        {"Torso", "Right Leg"},
    },
    R15 = {
        {"Head", "UpperTorso"},
        {"UpperTorso", "LowerTorso"},
        {"UpperTorso", "LeftUpperArm"},
        {"LeftUpperArm", "LeftLowerArm"},
        {"LeftLowerArm", "LeftHand"},
        {"UpperTorso", "RightUpperArm"},
        {"RightUpperArm", "RightLowerArm"},
        {"RightLowerArm", "RightHand"},
        {"LowerTorso", "LeftUpperLeg"},
        {"LeftUpperLeg", "LeftLowerLeg"},
        {"LeftLowerLeg", "LeftFoot"},
        {"LowerTorso", "RightUpperLeg"},
        {"RightUpperLeg", "RightLowerLeg"},
        {"RightLowerLeg", "RightFoot"},
    }
}

local function GetRigType(char)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        local rig = hum.RigType
        if rig == Enum.HumanoidRigType.R15 then return "R15" end
        if rig == Enum.HumanoidRigType.R6 then return "R6" end
    end
    if char:FindFirstChild("UpperTorso") then return "R15" end
    if char:FindFirstChild("Torso") then return "R6" end
    return nil
end

local function CreateSkeletonForPlayer(player)
    if player == LocalPlayer then return end
    if skeletonObjects[player] then return end
    if not hasDrawing then return end
    local lines = {}
    for i = 1, 15 do
        local line = Drawing.new("Line")
        line.Thickness = 1.5
        line.Color = BLUE
        line.Transparency = 1
        line.Visible = false
        table.insert(lines, line)
    end
    skeletonObjects[player] = lines
end

local function RemoveSkeletonForPlayer(player)
    local lines = skeletonObjects[player]
    if lines then
        for _, line in ipairs(lines) do
            if line and line.Remove then line:Remove() end
        end
        skeletonObjects[player] = nil
    end
end

local function UpdateSkeletonForPlayer(player)
    local lines = skeletonObjects[player]
    if not lines then return end
    local char = player.Character
    if not char or not char.Parent then
        for _, l in ipairs(lines) do l.Visible = false end
        return
    end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then
        for _, l in ipairs(lines) do l.Visible = false end
        return
    end
    local rig = GetRigType(char)
    if not rig then
        for _, l in ipairs(lines) do l.Visible = false end
        return
    end
    local bones = skeletonBones[rig]
    local color = IsSameTeam(player) and Color3.fromRGB(0, 255, 100) or BLUE
    for i, line in ipairs(lines) do
        local bone = bones[i]
        if bone then
            local partA = char:FindFirstChild(bone[1])
            local partB = char:FindFirstChild(bone[2])
            if partA and partB then
                local posA, onA = WorldToScreen(partA.Position)
                local posB, onB = WorldToScreen(partB.Position)
                if onA and onB then
                    line.From = posA
                    line.To = posB
                    line.Color = color
                    line.Visible = true
                else
                    line.Visible = false
                end
            else
                line.Visible = false
            end
        else
            line.Visible = false
        end
    end
end

Players.PlayerRemoving:Connect(function(player)
    local d = espObjects[player]
    if d then
        for _, o in pairs(d) do
            if o and o.Remove then o:Remove() end
        end
        espObjects[player] = nil
    end
    RemoveSkeletonForPlayer(player)
    ignoredPlayers[player] = nil
end)

--// FOV Circle
local fovCircle = nil
if hasDrawing then
    fovCircle = Drawing.new("Circle")
    fovCircle.Radius = fovSize
    fovCircle.Color = BLUE
    fovCircle.Thickness = 2
    fovCircle.Filled = false
    fovCircle.Visible = false
end

--// Loop principal do ESP
RunService.RenderStepped:Connect(function()
    if fovCircle then
        if aimbotEnabled then
            fovCircle.Visible = true
            fovCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
            fovCircle.Radius = fovSize
        else
            fovCircle.Visible = false
        end
    end

    local localRoot = GetLocalRoot()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            if not espObjects[player] then CreateESPForPlayer(player) end
            local d = espObjects[player]
            if d then
                local char = player.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                local skip = teamCheckEnabled and IsSameTeam(player)
                if not char or not char.Parent or (hum and hum.Health <= 0) or skip then
                    d.Name.Visible = false
                    d.Distance.Visible = false
                    if char then
                        local hl = char:FindFirstChild("ESP_Highlight")
                        if hl then hl:Destroy() end
                    end
                else
                    if espEnabled.WallChams then
                        if not char:FindFirstChild("ESP_Highlight") then CreateHighlightForPlayer(player) end
                    else
                        local hl = char:FindFirstChild("ESP_Highlight")
                        if hl then hl:Destroy() end
                    end
                    local root = char:FindFirstChild("HumanoidRootPart")
                    local head = char:FindFirstChild("Head")
                    if root and head then
                        local hs = WorldToScreen(head.Position)
                        local rs = WorldToScreen(root.Position)
                        local dist = localRoot and GetDistance(localRoot.Position, root.Position) or 9999999

                        if espEnabled.Name then
                            d.Name.Text = player.Name
                            d.Name.Position = Vector2.new(hs.X, hs.Y - 40)
                            d.Name.Visible = true
                        else
                            d.Name.Visible = false
                        end

                        if espEnabled.Distance then
                            local distText = dist >= 9999999 and "∞" or string.format("%.1f m", dist)
                            d.Distance.Text = distText
                            d.Distance.Position = Vector2.new(rs.X, rs.Y + 20)
                            d.Distance.Visible = true
                        else
                            d.Distance.Visible = false
                        end
                    else
                        d.Name.Visible = false
                        d.Distance.Visible = false
                    end
                end
            end

            -- Atualiza Skeleton
            if espEnabled.Skeleton then
                if not skeletonObjects[player] then CreateSkeletonForPlayer(player) end
                UpdateSkeletonForPlayer(player)
            else
                if skeletonObjects[player] then
                    for _, l in ipairs(skeletonObjects[player]) do l.Visible = false end
                end
            end

            -- Aplica Invis Players (75%)
            if espEnabled.InvisPlayers then
                ApplyInvisToPlayer(player)
            end
        end
    end
end)

--// Noclip
RunService.Stepped:Connect(function()
    if not LocalPlayer.Character then return end
    if noclipEnabled then
        for _, v in pairs(LocalPlayer.Character:GetDescendants()) do
            if v:IsA("BasePart") then
                if noclipOriginalState[v] == nil then
                    noclipOriginalState[v] = v.CanCollide
                end
                v.CanCollide = false
            end
        end
    else
        for part, original in pairs(noclipOriginalState) do
            if part and part.Parent then
                part.CanCollide = original
            end
        end
        noclipOriginalState = {}
    end
end)

--// VFly
local function EnableVFly()
    local seat = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") and LocalPlayer.Character.Humanoid.SeatPart
    if seat then
        CurrentVehicle = seat
        BodyVel = Instance.new("BodyVelocity")
        BodyVel.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        BodyVel.Parent = seat
        BodyGyro = Instance.new("BodyGyro")
        BodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
        BodyGyro.P = 500000
        BodyGyro.Parent = seat
    end
end

local function DisableVFly()
    if BodyVel then BodyVel:Destroy() end
    if BodyGyro then BodyGyro:Destroy() end
    CurrentVehicle = nil
end

RunService.RenderStepped:Connect(function()
    if VflyEnabled and CurrentVehicle and CurrentVehicle.Parent then
        CurrentVehicle.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        BodyGyro.CFrame = Camera.CFrame
        local camCF = Camera.CFrame
        local forward = camCF.LookVector
        local right = camCF.RightVector
        local up = Vector3.new(0, 1, 0)
        local moveDir = Vector3.new(0, 0, 0)
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + forward end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - forward end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - right end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + right end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + up end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift) then moveDir = moveDir - up end
        if vflyInputs.Gas then moveDir = moveDir + forward end
        if vflyInputs.Re then moveDir = moveDir - forward end
        if moveDir.Magnitude > 0 then
            BodyVel.Velocity = moveDir.Unit * FlySpeed
        else
            BodyVel.Velocity = Vector3.new(0, 0, 0)
        end
    end
end)

--// ========== ANIMAÇÃO DE ABERTURA v2 ==========
local function PlayIntro(callback)
    local intro = Instance.new("ScreenGui")
    intro.Name = "DJ_Intro"
    intro.ResetOnSpawn = false
    intro.IgnoreGuiInset = true
    intro.DisplayOrder = 9999999
    intro.Parent = PlayerGui

    local black = Instance.new("Frame")
    black.Size = UDim2.new(1, 0, 1, 0)
    black.BackgroundColor3 = Color3.new(0, 0, 0)
    black.BorderSizePixel = 0
    black.ZIndex = 1
    black.Parent = intro

    local dLetter = Instance.new("TextLabel")
    dLetter.Size = UDim2.new(0, 300, 0, 300)
    dLetter.Position = UDim2.new(0.5, -150, 0.5, -150)
    dLetter.BackgroundTransparency = 1
    dLetter.Text = "D"
    dLetter.TextColor3 = PURPLE
    dLetter.Font = Enum.Font.GothamBlack
    dLetter.TextSize = 0
    dLetter.TextTransparency = 0
    dLetter.ZIndex = 2
    dLetter.Parent = intro

    local dGlow = Instance.new("TextLabel")
    dGlow.Size = UDim2.new(0, 300, 0, 300)
    dGlow.Position = UDim2.new(0.5, -150, 0.5, -150)
    dGlow.BackgroundTransparency = 1
    dGlow.Text = "D"
    dGlow.TextColor3 = PURPLE
    dGlow.Font = Enum.Font.GothamBlack
    dGlow.TextSize = 0
    dGlow.TextTransparency = 0.7
    dGlow.ZIndex = 1
    dGlow.Parent = intro

    local flash = Instance.new("Frame")
    flash.Size = UDim2.new(1, 0, 1, 0)
    flash.BackgroundColor3 = Color3.new(1, 1, 1)
    flash.BorderSizePixel = 0
    flash.BackgroundTransparency = 1
    flash.ZIndex = 5
    flash.Parent = intro

    local djText = Instance.new("TextLabel")
    djText.Size = UDim2.new(1, 0, 0, 60)
    djText.Position = UDim2.new(0, 0, 0.5, 130)
    djText.BackgroundTransparency = 1
    djText.Text = "DJ MENU"
    djText.TextColor3 = BLUE
    djText.Font = Enum.Font.GothamBlack
    djText.TextSize = 0
    djText.TextTransparency = 1
    djText.ZIndex = 3
    djText.Parent = intro

    TweenService:Create(dLetter, TweenInfo.new(1.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {TextSize = 200}):Play()
    TweenService:Create(dGlow, TweenInfo.new(1.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {TextSize = 220, TextTransparency = 0.5}):Play()

    task.spawn(function()
        local t = 0
        while t < 1.5 do
            t = t + task.wait(0.05)
            local pulse = 1 + math.sin(t * 12) * 0.06
            dLetter.TextSize = 200 * pulse
        end
    end)

    task.wait(1.5)

    local thunder = Instance.new("Sound")
    thunder.SoundId = "rbxassetid://125036576486112"
    thunder.Volume = 3
    thunder.Parent = intro
    thunder:Play()

    flash.BackgroundTransparency = 0.2
    dLetter.TextColor3 = Color3.new(1, 1, 1)

    task.spawn(function()
        for i = 1, 12 do
            dLetter.Position = UDim2.new(0.5, -150 + math.random(-15, 15), 0.5, -150 + math.random(-15, 15))
            task.wait(0.02)
        end
        dLetter.Position = UDim2.new(0.5, -150, 0.5, -150)
    end)

    task.wait(0.1)
    flash.BackgroundTransparency = 0
    dLetter.TextColor3 = BLUE
    dGlow.TextColor3 = BLUE
    task.wait(2)

    TweenService:Create(flash, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 1}):Play()
    task.wait(0.6)

    TweenService:Create(dLetter, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {TextSize = 160, Position = UDim2.new(0.5, -150, 0.5, -180)}):Play()
    TweenService:Create(dGlow, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {TextSize = 180, TextTransparency = 0.6, Position = UDim2.new(0.5, -150, 0.5, -180)}):Play()
    task.wait(0.3)

    djText.TextTransparency = 1
    TweenService:Create(djText, TweenInfo.new(0.8, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {TextSize = 42, TextTransparency = 0}):Play()
    task.wait(2.2)

    TweenService:Create(black, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
    TweenService:Create(dLetter, TweenInfo.new(0.5), {TextTransparency = 1}):Play()
    TweenService:Create(dGlow, TweenInfo.new(0.5), {TextTransparency = 1}):Play()
    TweenService:Create(djText, TweenInfo.new(0.5), {TextTransparency = 1}):Play()

    task.wait(0.6)
    intro:Destroy()

    if callback then callback() end
end

--// ========== GUI ==========
local function BuildGUI()
    local ok, err = pcall(function()

        local ScreenGui = Instance.new("ScreenGui")
        ScreenGui.Name = "DJ_Menu"
        ScreenGui.Parent = PlayerGui
        ScreenGui.ResetOnSpawn = false
        ScreenGui.IgnoreGuiInset = true
        ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        ScreenGui.DisplayOrder = 999999

        local btnOpen = Instance.new("TextButton")
        btnOpen.Size = UDim2.new(0, 48, 0, 48)
        btnOpen.Position = UDim2.new(0.05, 0, 0.15, 0)
        btnOpen.BackgroundColor3 = DARK_BG
        btnOpen.Text = "D"
        btnOpen.TextColor3 = BLUE
        btnOpen.Font = Enum.Font.GothamBold
        btnOpen.TextSize = 26
        btnOpen.ZIndex = 10
        btnOpen.AutoButtonColor = false
        btnOpen.Active = true
        btnOpen.Parent = ScreenGui
        local cD = Instance.new("UICorner"); cD.CornerRadius = UDim.new(1, 0); cD.Parent = btnOpen
        local sD = Instance.new("UIStroke"); sD.Color = BLUE; sD.Thickness = 2; sD.Parent = btnOpen
        local gD = Instance.new("UIGradient")
        gD.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, BLUE),
            ColorSequenceKeypoint.new(1, BLUE_DARK)
        })
        gD.Rotation = 45
        gD.Parent = sD

        local MainFrame = Instance.new("Frame")
        MainFrame.Size = UDim2.new(0, 270, 0, 420)
        MainFrame.Position = UDim2.new(0.5, -135, 0.18, 0)
        MainFrame.BackgroundColor3 = DARK_BG
        MainFrame.BorderSizePixel = 0
        MainFrame.Visible = false
        MainFrame.ZIndex = 3
        MainFrame.Active = true
        MainFrame.Parent = ScreenGui
        local cM = Instance.new("UICorner"); cM.CornerRadius = UDim.new(0, 12); cM.Parent = MainFrame
        local sM = Instance.new("UIStroke"); sM.Color = BLUE; sM.Thickness = 1.5; sM.Parent = MainFrame
        local gM = Instance.new("UIGradient")
        gM.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, DARK_BG3),
            ColorSequenceKeypoint.new(1, DARK_BG)
        })
        gM.Rotation = 90
        gM.Parent = MainFrame

        local uiScale = Instance.new("UIScale")
        uiScale.Scale = panelScale / 100
        uiScale.Parent = MainFrame

        local Header = Instance.new("Frame")
        Header.Size = UDim2.new(1, 0, 0, 55)
        Header.BackgroundColor3 = DARK_BG2
        Header.BorderSizePixel = 0
        Header.Active = true
        Header.Parent = MainFrame
        local hCorner = Instance.new("UICorner"); hCorner.CornerRadius = UDim.new(0, 12); hCorner.Parent = Header

        local AvatarContainer = Instance.new("Frame")
        AvatarContainer.Size = UDim2.new(0, 40, 1, 0)
        AvatarContainer.Position = UDim2.new(0, 10, 0, 0)
        AvatarContainer.BackgroundTransparency = 1
        AvatarContainer.Parent = Header

        local AvatarFrame = Instance.new("Frame")
        AvatarFrame.Size = UDim2.new(0, 28, 0, 28)
        AvatarFrame.Position = UDim2.new(0.5, -14, 0, 5)
        AvatarFrame.BackgroundColor3 = DARK_BG
        AvatarFrame.BorderSizePixel = 0
        AvatarFrame.Parent = AvatarContainer
        local avCorner = Instance.new("UICorner"); avCorner.CornerRadius = UDim.new(1, 0); avCorner.Parent = AvatarFrame
        local avStroke = Instance.new("UIStroke"); avStroke.Color = BLUE; avStroke.Thickness = 1.5; avStroke.Parent = AvatarFrame
        local avGrad = Instance.new("UIGradient")
        avGrad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, BLUE),
            ColorSequenceKeypoint.new(1, BLUE_DARK)
        })
        avGrad.Rotation = 45
        avGrad.Parent = avStroke

        local AvatarImg = Instance.new("ImageLabel")
        AvatarImg.Size = UDim2.new(1, -3, 1, -3)
        AvatarImg.Position = UDim2.new(0, 1.5, 0, 1.5)
        AvatarImg.BackgroundTransparency = 1
        AvatarImg.Image = "rbxthumb://type=AvatarHeadShot&id=" .. LocalPlayer.UserId .. "&w=150&h=150"
        AvatarImg.Parent = AvatarFrame
        local avImgCorner = Instance.new("UICorner"); avImgCorner.CornerRadius = UDim.new(1, 0); avImgCorner.Parent = AvatarImg

        local NickLabel = Instance.new("TextLabel")
        NickLabel.Size = UDim2.new(1, 0, 0, 14)
        NickLabel.Position = UDim2.new(0, 0, 0, 36)
        NickLabel.BackgroundTransparency = 1
        NickLabel.Text = LocalPlayer.Name
        NickLabel.TextColor3 = TEXT_WHITE
        NickLabel.Font = Enum.Font.GothamBold
        NickLabel.TextSize = 9
        NickLabel.TextTruncate = Enum.TextTruncate.AtEnd
        NickLabel.Parent = AvatarContainer

        local HeaderTitle = Instance.new("TextLabel")
        HeaderTitle.Size = UDim2.new(1, -70, 1, 0)
        HeaderTitle.Position = UDim2.new(0, 60, 0, 0)
        HeaderTitle.BackgroundTransparency = 1
        HeaderTitle.Text = "DJ MENU"
        HeaderTitle.TextColor3 = BLUE
        HeaderTitle.Font = Enum.Font.GothamBold
        HeaderTitle.TextSize = 20
        HeaderTitle.TextXAlignment = Enum.TextXAlignment.Right
        HeaderTitle.Parent = Header

        local HeaderLine = Instance.new("Frame")
        HeaderLine.Size = UDim2.new(1, -20, 0, 1)
        HeaderLine.Position = UDim2.new(0, 10, 1, -1)
        HeaderLine.BackgroundColor3 = BLUE
        HeaderLine.BackgroundTransparency = 0.7
        HeaderLine.BorderSizePixel = 0
        HeaderLine.Parent = Header

        local TabContent = Instance.new("Frame")
        TabContent.Size = UDim2.new(1, 0, 1, -95)
        TabContent.Position = UDim2.new(0, 0, 0, 55)
        TabContent.BackgroundTransparency = 1
        TabContent.Parent = MainFrame

        local TabBar = Instance.new("Frame")
        TabBar.Size = UDim2.new(1, -20, 0, 34)
        TabBar.Position = UDim2.new(0, 10, 1, -44)
        TabBar.BackgroundColor3 = DARK_BG2
        TabBar.BorderSizePixel = 0
        TabBar.Parent = MainFrame
        local tbCorner = Instance.new("UICorner"); tbCorner.CornerRadius = UDim.new(0, 8); tbCorner.Parent = TabBar
        local tbStroke = Instance.new("UIStroke"); tbStroke.Color = BLUE; tbStroke.Thickness = 1; tbStroke.Transparency = 0.5; tbStroke.Parent = TabBar

        local TabList = Instance.new("UIListLayout")
        TabList.FillDirection = Enum.FillDirection.Horizontal
        TabList.SortOrder = Enum.SortOrder.LayoutOrder
        TabList.Padding = UDim.new(0, 4)
        TabList.HorizontalAlignment = Enum.HorizontalAlignment.Center
        TabList.VerticalAlignment = Enum.VerticalAlignment.Center
        TabList.Parent = TabBar

        local pages = {}
        local tabButtons = {}

        local function CreatePage(name)
            local page = Instance.new("ScrollingFrame")
            page.Size = UDim2.new(1, 0, 1, 0)
            page.BackgroundTransparency = 1
            page.BorderSizePixel = 0
            page.ScrollBarThickness = 3
            page.ScrollBarImageColor3 = BLUE
            page.AutomaticCanvasSize = Enum.AutomaticSize.Y
            page.CanvasSize = UDim2.new(0, 0, 0, 0)
            page.Visible = false            page.Parent = TabContent

            local L = Instance.new("UIListLayout")
            L.SortOrder = Enum.SortOrder.LayoutOrder
            L.Padding = UDim.new(0, 5)
            L.Parent = page

            local P = Instance.new("UIPadding")
            P.PaddingTop = UDim.new(0, 8)
            P.PaddingLeft = UDim.new(0, 10)
            P.PaddingRight = UDim.new(0, 10)
            P.PaddingBottom = UDim.new(0, 8)
            P.Parent = page

            pages[name] = page
            return page
        end

        local function SelectTab(name)
            for n, p in pairs(pages) do p.Visible = (n == name) end
            for n, b in pairs(tabButtons) do
                if n == name then
                    b.BackgroundColor3 = BLUE
                    b.TextColor3 = Color3.new(1, 1, 1)
                    b.UIStroke.Transparency = 0
                else
                    b.BackgroundColor3 = DARK_BG
                    b.TextColor3 = BLUE
                    b.UIStroke.Transparency = 0.5
                end
            end
        end

        local function CreateTabButton(name, label)
            local b = Instance.new("TextButton")
            b.Size = UDim2.new(0, 74, 0, 26)
            b.BackgroundColor3 = DARK_BG
            b.Text = label
            b.TextColor3 = BLUE
            b.Font = Enum.Font.GothamBold
            b.TextSize = 11
            b.Parent = TabBar
            local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0, 6); bc.Parent = b
            local bs = Instance.new("UIStroke"); bs.Color = BLUE; bs.Thickness = 1; bs.Transparency = 0.5; bs.Parent = b
            tabButtons[name] = b
            b.MouseButton1Click:Connect(function() SelectTab(name) end)
        end

        CreatePage("ESP")
        CreatePage("AIMBOT")
        CreatePage("OUTROS")

        CreateTabButton("ESP", "ESP")
        CreateTabButton("AIMBOT", "AIMBOT")
        CreateTabButton("OUTROS", "OUTROS")

        local bDrag, bMoved, bStart, bStartPos = false, false, nil, nil
        btnOpen.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                bDrag = true; bMoved = false
                bStart = input.Position; bStartPos = btnOpen.Position
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if bDrag and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local delta = input.Position - bStart
                if math.abs(delta.X) > 5 or math.abs(delta.Y) > 5 then bMoved = true end
                btnOpen.Position = UDim2.new(bStartPos.X.Scale, bStartPos.X.Offset + delta.X, bStartPos.Y.Scale, bStartPos.Y.Offset + delta.Y)
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                bDrag = false
            end
        end)
        btnOpen.MouseButton1Click:Connect(function()
            if not bMoved then MainFrame.Visible = not MainFrame.Visible end
        end)

        local mDrag, mStart, mStartPos = false, nil, nil
        Header.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                mDrag = true; mStart = input.Position; mStartPos = MainFrame.Position
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if mDrag and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local delta = input.Position - mStart
                MainFrame.Position = UDim2.new(mStartPos.X.Scale, mStartPos.X.Offset + delta.X, mStartPos.Y.Scale, mStartPos.Y.Offset + delta.Y)
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                mDrag = false
            end
        end)

        local function CreateToggle(parent, name, labelText, callback, initial)
            local f = Instance.new("Frame")
            f.Size = UDim2.new(1, 0, 0, 30)
            f.BackgroundColor3 = DARK_BG2
            f.BorderSizePixel = 0
            f.Parent = parent
            local fc = Instance.new("UICorner"); fc.CornerRadius = UDim.new(0, 6); fc.Parent = f
            local fs = Instance.new("UIStroke"); fs.Color = BLUE; fs.Thickness = 1; fs.Transparency = 0.7; fs.Parent = f

            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(0, 150, 1, 0); lbl.Position = UDim2.new(0, 10, 0, 0)
            lbl.BackgroundTransparency = 1; lbl.Text = labelText
            lbl.TextColor3 = TEXT_WHITE; lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.Font = Enum.Font.GothamMedium; lbl.TextSize = 12; lbl.Parent = f

            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(0, 55, 0, 20); btn.Position = UDim2.new(1, -65, 0.5, -10)
            btn.BackgroundColor3 = DARK_BG
            btn.Text = "OFF"; btn.TextColor3 = Color3.fromRGB(255, 80, 80)
            btn.Font = Enum.Font.GothamBold; btn.TextSize = 11; btn.Parent = f
            local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0, 4); bc.Parent = btn
            local bs = Instance.new("UIStroke"); bs.Color = Color3.fromRGB(255, 80, 80); bs.Thickness = 1; bs.Transparency = 0.5; bs.Parent = btn

            local state = initial
            if state == nil then state = false end
            local function upd()
                if state then
                    btn.Text = "ON"; btn.TextColor3 = Color3.new(1, 1, 1)
                    btn.BackgroundColor3 = BLUE
                    bs.Color = BLUE_LIGHT
                    bs.Transparency = 0
                else
                    btn.Text = "OFF"; btn.TextColor3 = Color3.fromRGB(255, 80, 80)
                    btn.BackgroundColor3 = DARK_BG
                    bs.Color = Color3.fromRGB(255, 80, 80)
                    bs.Transparency = 0.5
                end
                if callback then callback(state)
                elseif name == "Aimbot" then aimbotEnabled = state
                elseif name == "Noclip" then noclipEnabled = state
                elseif name == "VFly" then
                    VflyEnabled = state
                    if state then EnableVFly() else DisableVFly() end
                elseif name == "InvisPlayers" then
                    espEnabled.InvisPlayers = state
                    if state then
                        UpdateInvisForAll()
                    else
                        RevertAllInvis()
                    end
                else espEnabled[name] = state end
            end
            upd()
            btn.MouseButton1Click:Connect(function() state = not state; upd() end)
            return f
        end

        local function CreateNumericControl(parent, titleText, minVal, maxVal, step, initialVal, onChange)
            local f = Instance.new("Frame")
            f.Size = UDim2.new(1, 0, 0, 32)
            f.BackgroundColor3 = DARK_BG2
            f.BorderSizePixel = 0
            f.Parent = parent
            local fc = Instance.new("UICorner"); fc.CornerRadius = UDim.new(0, 6); fc.Parent = f
            local fs = Instance.new("UIStroke"); fs.Color = BLUE; fs.Thickness = 1; fs.Transparency = 0.7; fs.Parent = f

            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(0, 130, 1, 0); lbl.Position = UDim2.new(0, 10, 0, 0)
            lbl.BackgroundTransparency = 1; lbl.Text = titleText
            lbl.TextColor3 = TEXT_WHITE; lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.Font = Enum.Font.GothamMedium; lbl.TextSize = 12; lbl.Parent = f

            local num = Instance.new("TextLabel")
            num.Size = UDim2.new(0, 40, 1, 0); num.Position = UDim2.new(1, -105, 0, 0)
            num.BackgroundTransparency = 1; num.Text = tostring(initialVal)
            num.TextColor3 = BLUE; num.TextXAlignment = Enum.TextXAlignment.Right
            num.Font = Enum.Font.GothamBold; num.TextSize = 14; num.Parent = f

            local bMinus = Instance.new("TextButton")
            bMinus.Size = UDim2.new(0, 25, 0, 22); bMinus.Position = UDim2.new(1, -55, 0.5, -11)
            bMinus.BackgroundColor3 = DARK_BG; bMinus.Text = "-"
            bMinus.TextColor3 = TEXT_WHITE; bMinus.Font = Enum.Font.GothamBold
            bMinus.TextSize = 14; bMinus.Parent = f
            local mc = Instance.new("UICorner"); mc.CornerRadius = UDim.new(0, 4); mc.Parent = bMinus

            local bPlus = Instance.new("TextButton")
            bPlus.Size = UDim2.new(0, 25, 0, 22); bPlus.Position = UDim2.new(1, -28, 0.5, -11)
            bPlus.BackgroundColor3 = DARK_BG; bPlus.Text = "+"
            bPlus.TextColor3 = TEXT_WHITE; bPlus.Font = Enum.Font.GothamBold
            bPlus.TextSize = 14; bPlus.Parent = f
            local pc = Instance.new("UICorner"); pc.CornerRadius = UDim.new(0, 4); pc.Parent = bPlus

            local val = initialVal
            local function apply(v)
                val = v; num.Text = tostring(val)
                if onChange then onChange(val) end
            end
            bPlus.MouseButton1Click:Connect(function()
                if val + step <= maxVal then apply(val + step) end
            end)
            bMinus.MouseButton1Click:Connect(function()
                if val - step >= minVal then apply(val - step) end
            end)
        end

        local function CreateBodyPartSelection(parent)
            local f = Instance.new("Frame")
            f.Size = UDim2.new(1, 0, 0, 32)
            f.BackgroundColor3 = DARK_BG2
            f.BorderSizePixel = 0
            f.Parent = parent
            local fc = Instance.new("UICorner"); fc.CornerRadius = UDim.new(0, 6); fc.Parent = f
            local fs = Instance.new("UIStroke"); fs.Color = BLUE; fs.Thickness = 1; fs.Transparency = 0.7; fs.Parent = f

            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(0, 130, 1, 0); lbl.Position = UDim2.new(0, 10, 0, 0)
            lbl.BackgroundTransparency = 1; lbl.Text = "Mira no Corpo:"
            lbl.TextColor3 = TEXT_WHITE; lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.Font = Enum.Font.GothamMedium; lbl.TextSize = 12; lbl.Parent = f

            local dd = Instance.new("TextButton")
            dd.Size = UDim2.new(0, 85, 0, 22); dd.Position = UDim2.new(1, -95, 0.5, -11)
            dd.BackgroundColor3 = DARK_BG; dd.Text = aimTarget
            dd.TextColor3 = BLUE; dd.Font = Enum.Font.GothamBold
            dd.TextSize = 11; dd.Parent = f
            local dc = Instance.new("UICorner"); dc.CornerRadius = UDim.new(0, 4); dc.Parent = dd
            local ds = Instance.new("UIStroke"); ds.Color = BLUE; ds.Thickness = 1; ds.Transparency = 0.5; ds.Parent = dd

            local opts = {"Cabeça", "Peito"}; local idx = 1
            for i, o in ipairs(opts) do if o == aimTarget then idx = i end end
            dd.MouseButton1Click:Connect(function()
                idx = idx + 1
                if idx > #opts then idx = 1 end
                aimTarget = opts[idx]; dd.Text = aimTarget
            end)
        end

        local function CreatePlayerIgnoreList(parent)
            local sec = Instance.new("Frame")
            sec.Size = UDim2.new(1, 0, 0, 20)
            sec.BackgroundTransparency = 1
            sec.Parent = parent

            local ttl = Instance.new("TextLabel")
            ttl.Size = UDim2.new(1, 0, 1, 0); ttl.BackgroundTransparency = 1
            ttl.Text = "=== IGNORAR NO AIMBOT ==="
            ttl.TextColor3 = BLUE
            ttl.Font = Enum.Font.GothamBold; ttl.TextSize = 11; ttl.Parent = sec

            local sf = Instance.new("Frame")
            sf.Size = UDim2.new(1, 0, 0, 28)
            sf.BackgroundColor3 = DARK_BG2
            sf.BorderSizePixel = 0
            sf.Parent = parent
            local sc = Instance.new("UICorner"); sc.CornerRadius = UDim.new(0, 6); sc.Parent = sf
            local ss = Instance.new("UIStroke"); ss.Color = BLUE; ss.Thickness = 1; ss.Transparency = 0.7; ss.Parent = sf

            local sb = Instance.new("TextBox")
            sb.Size = UDim2.new(1, -10, 1, 0); sb.Position = UDim2.new(0, 5, 0, 0)
            sb.BackgroundTransparency = 1; sb.Text = ""
            sb.PlaceholderText = "🔍 Pesquisar player..."
            sb.PlaceholderColor3 = TEXT_DIM
            sb.TextColor3 = TEXT_WHITE; sb.Font = Enum.Font.Gotham
            sb.TextSize = 12; sb.TextXAlignment = Enum.TextXAlignment.Left
            sb.ClearTextOnFocus = false; sb.Parent = sf

            local cont = Instance.new("Frame")
            cont.Size = UDim2.new(1, 0, 0, 0)
            cont.AutomaticSize = Enum.AutomaticSize.Y
            cont.BackgroundTransparency = 1
            cont.Parent = parent
            local cl = Instance.new("UIListLayout")
            cl.SortOrder = Enum.SortOrder.LayoutOrder
            cl.Padding = UDim.new(0, 3)
            cl.Parent = cont

            local rows = {}

            local function filter()
                local q = string.lower(sb.Text)
                for player, row in pairs(rows) do
                    if player.Parent then
                        row.Visible = (q == "") or string.find(string.lower(player.Name), q, 1, true)
                    end
                end
            end

            local function refresh()
                for player, row in pairs(rows) do
                    if not player.Parent then row:Destroy(); rows[player] = nil end
                end
                for _, player in ipairs(Players:GetPlayers()) do
                    if player ~= LocalPlayer and not rows[player] then
                        local row = Instance.new("Frame")
                        row.Size = UDim2.new(1, 0, 0, 22)
                        row.BackgroundColor3 = DARK_BG2
                        row.BorderSizePixel = 0
                        row.Parent = cont
                        local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(0, 4); rc.Parent = row

                        local nm = Instance.new("TextLabel")
                        nm.Size = UDim2.new(1, -35, 1, 0); nm.Position = UDim2.new(0, 6, 0, 0)
                        nm.BackgroundTransparency = 1; nm.Text = player.Name
                        nm.TextColor3 = TEXT_WHITE; nm.TextXAlignment = Enum.TextXAlignment.Left
                        nm.Font = Enum.Font.Gotham; nm.TextSize = 11
                        nm.TextTruncate = Enum.TextTruncate.AtEnd; nm.Parent = row

                        local chk = Instance.new("TextButton")
                        chk.Size = UDim2.new(0, 20, 0, 20); chk.Position = UDim2.new(1, -24, 0.5, -10)
                        chk.BackgroundColor3 = DARK_BG
                        chk.Text = ""; chk.TextColor3 = Color3.new(1, 1, 1)
                        chk.Font = Enum.Font.GothamBold; chk.TextSize = 12; chk.Parent = row
                        local cc = Instance.new("UICorner"); cc.CornerRadius = UDim.new(0, 4); cc.Parent = chk

                        local state = IsIgnored(player)
                        local function upd()
                            if state then
                                chk.Text = "X"
                                chk.BackgroundColor3 = BLUE
                                chk.TextColor3 = Color3.new(1, 1, 1)
                            else
                                chk.Text = ""
                                chk.BackgroundColor3 = DARK_BG
                            end
                        end
                        upd()
                        chk.MouseButton1Click:Connect(function()
                            state = not state
                            if state then
                                ignoredPlayers[player] = true
                                ignoredPlayers[player.Name] = true
                            else
                                ignoredPlayers[player] = nil
                                ignoredPlayers[player.Name] = nil
                            end
                            upd()
                        end)

                        rows[player] = row
                    end
                end
                filter()
            end

            sb:GetPropertyChangedSignal("Text"):Connect(filter)
            refresh()
            Players.PlayerAdded:Connect(function() task.wait(0.5) refresh() end)
            Players.PlayerRemoving:Connect(function() task.wait(0.2) refresh() end)
        end

        local espPage = pages["ESP"]
        CreateToggle(espPage, "WallChams", "Chams")
        CreateToggle(espPage, "Name", "Nick")
        CreateToggle(espPage, "Distance", "Distancia")
        CreateToggle(espPage, "Skeleton", "Esqueleto")
        CreateToggle(espPage, "InvisPlayers", "Invis Players (75%)")
        CreateToggle(espPage, "TeamCheck", "Team Check (Ignorar Aliados)", function(s) teamCheckEnabled = s end)

        local aimPage = pages["AIMBOT"]
        CreateToggle(aimPage, "Aimbot", "Ativar Aimbot")
        CreateNumericControl(aimPage, "Nível Aimbot", 1, 50, 1, aimbotLevel, function(v) aimbotLevel = v end)
        CreateNumericControl(aimPage, "Tamanho FOV", 10, 500, 5, fovSize, function(v) fovSize = v end)
        CreateBodyPartSelection(aimPage)
        CreatePlayerIgnoreList(aimPage)

        local outrosPage = pages["OUTROS"]
        CreateToggle(outrosPage, "Noclip", "Noclip")
        CreateToggle(outrosPage, "VFly", "VFly (Veículo)")
        CreateNumericControl(outrosPage, "Velocidade VFly", 10, 300, 5, FlySpeed, function(v) FlySpeed = v end)

        local function CreateResolutionControl(parent)
            local f = Instance.new("Frame")
            f.Size = UDim2.new(1, 0, 0, 32)
            f.BackgroundColor3 = DARK_BG2
            f.BorderSizePixel = 0
            f.Parent = parent
            local fc = Instance.new("UICorner"); fc.CornerRadius = UDim.new(0, 6); fc.Parent = f
            local fs = Instance.new("UIStroke"); fs.Color = BLUE; fs.Thickness = 1; fs.Transparency = 0.7; fs.Parent = f

            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(0, 130, 1, 0); lbl.Position = UDim2.new(0, 10, 0, 0)
            lbl.BackgroundTransparency = 1; lbl.Text = "Resolução (%)"
            lbl.TextColor3 = TEXT_WHITE; lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.Font = Enum.Font.GothamMedium; lbl.TextSize = 12; lbl.Parent = f

            local num = Instance.new("TextLabel")
            num.Size = UDim2.new(0, 40, 1, 0); num.Position = UDim2.new(1, -105, 0, 0)
            num.BackgroundTransparency = 1; num.Text = tostring(panelScale)
            num.TextColor3 = BLUE; num.TextXAlignment = Enum.TextXAlignment.Right
            num.Font = Enum.Font.GothamBold; num.TextSize = 14; num.Parent = f

            local bMinus = Instance.new("TextButton")
            bMinus.Size = UDim2.new(0, 25, 0, 22); bMinus.Position = UDim2.new(1, -55, 0.5, -11)
            bMinus.BackgroundColor3 = DARK_BG; bMinus.Text = "-"
            bMinus.TextColor3 = TEXT_WHITE; bMinus.Font = Enum.Font.GothamBold
            bMinus.TextSize = 14; bMinus.Parent = f
            local mc = Instance.new("UICorner"); mc.CornerRadius = UDim.new(0, 4); mc.Parent = bMinus

            local bPlus = Instance.new("TextButton")
            bPlus.Size = UDim2.new(0, 25, 0, 22); bPlus.Position = UDim2.new(1, -28, 0.5, -11)
            bPlus.BackgroundColor3 = DARK_BG; bPlus.Text = "+"
            bPlus.TextColor3 = TEXT_WHITE; bPlus.Font = Enum.Font.GothamBold
            bPlus.TextSize = 14; bPlus.Parent = f
            local pc = Instance.new("UICorner"); pc.CornerRadius = UDim.new(0, 4); pc.Parent = bPlus

            bPlus.MouseButton1Click:Connect(function()
                if panelScale + 5 <= 200 then
                    panelScale = panelScale + 5
                    uiScale.Scale = panelScale / 100
                    num.Text = tostring(panelScale)
                end
            end)
            bMinus.MouseButton1Click:Connect(function()
                if panelScale - 5 >= 50 then
                    panelScale = panelScale - 5
                    uiScale.Scale = panelScale / 100
                    num.Text = tostring(panelScale)
                end
            end)
        end

        CreateResolutionControl(outrosPage)

        local footer = Instance.new("Frame")
        footer.Size = UDim2.new(1, 0, 0, 30)
        footer.BackgroundColor3 = DARK_BG2
        footer.BorderSizePixel = 0
        footer.Parent = outrosPage
        local fcFooter = Instance.new("UICorner"); fcFooter.CornerRadius = UDim.new(0, 6); fcFooter.Parent = footer
        local fsFooter = Instance.new("UIStroke"); fsFooter.Color = BLUE; fsFooter.Thickness = 1; fsFooter.Transparency = 0.7; fcFooter.Parent = footer

        local dSym = Instance.new("TextLabel")
        dSym.Size = UDim2.new(0, 25, 1, 0); dSym.Position = UDim2.new(0, 5, 0, 0)
        dSym.BackgroundTransparency = 1; dSym.Text = "D"
        dSym.TextColor3 = BLUE; dSym.Font = Enum.Font.GothamBold
        dSym.TextSize = 18; dSym.Parent = footer

        local dBtn = Instance.new("TextButton")
        dBtn.Size = UDim2.new(1, -35, 1, 0); dBtn.Position = UDim2.new(0, 30, 0, 0)
        dBtn.BackgroundTransparency = 1
        dBtn.Text = "https://discord.gg/HpJCTwTSeS"
        dBtn.TextColor3 = BLUE
        dBtn.TextXAlignment = Enum.TextXAlignment.Left
        dBtn.Font = Enum.Font.GothamBold; dBtn.TextSize = 11; dBtn.Parent = footer
        dBtn.MouseButton1Click:Connect(function()
            if setclipboard then
                setclipboard("https://discord.gg/HpJCTwTSeS")
                dBtn.Text = "Copiado! ✓"
                task.wait(1.5)
                dBtn.Text = "https://discord.gg/HpJCTwTSeS"
            end
        end)

        SelectTab("ESP")

        local ControlsFrame = Instance.new("Frame", ScreenGui)
        ControlsFrame.Size = UDim2.new(1, 0, 1, 0)
        ControlsFrame.BackgroundTransparency = 1
        ControlsFrame.Visible = false
        ControlsFrame.ZIndex = 8

        local function createBtn(n, t, p)
            local b = Instance.new("TextButton", ControlsFrame)
            b.Text, b.Position, b.Size = t, p, UDim2.new(0, 80, 0, 60)
            b.BackgroundColor3 = DARK_BG
            b.TextColor3 = BLUE
            b.Font = Enum.Font.GothamBold
            b.TextSize = 14
            local bc = Instance.new("UICorner", b); bc.CornerRadius = UDim.new(0, 10)
            local bs = Instance.new("UIStroke", b); bs.Color = BLUE; bs.Thickness = 2
            b.MouseButton1Down:Connect(function() vflyInputs[n] = true end)
            b.MouseButton1Up:Connect(function() vflyInputs[n] = false end)
            b.MouseLeave:Connect(function() vflyInputs[n] = false end)
        end
        createBtn("Gas", "GÁS", UDim2.new(0.8, 0, 0.65, 0))
        createBtn("Re", "RÉ", UDim2.new(0.7, 0, 0.72, 0))

        RunService.RenderStepped:Connect(function()
            ControlsFrame.Visible = VflyEnabled and MainFrame.Visible
        end)

        print("DJ MENU carregado!")
    end)

    if not ok then
        warn("[DJ MENU] Erro ao criar GUI: " .. tostring(err))
    end
end

--// ===== EXECUTA ANIMAÇÃO E DEPOIS MONTA O GUI =====
PlayIntro(function()
    BuildGUI()
end)
