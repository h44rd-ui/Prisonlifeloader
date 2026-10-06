--[[
    Painel Rkz | Paid version
    Interface: WindUI
    By Elton
]]

local WindUI
local winduiUrls = {
    "https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua",
    "https://github.com/Footagesus/WindUI/releases/latest/download/main.lua",
    "https://raw.githubusercontent.com/Footagesus/WindUI/refs/heads/main/dist/main.lua",
}

for _, url in ipairs(winduiUrls) do
    local ok, result = pcall(function()
        return loadstring(game:HttpGet(url))()
    end)
    if ok and result and type(result) == "table" and result.CreateWindow then
        WindUI = result
        break
    end
end

if not WindUI then
    error("[RKZ Hub] Falha ao carregar WindUI. Verifique se seu executor permite HttpGet / loadstring.")
end

local Window = WindUI:CreateWindow({
    Title = "Painel Rkz | Paid version",
    Icon = "shield",
    Author = "By Elton",
    Folder = "RKZHUB/PAID",
    Theme = "Dark",
    Size = UDim2.fromOffset(580, 460),
    MinSize = Vector2.new(500, 350),
    MaxSize = Vector2.new(900, 650),
    Resizable = true,
    Transparent = true,
})

-- ==================== SERVICES & HELPERS ====================
local function missing(expectedType, value, fallback)
    if type(value) == expectedType then
        return value
    end
    return fallback
end

local safeCloneref = missing("function", cloneref, function(value)
    return value
end)

local function getService(serviceName)
    return safeCloneref(game:GetService(serviceName))
end

local Players = getService("Players")
local TextChatService = getService("TextChatService")
local UserInputService = getService("UserInputService")
local RunService = getService("RunService")
local ReplicatedStorage = getService("ReplicatedStorage")
local Teams = getService("Teams")
local TweenService = getService("TweenService")
local PathfindingService = getService("PathfindingService")
local HttpService = getService("HttpService")

local LocalPlayer = safeCloneref(Players.LocalPlayer)
local Camera = workspace.CurrentCamera

local MainControls = {}
local RageControls = {}
local VisualControls = {}

-- ==================== BYPASS ====================
local RemoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
local RemotesToBlock = {
    "BanServer",
    "ClientKick",
    "BanTemp",
    "AntiServer"
}
local RemoteList = {}

for _, name in ipairs(RemotesToBlock) do
    local r = RemoteEvents and RemoteEvents:FindFirstChild(name)
    if r and (r:IsA("RemoteEvent") or r:IsA("RemoteFunction")) then
        table.insert(RemoteList, r)
    end
end

for _, remote in ipairs(RemoteList) do
    if hookfunction and newcclosure and remote.FireServer then
        pcall(function()
            local old = remote.FireServer
            remote.FireServer = hookfunction(old, newcclosure(function(self, ...)
                return
            end))
        end)
    end
end

if hookmetamethod and getnamecallmethod and newcclosure then
    pcall(function()
        local oldNamecall
        oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
            local method = getnamecallmethod()
            if method == "FireServer" or method == "InvokeServer" then
                for _, remote in ipairs(RemoteList) do
                    if self == remote then
                        return
                    end
                end
            end
            return oldNamecall(self, ...)
        end))
    end)
end

WindUI:Notify({
    Title = "Hello",
    Content = "Welcome to the paid version " .. LocalPlayer.Name .. "!",
    Duration = 3,
})

-- ==================== CHARACTER HELPERS ====================
local function getChar()
    return LocalPlayer.Character
end

local function getRootPart()
    local char = getChar()
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
    local char = getChar()
    return char and char:FindFirstChild("Humanoid")
end

local function isLocalCharacter(character)
    local localCharacter = getChar()
    return character ~= nil and localCharacter ~= nil and character == localCharacter
end

local function isPlayerTargetable(player)
    local localCharacter = getChar()
    if not player or player == LocalPlayer then
        return false
    end
    if LocalPlayer and player.UserId ~= 0 and player.UserId == LocalPlayer.UserId then
        return false
    end
    if player.Character and localCharacter and player.Character == localCharacter then
        return false
    end
    return true
end

local function getPlayerList()
    local list = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(list, player.Name)
        end
    end
    table.sort(list)
    return list
end

local function getTeamList()
    local list = {}
    for _, team in ipairs(Teams:GetTeams()) do
        table.insert(list, team.Name)
    end
    table.sort(list)
    return list
end

workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    Camera = workspace.CurrentCamera
end)

local function sendMsg(msg)
    local channel = TextChatService.TextChannels:FindFirstChild("RBXGeneral")
    if channel then
        channel:SendAsync(msg)
    else
        pcall(function()
            game.StarterGui:SetCore("ChatMakeSystemMessage", { Text = msg })
        end)
    end
end

local function createDrawingObject(drawType, properties)
    if not Drawing then
        return nil
    end
    local object = Drawing.new(drawType)
    for key, value in pairs(properties or {}) do
        object[key] = value
    end
    return object
end

local function removeDrawingObject(object)
    if object then
        pcall(function()
            object:Remove()
        end)
    end
end

local ExecutorSupport = {
    Drawing = Drawing ~= nil and type(Drawing.new) == "function",
    Hook = type(hookmetamethod) == "function"
        and type(newcclosure) == "function"
        and type(getnamecallmethod) == "function",
    Getsenv = type(getsenv) == "function",
    Firetouchinterest = type(firetouchinterest) == "function",
    AutoReload = type(getgc) == "function"
        and type(debug) == "table"
        and type(debug.getinfo) == "function",
}

local function notifyMissingExecutorSupport(featureName, requirementText)
    WindUI:Notify({
        Title = "Executor",
        Content = string.format("%s requires %s support.", featureName, requirementText),
        Duration = 3,
    })
end

-- ==================== PROJECTILE KEY ====================
local argsGun = nil
local projectileKeyReceived = false
local cachedClientEvents = ReplicatedStorage:FindFirstChild("ClientEvents")
local cachedSendKey = cachedClientEvents and cachedClientEvents:FindFirstChild("SendKey")
local rageProjectileStatusLabel = nil

local function updateProjectileStatusLabel()
    if rageProjectileStatusLabel and rageProjectileStatusLabel.SetDesc then
        rageProjectileStatusLabel:SetDesc(projectileKeyReceived and "Loaded" or "Carregando aimkill e silent aim, se demorar muito pegue uma arma")
    end
end

local function setProjectileKey(value)
    if value == nil then
        return false
    end
    argsGun = value
    projectileKeyReceived = true
    if getgenv then
        getgenv().ProjectileKey = value
    end
    updateProjectileStatusLabel()
    return true
end

local function getProjectileKey()
    return argsGun
end

if cachedSendKey then
    cachedSendKey.OnClientEvent:Connect(function(key)
        if not projectileKeyReceived then
            setProjectileKey(key)
        end
    end)
end

-- ==================== STATES ====================
local killAuraEnabled = false
local killAuraMaxDistance = 500
local killAuraIgnoreTeams = {}
local killAuraIgnorePlayers = {}
local killAuraHighlights = {}
local killAuraHighlightThread = nil
local killAuraShowTargets = false

local silentAimEnabled = false
local silentAimTargetPart = "Head"
local silentAimIgnoreTeams = {}
local silentAimIgnorePlayers = {}
local silentAimMaxDistance = 500
local silentAimFOVMode = "Mouse"
local silentAimFOVRadius = 150
local silentAimFOVVisible = false
local silentAimFOVColor = Color3.fromRGB(255, 0, 0)
local silentAimFOVAlpha = 1
local silentAimFOVCircle = nil

local AimbotState = {
    Enabled = false,
    AimMode = "Mouse",
    TargetPart = "Head",
    Smoothness = 0.14,
    FOVMode = "Mouse",
    FOVRadius = 150,
    FOVVisible = false,
    FOVColor = Color3.fromRGB(255, 255, 255),
    FOVAlpha = 1,
    MaxDistance = 500,
    TeamCheck = true,
    WallCheck = false,
    CurrentTarget = nil,
    FOVCircle = nil,
}

local ESPState = {
    Enabled = false,
    IgnoreTeams = {},
    ShowBox = false,
    BoxColor = Color3.fromRGB(255, 255, 255),
    BoxAlpha = 1,
    ShowName = false,
    NameColor = Color3.fromRGB(255, 255, 255),
    NameAlpha = 1,
    ShowDistance = false,
    DistanceColor = Color3.fromRGB(255, 255, 255),
    DistanceAlpha = 1,
    ShowTool = false,
    ToolColor = Color3.fromRGB(255, 255, 255),
    ToolAlpha = 1,
    ShowTracers = false,
    TracerColor = Color3.fromRGB(255, 255, 255),
    TracerAlpha = 1,
    TracerOrigin = "Bottom",
    ShowChams = false,
    ChamsColor = Color3.fromRGB(255, 103, 24),
    ChamsAlpha = 0.35,
    Entries = {},
    Connection = nil,
}

local EggESPState = {
    Enabled = false,
    Color = Color3.fromRGB(255, 255, 255),
    Drawings = {},
    Connection = nil,
    ChildAddedConnection = nil,
    ChildRemovedConnection = nil,
}

local infiniteAmmoEnabled = false
local infiniteAmmoLoopThread = nil
local autoReloadEnabled = false
local autoReloadLoopThread = nil
local cachedReloadFunction = nil
local autoReloadLastTrigger = 0
local infiniteJumpEnabled = false
local infJumpConnection = nil
local infJumpDebounce = false
local spinbotEnabled = false
local spinbotSpeed = 180
local recoilRemovalApplied = false
local hitboxExpanderEnabled = false
local hitboxExpanderSize = 5
local hitboxExpanderPart = "HumanoidRootPart"
local hitboxExpanderTransparency = 1
local hitboxExpanderIgnoreTeams = {}
local hitboxExpanderIgnorePlayers = {}
local originalSizes = {}
local originalTransparencies = {}
local originalCanCollides = {}

local RecruitState = {
    AutoVolvers = false,
    InstructorName = "",
    JJsStartNumber = 1,
    JJsEndNumber = 10,
    JJsSuffix = "!",
    JJsWaitTime = 1.5,
    JJsReverseMode = false,
    JJsRunning = false,
    ChatConnections = {},
    JJsPlayToggle = nil,
}

local musicSound = workspace:FindFirstChild("MusicVisualSound") or Instance.new("Sound")
local musicId = ""
local recruitUnits = { "", "UM", "DOIS", "TRES", "QUATRO", "CINCO", "SEIS", "SETE", "OITO", "NOVE" }
local recruitSpecials = { "DEZ", "ONZE", "DOZE", "TREZE", "QUATORZE", "QUINZE", "DEZESSEIS", "DEZESSETE", "DEZOITO", "DEZENOVE" }
local recruitTens = { "", "", "VINTE", "TRINTA", "QUARENTA", "CINQUENTA", "SESSENTA", "SETENTA", "OITENTA", "NOVENTA" }
local recruitHundreds = { "", "CEM", "DUZENTOS", "TREZENTOS", "QUATROCENTOS", "QUINHENTOS", "SEISCENTOS", "SETECENTOS", "OITOCENTOS", "NOVECENTOS" }

musicSound.Name = "MusicVisualSound"
musicSound.Volume = 2
musicSound.Looped = true
musicSound.Parent = workspace

local ignoredTools = {
    "Descansar", "Continência", "Segurar", "Prancheta", "Feijões de tom",
    "Check", "Recrutamento", "Moto"
}

local function isSelected(filterTable, value)
    if type(filterTable) ~= "table" then
        return filterTable == value
    end
    if filterTable[value] ~= nil then
        return filterTable[value] == true
    end
    for _, v in ipairs(filterTable) do
        if v == value then
            return true
        end
    end
    return false
end

local function isToolIgnored(tool)
    for _, name in ipairs(ignoredTools) do
        if tool.Name == name then
            return true
        end
    end
    return false
end

-- ==================== KILL AURA ====================
local function getKillAuraTargets()
    local hrp = getRootPart()
    if not hrp then return {} end
    local localCharacter = getChar()
    local list = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if isPlayerTargetable(player) and player.Character then
            if player.Team and isSelected(killAuraIgnoreTeams, player.Team.Name) then continue end
            if isSelected(killAuraIgnorePlayers, player.Name) then continue end
            local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
            if not humanoid or humanoid.Health <= 0 then continue end
            local equippedTool = player.Character:FindFirstChildWhichIsA("Tool")
            if not equippedTool or isToolIgnored(equippedTool) then continue end
            local targetPart = player.Character:FindFirstChild("Head") or player.Character:FindFirstChild("HumanoidRootPart")
            if targetPart and (not localCharacter or not targetPart:IsDescendantOf(localCharacter)) then
                local distance = (targetPart.Position - hrp.Position).Magnitude
                if distance <= killAuraMaxDistance then
                    table.insert(list, {
                        plr = player,
                        part = targetPart,
                        distance = distance,
                        character = player.Character,
                    })
                end
            end
        end
    end
    table.sort(list, function(a, b) return a.distance < b.distance end)
    return list
end

local function clearKillAuraHighlights()
    for _, highlight in pairs(killAuraHighlights) do
        if highlight and highlight.Parent then
            highlight:Destroy()
        end
    end
    killAuraHighlights = {}
end

local function updateKillAuraHighlights()
    if not killAuraShowTargets then return end
    local currentTargets = {}
    for _, targetData in ipairs(getKillAuraTargets()) do
        currentTargets[targetData.plr.UserId] = targetData.character
    end
    for userId, highlight in pairs(killAuraHighlights) do
        if not currentTargets[userId] then
            if highlight and highlight.Parent then highlight:Destroy() end
            killAuraHighlights[userId] = nil
        end
    end
    for userId, character in pairs(currentTargets) do
        if not killAuraHighlights[userId] or not killAuraHighlights[userId].Parent then
            local highlight = Instance.new("Highlight")
            highlight.FillColor = Color3.fromRGB(255, 0, 0)
            highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
            highlight.FillTransparency = 0.5
            highlight.OutlineTransparency = 0
            highlight.Parent = character
            killAuraHighlights[userId] = highlight
        end
    end
end

-- ==================== SILENT AIM ====================
local function getSilentAimFOVPosition()
    if silentAimFOVMode == "Mouse" then
        return UserInputService:GetMouseLocation()
    end
    return Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
end

local function createSilentAimFOVCircle()
    if not Drawing then return nil end
    if silentAimFOVCircle then silentAimFOVCircle:Remove() end
    silentAimFOVCircle = Drawing.new("Circle")
    silentAimFOVCircle.Thickness = 2
    silentAimFOVCircle.NumSides = 64
    silentAimFOVCircle.Radius = silentAimFOVRadius
    silentAimFOVCircle.Filled = false
    silentAimFOVCircle.Color = silentAimFOVColor
    silentAimFOVCircle.Transparency = silentAimFOVAlpha
    silentAimFOVCircle.Visible = silentAimFOVVisible
    silentAimFOVCircle.Position = getSilentAimFOVPosition()
    return silentAimFOVCircle
end

local function updateSilentAimFOVCircle()
    if silentAimFOVCircle then
        silentAimFOVCircle.Position = getSilentAimFOVPosition()
        silentAimFOVCircle.Radius = silentAimFOVRadius
        silentAimFOVCircle.Color = silentAimFOVColor
        silentAimFOVCircle.Transparency = silentAimFOVAlpha
        silentAimFOVCircle.Visible = silentAimFOVVisible
    end
end

local function isInSilentAimFOV(targetPosition)
    local screenPoint, onScreen = Camera:WorldToViewportPoint(targetPosition)
    if not onScreen then return false end
    local targetPoint = Vector2.new(screenPoint.X, screenPoint.Y)
    local distance = (getSilentAimFOVPosition() - targetPoint).Magnitude
    return distance <= silentAimFOVRadius
end

local function getSilentAimTargets()
    local hrp = getRootPart()
    if not hrp then return {} end
    local localCharacter = getChar()
    local list = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if isPlayerTargetable(player) and player.Character then
            if player.Team and isSelected(silentAimIgnoreTeams, player.Team.Name) then continue end
            if isSelected(silentAimIgnorePlayers, player.Name) then continue end
            local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
            if not humanoid or humanoid.Health <= 0 then continue end
            local equippedTool = player.Character:FindFirstChildWhichIsA("Tool")
            if not equippedTool or isToolIgnored(equippedTool) then continue end
            local targetPart = player.Character:FindFirstChild(silentAimTargetPart)
            if targetPart and (not localCharacter or not targetPart:IsDescendantOf(localCharacter)) then
                local distance = (targetPart.Position - hrp.Position).Magnitude
                if distance <= silentAimMaxDistance and isInSilentAimFOV(targetPart.Position) then
                    table.insert(list, {
                        plr = player,
                        part = targetPart,
                        distance = distance,
                    })
                end
            end
        end
    end
    table.sort(list, function(a, b) return a.distance < b.distance end)
    return list
end

if Drawing then
    createSilentAimFOVCircle()
    task.spawn(function()
        while task.wait() do
            pcall(updateSilentAimFOVCircle)
        end
    end)
end

if hookmetamethod and newcclosure then
    local damageRemote = ReplicatedStorage:FindFirstChild("ServerEvents")
        and ReplicatedStorage.ServerEvents:FindFirstChild("_Projectile")
    local projectileRemote = ReplicatedStorage:FindFirstChild("ServerEvents")
        and ReplicatedStorage.ServerEvents:FindFirstChild("Projectile")
    local lastSilentAimShot = 0

    if damageRemote and projectileRemote then
        local oldSilentNamecall
        oldSilentNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
            local method = getnamecallmethod()
            if method ~= "FireServer" then
                return oldSilentNamecall(self, ...)
            end
            local trigger = (self.Name == "Fire" and self.Parent and self.Parent.Name == "Core")
                or self == projectileRemote
            if silentAimEnabled and trigger then
                local currentTime = tick()
                if (currentTime - lastSilentAimShot) > 0.05 then
                    lastSilentAimShot = currentTime
                    task.spawn(function()
                        local projectileKey = getProjectileKey()
                        local targetData = getSilentAimTargets()[1]
                        if targetData then
                            local currentCharacter = getChar()
                            local currentWeapon = currentCharacter and currentCharacter:FindFirstChildWhichIsA("Tool")
                            local animation = currentWeapon and currentWeapon:FindFirstChild("Animation")
                            local bullet = animation and animation:FindFirstChild("BulletDamage")
                            if projectileKey and bullet then
                                damageRemote:FireServer(projectileKey, bullet, targetData.part, targetData.plr)
                            end
                        end
                    end)
                end
            end
            return oldSilentNamecall(self, ...)
        end))
    end
end

-- ==================== AIMBOT ====================
local function getAimbotFOVPosition()
    if AimbotState.FOVMode == "Mouse" then
        return UserInputService:GetMouseLocation()
    end
    return Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
end

local function isAimbotTargetVisible(targetPart)
    if not targetPart then return false end
    local character = getChar()
    if not character then return false end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = { character }
    params.FilterType = Enum.RaycastFilterType.Blacklist
    local direction = targetPart.Position - Camera.CFrame.Position
    local result = workspace:Raycast(Camera.CFrame.Position, direction, params)
    if not result then return true end
    return result.Instance:IsDescendantOf(targetPart.Parent)
end

local function getClosestAimbotTarget()
    local myRoot = getRootPart()
    if not myRoot then return nil end
    if AimbotState.CurrentTarget then
        local currentCharacter = AimbotState.CurrentTarget.Parent
        local currentHumanoid = currentCharacter and currentCharacter:FindFirstChildOfClass("Humanoid")
        if currentHumanoid and currentHumanoid.Health > 0 then
            local screenPoint, visible = Camera:WorldToViewportPoint(AimbotState.CurrentTarget.Position)
            if visible then
                local screenDistance = (Vector2.new(screenPoint.X, screenPoint.Y) - getAimbotFOVPosition()).Magnitude
                local worldDistance = (AimbotState.CurrentTarget.Position - myRoot.Position).Magnitude
                if screenDistance < AimbotState.FOVRadius
                    and worldDistance <= AimbotState.MaxDistance
                    and (not AimbotState.WallCheck or isAimbotTargetVisible(AimbotState.CurrentTarget))
                then
                    return AimbotState.CurrentTarget
                end
            end
        end
        AimbotState.CurrentTarget = nil
    end
    local closest = nil
    local closestScreenDistance = math.huge
    local fovPosition = getAimbotFOVPosition()
    for _, player in ipairs(Players:GetPlayers()) do
        if isPlayerTargetable(player) then
            if AimbotState.TeamCheck and player.Team == LocalPlayer.Team then continue end
            local character = player.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            if character and humanoid and humanoid.Health > 0 then
                local targetPart = character:FindFirstChild(AimbotState.TargetPart)
                if targetPart then
                    local screenPoint, visible = Camera:WorldToViewportPoint(targetPart.Position)
                    if visible then
                        local screenDistance = (Vector2.new(screenPoint.X, screenPoint.Y) - fovPosition).Magnitude
                        local worldDistance = (targetPart.Position - myRoot.Position).Magnitude
                        if screenDistance < AimbotState.FOVRadius and worldDistance <= AimbotState.MaxDistance then
                            if AimbotState.WallCheck and not isAimbotTargetVisible(targetPart) then continue end
                            if screenDistance < closestScreenDistance then
                                closestScreenDistance = screenDistance
                                closest = targetPart
                            end
                        end
                    end
                end
            end
        end
    end
    AimbotState.CurrentTarget = closest
    return closest
end

local function mouseAim(target)
    if not mousemoverel then return end
    local screenPoint, visible = Camera:WorldToViewportPoint(target.Position)
    if not visible then return end
    local mousePosition = UserInputService:GetMouseLocation()
    local deltaX = (screenPoint.X - mousePosition.X) * AimbotState.Smoothness
    local deltaY = (screenPoint.Y - mousePosition.Y) * AimbotState.Smoothness
    mousemoverel(deltaX, deltaY)
end

local function cameraAim(target)
    local cameraPosition = Camera.CFrame.Position
    local targetCFrame = CFrame.lookAt(cameraPosition, target.Position)
    Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, AimbotState.Smoothness)
end

if Drawing then
    AimbotState.FOVCircle = Drawing.new("Circle")
    AimbotState.FOVCircle.Visible = false
    AimbotState.FOVCircle.Thickness = 2
    AimbotState.FOVCircle.Filled = false
    AimbotState.FOVCircle.Radius = AimbotState.FOVRadius
    AimbotState.FOVCircle.Color = AimbotState.FOVColor
    AimbotState.FOVCircle.Transparency = AimbotState.FOVAlpha
end

-- ==================== HITBOX EXPANDER ====================
local function expandHitbox(player)
    if not isPlayerTargetable(player) then return end
    if player.Team and isSelected(hitboxExpanderIgnoreTeams, player.Team.Name) then return end
    if isSelected(hitboxExpanderIgnorePlayers, player.Name) then return end
    local character = player.Character
    if not character then return end
    local part = character:FindFirstChild(hitboxExpanderPart)
    if not part or not part:IsA("BasePart") then return end
    if not originalSizes[part] then
        originalSizes[part] = part.Size
        originalTransparencies[part] = part.Transparency
        originalCanCollides[part] = part.CanCollide
    end
    part.Size = originalSizes[part] * Vector3.new(hitboxExpanderSize, hitboxExpanderSize, hitboxExpanderSize)
    part.Transparency = hitboxExpanderTransparency
    part.CanCollide = false
end

local function restoreHitboxPart(part)
    if not part or not originalSizes[part] then return end
    part.Size = originalSizes[part]
    part.Transparency = originalTransparencies[part]
    part.CanCollide = originalCanCollides[part]
    originalSizes[part] = nil
    originalTransparencies[part] = nil
    originalCanCollides[part] = nil
end

local function restoreHitbox(player)
    if not player then return end
    local character = player.Character
    if not character then return end
    for _, descendant in ipairs(character:GetDescendants()) do
        if descendant:IsA("BasePart") and originalSizes[descendant] then
            restoreHitboxPart(descendant)
        end
    end
end

local function shouldExpandHitbox(player)
    if not isPlayerTargetable(player) then return false end
    if player.Team and isSelected(hitboxExpanderIgnoreTeams, player.Team.Name) then return false end
    if isSelected(hitboxExpanderIgnorePlayers, player.Name) then return false end
    local character = player.Character
    local part = character and character:FindFirstChild(hitboxExpanderPart)
    return part ~= nil and part:IsA("BasePart")
end

local function restoreAllHitboxes()
    local partsToRestore = {}
    for part in pairs(originalSizes) do
        table.insert(partsToRestore, part)
    end
    for _, part in ipairs(partsToRestore) do
        restoreHitboxPart(part)
    end
end

local function updateHitboxExpander()
    if not hitboxExpanderEnabled then
        restoreAllHitboxes()
        return
    end
    local partsToCheck = {}
    for part in pairs(originalSizes) do
        table.insert(partsToCheck, part)
    end
    for _, part in ipairs(partsToCheck) do
        local character = part.Parent
        local player = character and Players:GetPlayerFromCharacter(character)
        if not part.Parent or not player or not shouldExpandHitbox(player) or part.Name ~= hitboxExpanderPart then
            restoreHitboxPart(part)
        end
    end
    for _, player in ipairs(Players:GetPlayers()) do
        expandHitbox(player)
    end
end

local function startHitboxExpander()
    updateHitboxExpander()
end

local function stopHitboxExpander()
    restoreAllHitboxes()
end

RunService.RenderStepped:Connect(function()
    updateHitboxExpander()
    if AimbotState.FOVCircle then
        AimbotState.FOVCircle.Visible = AimbotState.FOVVisible
        if AimbotState.FOVVisible then
            AimbotState.FOVCircle.Position = getAimbotFOVPosition()
            AimbotState.FOVCircle.Radius = AimbotState.FOVRadius
            AimbotState.FOVCircle.Color = AimbotState.FOVColor
            AimbotState.FOVCircle.Transparency = AimbotState.FOVAlpha
        end
    end
    if not AimbotState.Enabled then
        AimbotState.CurrentTarget = nil
        return
    end
    if not getRootPart() then return end
    local target = getClosestAimbotTarget()
    if target then
        if AimbotState.AimMode == "Mouse" then
            mouseAim(target)
        else
            cameraAim(target)
        end
    end
end)

-- ==================== ESP ====================
local function getTracerOriginPosition()
    if ESPState.TracerOrigin == "Center" then
        return Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    elseif ESPState.TracerOrigin == "Top" then
        return Vector2.new(Camera.ViewportSize.X / 2, 20)
    end
    return Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y - 20)
end

local function getESPEntry(player)
    local userId = player.UserId
    local entry = ESPState.Entries[userId]
    if entry then return entry end
    entry = {
        Player = player,
        Box = createDrawingObject("Square", {
            Visible = false, Filled = false, Thickness = 1.5,
            Color = ESPState.BoxColor, Transparency = ESPState.BoxAlpha,
        }),
        Name = createDrawingObject("Text", {
            Visible = false, Center = true, Outline = true, Size = 13, Font = 2,
            Color = ESPState.NameColor, Transparency = ESPState.NameAlpha,
        }),
        Distance = createDrawingObject("Text", {
            Visible = false, Center = true, Outline = true, Size = 13, Font = 2,
            Color = ESPState.DistanceColor, Transparency = ESPState.DistanceAlpha,
        }),
        Tool = createDrawingObject("Text", {
            Visible = false, Center = true, Outline = true, Size = 13, Font = 2,
            Color = ESPState.ToolColor, Transparency = ESPState.ToolAlpha,
        }),
        Tracer = createDrawingObject("Line", {
            Visible = false, Thickness = 1.5,
            Color = ESPState.TracerColor, Transparency = ESPState.TracerAlpha,
        }),
        Highlight = nil,
    }
    ESPState.Entries[userId] = entry
    return entry
end

local function hideESPEntry(entry)
    if entry.Box then entry.Box.Visible = false end
    if entry.Name then entry.Name.Visible = false end
    if entry.Distance then entry.Distance.Visible = false end
    if entry.Tool then entry.Tool.Visible = false end
    if entry.Tracer then entry.Tracer.Visible = false end
    if entry.Highlight then entry.Highlight.Enabled = false end
end

local function removeESPEntry(entry)
    if not entry then return end
    removeDrawingObject(entry.Box)
    removeDrawingObject(entry.Name)
    removeDrawingObject(entry.Distance)
    removeDrawingObject(entry.Tool)
    removeDrawingObject(entry.Tracer)
    if entry.Highlight then
        entry.Highlight:Destroy()
        entry.Highlight = nil
    end
end

local function clearESPEntries()
    for userId, entry in pairs(ESPState.Entries) do
        removeESPEntry(entry)
        ESPState.Entries[userId] = nil
    end
end

local function getCharacterBoundingBox2D(character)
    local cf, size = character:GetBoundingBox()
    local halfSize = size / 2
    local corners = {
        Vector3.new(-halfSize.X, -halfSize.Y, -halfSize.Z),
        Vector3.new(-halfSize.X, -halfSize.Y, halfSize.Z),
        Vector3.new(-halfSize.X, halfSize.Y, -halfSize.Z),
        Vector3.new(-halfSize.X, halfSize.Y, halfSize.Z),
        Vector3.new(halfSize.X, -halfSize.Y, -halfSize.Z),
        Vector3.new(halfSize.X, -halfSize.Y, halfSize.Z),
        Vector3.new(halfSize.X, halfSize.Y, -halfSize.Z),
        Vector3.new(halfSize.X, halfSize.Y, halfSize.Z),
    }
    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    local visibleCorner = false
    for _, corner in ipairs(corners) do
        local worldPoint = cf:PointToWorldSpace(corner)
        local screenPoint, onScreen = Camera:WorldToViewportPoint(worldPoint)
        if onScreen then
            visibleCorner = true
            minX = math.min(minX, screenPoint.X)
            minY = math.min(minY, screenPoint.Y)
            maxX = math.max(maxX, screenPoint.X)
            maxY = math.max(maxY, screenPoint.Y)
        end
    end
    if not visibleCorner then return nil end
    return Vector2.new(minX, minY), Vector2.new(maxX, maxY)
end

local function updateESPForPlayer(player)
    local entry = getESPEntry(player)
    local localPlayer = LocalPlayer or Players.LocalPlayer
    if not ESPState.Enabled or player == localPlayer or (localPlayer and player.UserId == localPlayer.UserId) then
        hideESPEntry(entry)
        return
    end
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local myRoot = getRootPart()
    if not character or not humanoid or humanoid.Health <= 0 or not root or not myRoot then
        hideESPEntry(entry)
        return
    end
    if player.Team and isSelected(ESPState.IgnoreTeams, player.Team.Name) then
        hideESPEntry(entry)
        return
    end
    local topLeft, bottomRight = getCharacterBoundingBox2D(character)
    local rootScreen, onScreen = Camera:WorldToViewportPoint(root.Position)
    if not topLeft or not onScreen then
        hideESPEntry(entry)
        return
    end
    local width = math.max(2, bottomRight.X - topLeft.X)
    local height = math.max(2, bottomRight.Y - topLeft.Y)
    local centerX = topLeft.X + (width / 2)
    local distance = math.floor((root.Position - myRoot.Position).Magnitude)
    local equippedTool = character:FindFirstChildWhichIsA("Tool")
    if equippedTool and isToolIgnored(equippedTool) then equippedTool = nil end
    local toolOffsetY = ESPState.ShowName and 30 or 16
    if entry.Box then
        entry.Box.Visible = ESPState.ShowBox
        entry.Box.Position = topLeft
        entry.Box.Size = Vector2.new(width, height)
        entry.Box.Color = ESPState.BoxColor
        entry.Box.Transparency = ESPState.BoxAlpha
    end
    if entry.Name then
        entry.Name.Visible = ESPState.ShowName
        entry.Name.Text = player.Name
        entry.Name.Position = Vector2.new(centerX, topLeft.Y - 16)
        entry.Name.Color = ESPState.NameColor
        entry.Name.Transparency = ESPState.NameAlpha
    end
    if entry.Distance then
        entry.Distance.Visible = ESPState.ShowDistance
        entry.Distance.Text = string.format("%sm", distance)
        entry.Distance.Position = Vector2.new(centerX, bottomRight.Y + 2)
        entry.Distance.Color = ESPState.DistanceColor
        entry.Distance.Transparency = ESPState.DistanceAlpha
    end
    if entry.Tool then
        entry.Tool.Visible = ESPState.ShowTool and equippedTool ~= nil
        entry.Tool.Text = equippedTool and equippedTool.Name or ""
        entry.Tool.Position = Vector2.new(centerX, topLeft.Y - toolOffsetY)
        entry.Tool.Color = ESPState.ToolColor
        entry.Tool.Transparency = ESPState.ToolAlpha
    end
    if entry.Tracer then
        entry.Tracer.Visible = ESPState.ShowTracers
        entry.Tracer.From = getTracerOriginPosition()
        entry.Tracer.To = Vector2.new(centerX, bottomRight.Y)
        entry.Tracer.Color = ESPState.TracerColor
        entry.Tracer.Transparency = ESPState.TracerAlpha
    end
    if ESPState.ShowChams then
        if not entry.Highlight then
            entry.Highlight = Instance.new("Highlight")
            entry.Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            entry.Highlight.Parent = character
        end
        entry.Highlight.Adornee = character
        entry.Highlight.FillColor = ESPState.ChamsColor
        entry.Highlight.FillTransparency = 1 - ESPState.ChamsAlpha
        entry.Highlight.OutlineColor = ESPState.ChamsColor
        entry.Highlight.OutlineTransparency = 0.25
        entry.Highlight.Enabled = true
        if entry.Highlight.Parent ~= character then
            entry.Highlight.Parent = character
        end
    elseif entry.Highlight then
        entry.Highlight.Enabled = false
    end
end

local function startESP()
    if ESPState.Connection then
        ESPState.Connection:Disconnect()
        ESPState.Connection = nil
    end
    ESPState.Connection = RunService.RenderStepped:Connect(function()
        local seenUsers = {}
        for _, player in ipairs(Players:GetPlayers()) do
            seenUsers[player.UserId] = true
            updateESPForPlayer(player)
        end
        for userId, entry in pairs(ESPState.Entries) do
            if not seenUsers[userId] then
                removeESPEntry(entry)
                ESPState.Entries[userId] = nil
            end
        end
    end)
end

local function stopESP()
    if ESPState.Connection then
        ESPState.Connection:Disconnect()
        ESPState.Connection = nil
    end
    clearESPEntries()
end

local function refreshESPState()
    local shouldEnable = ESPState.ShowBox
        or ESPState.ShowName
        or ESPState.ShowDistance
        or ESPState.ShowTool
        or ESPState.ShowTracers
        or ESPState.ShowChams
    if shouldEnable == ESPState.Enabled then return end
    ESPState.Enabled = shouldEnable
    if shouldEnable then
        startESP()
    else
        stopESP()
    end
end

-- ==================== EGG ESP ====================
local function getEggESPFolder()
    return workspace:FindFirstChild("Ovos de Páscoa")
        or workspace:FindFirstChild("Ovos de PÃ¡scoa")
end

local function addEggESPPart(part)
    if not part or not part:IsA("MeshPart") or EggESPState.Drawings[part] then return end
    local text = createDrawingObject("Text", {
        Size = 16, Center = true, Outline = true, Visible = false, Font = 2,
        Color = EggESPState.Color,
    })
    if text then EggESPState.Drawings[part] = text end
end

local function removeEggESPPart(part)
    local drawing = EggESPState.Drawings[part]
    if drawing then
        removeDrawingObject(drawing)
        EggESPState.Drawings[part] = nil
    end
end

local function clearEggESP()
    for part, drawing in pairs(EggESPState.Drawings) do
        removeDrawingObject(drawing)
        EggESPState.Drawings[part] = nil
    end
end

local function updateEggESP()
    local character = getChar()
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
    for part, text in pairs(EggESPState.Drawings) do
        if part and part.Parent then
            local position, onScreen = Camera:WorldToViewportPoint(part.Position)
            if onScreen then
                local distance = (rootPart.Position - part.Position).Magnitude
                text.Position = Vector2.new(position.X, position.Y)
                text.Text = string.format("%s [%dm]", part.Name, math.floor(distance))
                text.Color = EggESPState.Color
                text.Visible = true
            else
                text.Visible = false
            end
        else
            removeEggESPPart(part)
        end
    end
end

local function stopEggESP()
    if EggESPState.Connection then
        EggESPState.Connection:Disconnect()
        EggESPState.Connection = nil
    end
    if EggESPState.ChildAddedConnection then
        EggESPState.ChildAddedConnection:Disconnect()
        EggESPState.ChildAddedConnection = nil
    end
    if EggESPState.ChildRemovedConnection then
        EggESPState.ChildRemovedConnection:Disconnect()
        EggESPState.ChildRemovedConnection = nil
    end
    clearEggESP()
end

local function startEggESP()
    stopEggESP()
    local eggsFolder = getEggESPFolder()
    if not eggsFolder then return end
    for _, object in ipairs(eggsFolder:GetChildren()) do
        addEggESPPart(object)
    end
    EggESPState.ChildAddedConnection = eggsFolder.ChildAdded:Connect(addEggESPPart)
    EggESPState.ChildRemovedConnection = eggsFolder.ChildRemoved:Connect(removeEggESPPart)
    EggESPState.Connection = RunService.RenderStepped:Connect(updateEggESP)
end

-- ==================== RECRUIT ====================
local function findPlayerByPrefix(prefix)
    if not prefix or prefix == "" then return nil end
    local loweredPrefix = string.lower(prefix)
    for _, player in ipairs(Players:GetPlayers()) do
        if string.sub(string.lower(player.Name), 1, #loweredPrefix) == loweredPrefix then
            return player
        end
    end
    return nil
end

local function spinRecruitTo(cf)
    local hrp = getRootPart()
    if not hrp then return end
    local tween = TweenService:Create(hrp, TweenInfo.new(0.35, Enum.EasingStyle.Linear), { CFrame = cf })
    tween:Play()
end

local function recruitRightFace()
    local hrp = getRootPart()
    if hrp then spinRecruitTo(hrp.CFrame * CFrame.Angles(0, math.rad(-90), 0)) end
end

local function recruitLeftFace()
    local hrp = getRootPart()
    if hrp then spinRecruitTo(hrp.CFrame * CFrame.Angles(0, math.rad(90), 0)) end
end

local function recruitRearFace()
    local hrp = getRootPart()
    if hrp then spinRecruitTo(hrp.CFrame * CFrame.Angles(0, math.rad(180), 0)) end
end

local function recruitCenterFace(instructor)
    local hrp = getRootPart()
    local targetRoot = instructor and instructor.Character and instructor.Character:FindFirstChild("HumanoidRootPart")
    if not hrp or not targetRoot then return end
    local lookCF = CFrame.lookAt(hrp.Position, Vector3.new(targetRoot.Position.X, hrp.Position.Y, targetRoot.Position.Z))
    spinRecruitTo(lookCF)
end

local function handleRecruitChat(player, message)
    if not RecruitState.AutoVolvers then return end
    if message ~= string.upper(message) then return end
    if string.find(message, " !", 1, true) then return end
    if RecruitState.InstructorName ~= "" and player.Name ~= RecruitState.InstructorName then return end
    if message == "DIREITA VOLVER!" then
        recruitRightFace()
    elseif message == "ESQUERDA VOLVER!" then
        recruitLeftFace()
    elseif message == "RETAGUARDA VOLVER!" then
        recruitRearFace()
    elseif message == "CENTRAL FACE!" then
        recruitCenterFace(player)
    end
end

local function connectRecruitChat(player)
    if player == LocalPlayer or RecruitState.ChatConnections[player] then return end
    RecruitState.ChatConnections[player] = player.Chatted:Connect(function(message)
        handleRecruitChat(player, message)
    end)
end

local function recruitNumberToWords(value)
    if value == 100 then return "CEM" end
    if value == 1000 then return "MIL" end
    if value == 5000 then return "CINCO MIL" end
    local text = ""
    local thousands = math.floor(value / 1000)
    local thousandRemainder = value % 1000
    local hundreds = math.floor(thousandRemainder / 100)
    local hundredRemainder = thousandRemainder % 100
    local tens = math.floor(hundredRemainder / 10)
    local units = hundredRemainder % 10
    if thousands > 0 then
        if thousands == 1 then
            text = "MIL"
        else
            text = recruitUnits[thousands + 1] .. " MIL"
        end
    end
    if hundreds > 0 then
        if text ~= "" then text = text .. " E " end
        text = text .. recruitHundreds[hundreds + 1]
    end
    if hundredRemainder >= 10 and hundredRemainder <= 19 then
        if text ~= "" then text = text .. " E " end
        text = text .. recruitSpecials[hundredRemainder - 9]
    else
        if tens > 0 then
            if text ~= "" then text = text .. " E " end
            text = text .. recruitTens[tens + 1]
        end
        if units > 0 then
            if text ~= "" then text = text .. " E " end
            text = text .. recruitUnits[units + 1]
        end
    end
    return text
end

local function stopRecruitJJs()
    RecruitState.JJsRunning = false
    if RecruitState.JJsPlayToggle and RecruitState.JJsPlayToggle.Set then
        RecruitState.JJsPlayToggle:Set(false)
    end
end

local function runRecruitJJs()
    local startValue = math.clamp(RecruitState.JJsStartNumber, 1, 5000)
    local endValue = math.clamp(RecruitState.JJsEndNumber, 1, 5000)
    local suffix = RecruitState.JJsSuffix or "!"
    local waitTime = math.max(0, RecruitState.JJsWaitTime or 1.5)
    if RecruitState.JJsReverseMode then
        for number = endValue, startValue, -1 do
            if not RecruitState.JJsRunning then break end
            sendMsg(recruitNumberToWords(number) .. suffix)
            task.wait(waitTime)
        end
    else
        for number = startValue, endValue do
            if not RecruitState.JJsRunning then break end
            sendMsg(recruitNumberToWords(number) .. suffix)
            task.wait(waitTime)
        end
    end
    stopRecruitJJs()
end

-- ==================== WEAPON HELPERS ====================
local function setInfiniteAmmoForWeapon(weapon)
    local ammo = weapon and weapon:FindFirstChild("Ammo")
    if not ammo then return end
    pcall(function()
        ammo.MaxValue = 99999
        ammo.Value = 99999
    end)
end

local function applyInfiniteAmmo()
    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    local character = getChar()
    if backpack then
        for _, weapon in ipairs(backpack:GetChildren()) do
            if weapon:IsA("Tool") then setInfiniteAmmoForWeapon(weapon) end
        end
    end
    if character then
        for _, weapon in ipairs(character:GetChildren()) do
            if weapon:IsA("Tool") then setInfiniteAmmoForWeapon(weapon) end
        end
    end
end

local function startInfiniteAmmo()
    if infiniteAmmoLoopThread then return end
    infiniteAmmoLoopThread = task.spawn(function()
        while infiniteAmmoEnabled do
            applyInfiniteAmmo()
            task.wait(0.1)
        end
    end)
end

local function stopInfiniteAmmo()
    if infiniteAmmoLoopThread then
        task.cancel(infiniteAmmoLoopThread)
        infiniteAmmoLoopThread = nil
    end
end

local function isAutoReloadSupported()
    return ExecutorSupport.AutoReload
end

local function findReloadFunction()
    if cachedReloadFunction then return cachedReloadFunction end
    if not isAutoReloadSupported() then return nil end
    local ok, gcObjects = pcall(getgc, true)
    if not ok then ok, gcObjects = pcall(getgc) end
    if not ok or type(gcObjects) ~= "table" then return nil end
    for _, value in pairs(gcObjects) do
        if type(value) == "function" then
            local infoOk, info = pcall(debug.getinfo, value)
            if infoOk and info and info.name == "Reload" then
                cachedReloadFunction = value
                return value
            end
        end
    end
    return nil
end

local function shouldAutoReloadWeapon(tool)
    local ammo = tool and tool:FindFirstChild("Ammo")
    if not ammo then return false end
    local currentAmmo = ammo.Value
    return type(currentAmmo) == "number" and currentAmmo <= 0
end

local function triggerAutoReload()
    local reloadFunction = findReloadFunction()
    if not reloadFunction then return false end
    local ok = pcall(reloadFunction)
    return ok
end

local function getAutoReloadWeapon()
    local character = getChar()
    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    if character then
        for _, tool in ipairs(character:GetChildren()) do
            if tool:IsA("Tool") and shouldAutoReloadWeapon(tool) then return tool end
        end
    end
    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA("Tool") and shouldAutoReloadWeapon(tool) then return tool end
        end
    end
    return nil
end

local function startAutoReload()
    if autoReloadLoopThread then return end
    autoReloadLoopThread = task.spawn(function()
        while autoReloadEnabled do
            local weapon = getAutoReloadWeapon()
            if weapon and (tick() - autoReloadLastTrigger) >= 0.35 then
                if triggerAutoReload() then
                    autoReloadLastTrigger = tick()
                else
                    cachedReloadFunction = nil
                end
            end
            task.wait(0.1)
        end
    end)
end

local function stopAutoReload()
    if autoReloadLoopThread then
        task.cancel(autoReloadLoopThread)
        autoReloadLoopThread = nil
    end
end

local function stopInfiniteJump()
    if infJumpConnection then
        infJumpConnection:Disconnect()
        infJumpConnection = nil
    end
    infJumpDebounce = false
end

local function startInfiniteJump()
    stopInfiniteJump()
    infJumpDebounce = false
    infJumpConnection = UserInputService.JumpRequest:Connect(function()
        if not infiniteJumpEnabled or infJumpDebounce then return end
        local humanoid = getHumanoid()
        if humanoid then
            infJumpDebounce = true
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            task.wait()
            infJumpDebounce = false
        end
    end)
end

local function clearSpinbot(character)
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
    for _, child in ipairs(rootPart:GetChildren()) do
        if child.Name == "Spinning" then child:Destroy() end
    end
end

local function applySpinbot()
    local character = getChar()
    local rootPart = getRootPart()
    if not character or not rootPart then return end
    clearSpinbot(character)
    local spin = Instance.new("BodyAngularVelocity")
    spin.Name = "Spinning"
    spin.Parent = rootPart
    spin.MaxTorque = Vector3.new(0, math.huge, 0)
    spin.AngularVelocity = Vector3.new(0, spinbotSpeed, 0)
end

local function startSpinbot()
    applySpinbot()
end

local function stopSpinbot()
    clearSpinbot(getChar())
end

local function startRecoilRemoval()
    if recoilRemovalApplied then return end
    recoilRemovalApplied = true
    local lastTool = nil
    local env = nil
    RunService.Heartbeat:Connect(function()
        local character = getChar()
        if not character then return end
        local tool = character:FindFirstChildOfClass("Tool")
        if tool ~= lastTool then
            lastTool = tool
            env = nil
            if tool then
                local animation = tool:FindFirstChild("Animation")
                if animation then
                    local ok, toolEnv = pcall(getsenv, animation)
                    if ok then env = toolEnv end
                end
            end
        end
        if env then
            env.minimumverticalrecoil = 0
            env.maximumverticalrecoil = 0
            env.minimumhorizontalrecoil = 0
            env.maximumhorizontalrecoil = 0
        end
    end)
end

-- ==================== TABS ====================
local MainTab = Window:Tab({ Title = "Main", Icon = "house" })
local MiscTab = Window:Tab({ Title = "Misc", Icon = "package" })
local RecruitTab = Window:Tab({ Title = "Recruit", Icon = "users" })
local VisualsTab = Window:Tab({ Title = "Visuals", Icon = "eye" })
local RageTab = Window:Tab({ Title = "Rage", Icon = "crosshair" })
local ConfigTab = Window:Tab({ Title = "Config", Icon = "settings" })

-- ==================== MAIN TAB ====================
local ChatSection = MainTab:Section({ Title = "Chat", Opened = true })

local spamText = false
local textToSpam = "RKZ HUB ON TOP"
local spamDelay = 1
local spamThread = nil

ChatSection:Input({
    Title = "Spam Text",
    Flag = "spam_text_value",
    Placeholder = "Digite o texto...",
    Value = textToSpam,
    Callback = function(value)
        textToSpam = value
    end,
})

ChatSection:Slider({
    Title = "Delay",
    Flag = "spam_text_delay",
    Step = 0.1,
    Value = { Min = 0.1, Max = 10, Default = spamDelay },
    Callback = function(value)
        spamDelay = value
    end,
})

ChatSection:Toggle({
    Title = "Spam",
    Flag = "spam_text_enabled",
    Value = false,
    Callback = function(state)
        spamText = state
        if spamThread then
            task.cancel(spamThread)
            spamThread = nil
        end
        if state then
            spamThread = task.spawn(function()
                while spamText do
                    if textToSpam and textToSpam ~= "" then
                        sendMsg(textToSpam)
                    end
                    task.wait(spamDelay)
                end
            end)
        end
    end,
})

ChatSection:Toggle({
    Title = "Mostrar Chat",
    Flag = "chat_visible",
    Value = false,
    Callback = function(state)
        if TextChatService.ChatWindowConfiguration then
            TextChatService.ChatWindowConfiguration.Enabled = state
        end
    end,
})

local MovementSection = MainTab:Section({ Title = "Movement", Opened = true })

local tpwalkActive = false
local tpwalkSpeed = 1
local tpWalkConnection = nil
local spamDetector = false
local selectedSpectatePlayer = nil
local spectateEnabled = false
local spectateConnection = nil

MovementSection:Toggle({
    Title = "TP Walk",
    Flag = "tp_walk_enabled",
    Value = false,
    Callback = function(state)
        tpwalkActive = state
        if state then
            if tpWalkConnection then tpWalkConnection:Disconnect() end
            tpWalkConnection = RunService.Heartbeat:Connect(function(delta)
                if not tpwalkActive then return end
                local char = getChar()
                local hum = getHumanoid()
                if char and hum and tpwalkSpeed > 0 and hum.MoveDirection.Magnitude > 0 then
                    pcall(function()
                        char:TranslateBy(hum.MoveDirection * tpwalkSpeed * delta)
                    end)
                end
            end)
        else
            if tpWalkConnection then
                tpWalkConnection:Disconnect()
                tpWalkConnection = nil
            end
        end
    end,
})

MainControls.TPWalkSlider = MovementSection:Slider({
    Title = "TP Walk Speed",
    Flag = "tp_walk_speed",
    Step = 1,
    Value = { Min = 1, Max = 15, Default = tpwalkSpeed },
    Callback = function(value)
        tpwalkSpeed = value
    end,
})

MainControls.SpamDetectorToggle = MovementSection:Toggle({
    Title = "Spam Detector",
    Flag = "spam_detector_enabled",
    Value = false,
    Callback = function(state)
        if state and not ExecutorSupport.Firetouchinterest then
            spamDetector = false
            notifyMissingExecutorSupport("Spam Detector", "firetouchinterest")
            if MainControls.SpamDetectorToggle then
                MainControls.SpamDetectorToggle:Set(false)
            end
            return
        end
        spamDetector = state
        if state then
            task.spawn(function()
                while spamDetector do
                    local rootPart = getRootPart()
                    local detectorFolder = workspace:FindFirstChild("MAPA DA EB")
                    local detector = detectorFolder
                        and detectorFolder:FindFirstChild("DeleteClient")
                        and detectorFolder.DeleteClient:FindFirstChild("Detecto")
                    if rootPart and detector then
                        pcall(function()
                            firetouchinterest(detector, rootPart, true)
                            firetouchinterest(detector, rootPart, false)
                        end)
                    end
                    task.wait(0.1)
                end
            end)
        end
    end,
})

MovementSection:Button({
    Title = "Anti Detector",
    Callback = function()
        local detectorFolder = workspace:FindFirstChild("MAPA DA EB")
        local detector = detectorFolder
            and detectorFolder:FindFirstChild("DeleteClient")
            and detectorFolder.DeleteClient:FindFirstChild("Detecto")
        if detector then
            pcall(function() detector:Destroy() end)
        end
    end,
})

-- VIP Portão (Invadir / Sair da base)
local VIPSection = MainTab:Section({ Title = "VIP Portão", Opened = true })

local EntrarAtivo = false
local SairAtivo = false
local CoordEntrar = Vector3.new(2084, 1, -132)
local CoordSair = Vector3.new(2085, 1, -124)

local function Teleportar(pos)
    local char = getChar()
    if char and char:FindFirstChild("HumanoidRootPart") then
        char.HumanoidRootPart.CFrame = CFrame.new(pos)
    end
end

VIPSection:Toggle({
    Title = "Entrar na base (Portão VIP)",
    Desc = "Teleporta para dentro quando o portão abrir",
    Flag = "vip_entrar",
    Value = false,
    Callback = function(state)
        EntrarAtivo = state
        if state then SairAtivo = false end
    end,
})

VIPSection:Toggle({
    Title = "Sair da base (Portão VIP)",
    Desc = "Teleporta para fora quando o portão abrir",
    Flag = "vip_sair",
    Value = false,
    Callback = function(state)
        SairAtivo = state
        if state then EntrarAtivo = false end
    end,
})

task.spawn(function()
    local mapa = workspace:WaitForChild("MAPA DA EB", 15)
    if not mapa then
        warn("MAPA DA EB não encontrado")
        return
    end
    local pastaVazia = mapa:WaitForChild("", 10)
    if not pastaVazia then
        warn("Pasta vazia não encontrada")
        return
    end
    local portao = pastaVazia:WaitForChild("Portão do VIP", 10)
    if not portao then
        warn("Portão do VIP não encontrado")
        return
    end
    local ultimoCanCollide = portao.CanCollide
    portao:GetPropertyChangedSignal("CanCollide"):Connect(function()
        local novo = portao.CanCollide
        if ultimoCanCollide == true and novo == false then
            if EntrarAtivo then
                Teleportar(CoordEntrar)
            elseif SairAtivo then
                Teleportar(CoordSair)
            end
        end
        ultimoCanCollide = novo
    end)
    print("Detecção do Portão VIP ativa (CanCollide)")
end)

local SpectateSection = MainTab:Section({ Title = "Spectate", Opened = true })

MainControls.SpectateDropdown = SpectateSection:Dropdown({
    Title = "Select Player",
    Flag = "spectate_target_player",
    Values = getPlayerList(),
    Search = true,
    Callback = function(value)
        selectedSpectatePlayer = value
    end,
})

SpectateSection:Toggle({
    Title = "Enable Spectate",
    Flag = "spectate_enabled",
    Value = false,
    Callback = function(state)
        spectateEnabled = state
        if spectateConnection then
            spectateConnection:Disconnect()
            spectateConnection = nil
        end
        if state then
            spectateConnection = RunService.RenderStepped:Connect(function()
                if not spectateEnabled then return end
                local target = selectedSpectatePlayer and Players:FindFirstChild(selectedSpectatePlayer)
                local targetHumanoid = target and target.Character and target.Character:FindFirstChildOfClass("Humanoid")
                if targetHumanoid and Camera.CameraSubject ~= targetHumanoid then
                    Camera.CameraSubject = targetHumanoid
                end
            end)
        else
            local myHumanoid = getHumanoid()
            if myHumanoid then Camera.CameraSubject = myHumanoid end
        end
    end,
})

-- ==================== MISC TAB ====================
local AutoBuySection = MiscTab:Section({ Title = "Auto Buy Gun", Opened = true })

local SelectedWeapon = nil
local autoBuyEnabled = false
local WeaponsList = {
    "G3 tactical 1","Benelli M4 Super 90","AR 15","USP9-S","FABARM STF 12",
    "G36C","M14","IA2","L96","Lever action rifle","M16","AS VAL","M4A1",
    "MP5SD M203","RPK","SCAR","SKS","Saiga 12","Serbu Shorty","Gasser M1870",
    "M4","Beretta do inferno","PP-19 Bizon","AK47","M249","Glock",
    "MP5SD M203 Scorpions","L96 Red Black","L96 Camuflada","G36C Red Black",
    "Beretta do inferno Red Black","G36C Camuflada","Beretta do inferno Camuflada",
    "Beretta do inferno Blue Dragon","Beretta do inferno Scorpions",
    "G36C Blue Dragon","G36C Scorpions","L96 Blue Dragon","L96 Scorpions",
    "MP5SD M203 Blue Dragon","MP5SD M203 Camuflada","MP5SD M203 Red Black",
    "SCAR Camuflada","SCAR Red Black","PP-19 Bizon Fire"
}

local Senhas = game:GetService("ReplicatedFirst"):FindFirstChild("Senhas")
local Senha3 = Senhas and Senhas:FindFirstChild("Senha 3")
local Senha4 = Senhas and Senhas:FindFirstChild("Senha 4")

local function HasWeapon(weapon)
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    local character = LocalPlayer.Character
    if backpack and backpack:FindFirstChild(weapon) then return true end
    if character and character:FindFirstChild(weapon) then return true end
    return false
end

local function BuyWeapon(weapon)
    ReplicatedStorage:WaitForChild("Armas"):InvokeServer(
        Senha3 and Senha3.Value,
        Senha4 and Senha4.Value,
        weapon,
        "Armas"
    )
end

AutoBuySection:Paragraph({
    Title = "Info",
    Desc = "Você precisa estar perto da loja. Se já tiver a arma selecionada ela não compra.",
})

AutoBuySection:Dropdown({
    Title = "Select Gun",
    Flag = "Gun_Dropdown",
    Values = WeaponsList,
    Search = true,
    Callback = function(value)
        SelectedWeapon = value
    end,
})

AutoBuySection:Toggle({
    Title = "Auto Buy Selected",
    Flag = "auto_buy_enabled",
    Value = false,
    Callback = function(state)
        autoBuyEnabled = state
        if state then
            task.spawn(function()
                while autoBuyEnabled do
                    task.wait(1)
                    if SelectedWeapon and not HasWeapon(SelectedWeapon) then
                        print("Comprando:", SelectedWeapon)
                        BuyWeapon(SelectedWeapon)
                    end
                end
            end)
        end
    end,
})

local DesyncSection = MiscTab:Section({ Title = "Desync", Opened = true })

local Desync = false
local raknetSupported = false

if raknet and raknet.add_send_hook and buffer and buffer.writeu32 then
    raknetSupported = true
    raknet.add_send_hook(function(packet)
        if not Desync then return packet end
        if packet.PacketId == 0x1B then
            local buf = packet.AsBuffer
            buffer.writeu32(buf, 1, 0xFFFFFFFF)
            packet:SetData(buf)
        end
        return packet
    end)
else
    warn("Executor não suporta Raknet")
end

DesyncSection:Toggle({
    Title = "Desync Pc",
    Flag = "desync_pc",
    Value = false,
    Callback = function(state)
        if not raknetSupported then
            warn("Raknet não suportado")
            return
        end
        Desync = state
    end,
})

local DesyncMobile = false
DesyncSection:Toggle({
    Title = "Desync Mobile",
    Flag = "desync_mobile",
    Value = false,
    Callback = function(state)
        DesyncMobile = state
        pcall(function()
            raknet.desync(DesyncMobile)
        end)
    end,
})

local MusicSection = MiscTab:Section({ Title = "Music", Opened = true })

MusicSection:Input({
    Title = "Music ID",
    Flag = "music_id_input",
    Placeholder = "Type the music ID...",
    Value = "",
    Callback = function(value)
        musicId = value or ""
    end,
})

MusicSection:Toggle({
    Title = "Play ID",
    Flag = "music_play_toggle",
    Value = false,
    Callback = function(state)
        if state then
            if musicId ~= "" then
                musicSound.SoundId = "rbxassetid://" .. musicId
                musicSound:Play()
            else
                musicSound:Stop()
                WindUI:Notify({
                    Title = "Music",
                    Content = "Enter a valid music ID.",
                    Duration = 3,
                })
            end
        else
            musicSound:Stop()
        end
    end,
})

-- Auto Farm Lixo
local FarmSection = MiscTab:Section({ Title = "Auto Farm Lixo", Opened = true })

local FarmAtivo = false
local FarmRodando = false

local function FarmGetCharacter()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function FarmGetRoot()
    return FarmGetCharacter():FindFirstChild("HumanoidRootPart")
end

local function FarmGetHumanoid()
    return FarmGetCharacter():FindFirstChildOfClass("Humanoid")
end

local function FarmGetPart(Object)
    if Object:IsA("BasePart") then return Object end
    return Object:FindFirstChildWhichIsA("BasePart", true)
end

local function FarmGetPrompt(Object)
    if Object:IsA("ProximityPrompt") then return Object end
    return Object:FindFirstChildWhichIsA("ProximityPrompt", true)
end

local function TemLixo()
    local Character = FarmGetCharacter()
    return LocalPlayer.Backpack:FindFirstChild("Lixo") or Character:FindFirstChild("Lixo")
end

local function EncontrarMaisProximo(Folder)
    local Root = FarmGetRoot()
    if not Root then return nil end
    local Melhor
    local MenorDistancia = math.huge
    for _, Object in ipairs(Folder:GetChildren()) do
        local Part = FarmGetPart(Object)
        local Prompt = FarmGetPrompt(Object)
        if Part and Prompt and Prompt.Enabled then
            local Distancia = (Root.Position - Part.Position).Magnitude
            if Distancia < MenorDistancia then
                MenorDistancia = Distancia
                Melhor = Object
            end
        end
    end
    return Melhor
end

local function IrAte(Destino)
    local Root = FarmGetRoot()
    local Humanoid = FarmGetHumanoid()
    if not Root or not Humanoid then return false end
    local Path = PathfindingService:CreatePath({
        AgentRadius = 2,
        AgentHeight = 5,
        AgentCanJump = true,
        WaypointSpacing = 4
    })
    local Sucesso = pcall(function()
        Path:ComputeAsync(Root.Position, Destino)
    end)
    if not Sucesso or Path.Status ~= Enum.PathStatus.Success then
        Humanoid:MoveTo(Destino)
        local Inicio = tick()
        while FarmAtivo and tick() - Inicio < 8 do
            if (Root.Position - Destino).Magnitude <= 6 then return true end
            task.wait(0.15)
        end
        return false
    end
    for _, Waypoint in ipairs(Path:GetWaypoints()) do
        if not FarmAtivo then return false end
        if Waypoint.Action == Enum.PathWaypointAction.Jump then
            Humanoid.Jump = true
        end
        Humanoid:MoveTo(Waypoint.Position)
        local Inicio = tick()
        while FarmAtivo and tick() - Inicio < 4 do
            if (Root.Position - Waypoint.Position).Magnitude <= 4 then break end
            task.wait(0.1)
        end
    end
    return true
end

local function UsarPrompt(Prompt)
    if not Prompt or not Prompt.Enabled then return false end
    local HoldDuration = Prompt.HoldDuration or 0
    Prompt:InputHoldBegin()
    task.wait(HoldDuration + 0.1)
    Prompt:InputHoldEnd()
    return true
end

local function PegarLixo()
    local Sistema = workspace:FindFirstChild("Sistema_De_Lixo")
    if not Sistema then return false end
    local Lixos = Sistema:FindFirstChild("Lixos")
    if not Lixos then return false end
    local Lixo = EncontrarMaisProximo(Lixos)
    if not Lixo then return false end
    local Part = FarmGetPart(Lixo)
    local Prompt = FarmGetPrompt(Lixo)
    if not Part or not Prompt then return false end
    if not IrAte(Part.Position) then return false end
    for _ = 1, 3 do
        if not FarmAtivo or TemLixo() then break end
        UsarPrompt(Prompt)
        task.wait(0.25)
    end
    local Inicio = tick()
    while FarmAtivo and not TemLixo() and tick() - Inicio < 3 do
        task.wait(0.1)
    end
    return TemLixo() ~= nil
end

local function JogarLixoFora()
    local Sistema = workspace:FindFirstChild("Sistema_De_Lixo")
    if not Sistema then return false end
    local Lixeiras = Sistema:FindFirstChild("Lixeiras")
    if not Lixeiras then return false end
    local Lixeira = EncontrarMaisProximo(Lixeiras)
    if not Lixeira then return false end
    local Part = FarmGetPart(Lixeira)
    local Prompt = FarmGetPrompt(Lixeira)
    if not Part or not Prompt then return false end
    if not IrAte(Part.Position) then return false end
    UsarPrompt(Prompt)
    task.wait(0.5)
    return true
end

local function AutoFarmLixo()
    if FarmRodando then return end
    FarmRodando = true
    while FarmAtivo do
        if not TemLixo() then
            PegarLixo()
        end
        if FarmAtivo and TemLixo() then
            JogarLixoFora()
        end
        task.wait(0.15)
    end
    FarmRodando = false
end

FarmSection:Toggle({
    Title = "Auto Farm Lixo",
    Desc = "Pega e joga lixo automaticamente",
    Flag = "auto_farm_lixo",
    Value = false,
    Callback = function(Value)
        FarmAtivo = Value
        if Value then
            task.spawn(AutoFarmLixo)
        end
    end,
})

-- ==================== RECRUIT TAB ====================
local ResponsesSection = RecruitTab:Section({ Title = "Responses", Opened = true })

ResponsesSection:Button({
    Title = "Nao, Cabo.",
    Callback = function() sendMsg("Nao, Cabo.") end,
})
ResponsesSection:Button({
    Title = "Sim, Cabo.",
    Callback = function() sendMsg("Sim, Cabo.") end,
})
ResponsesSection:Button({
    Title = "Nao, Sargento.",
    Callback = function() sendMsg("Nao, Sargento.") end,
})
ResponsesSection:Button({
    Title = "Sim, Sargento.",
    Callback = function() sendMsg("Sim, Sargento.") end,
})

local AutoVolverSection = RecruitTab:Section({ Title = "Auto Volver's", Opened = true })

AutoVolverSection:Toggle({
    Title = "Auto Volver's",
    Flag = "recruit_auto_volvers",
    Value = false,
    Callback = function(state)
        RecruitState.AutoVolvers = state
    end,
})

AutoVolverSection:Input({
    Title = "Instructor Name",
    Flag = "recruit_instructor_name",
    Placeholder = "Type the instructor name...",
    Value = "",
    Callback = function(value)
        if value == "" then
            RecruitState.InstructorName = ""
            return
        end
        local foundPlayer = findPlayerByPrefix(value)
        if foundPlayer then
            RecruitState.InstructorName = foundPlayer.Name
            WindUI:Notify({
                Title = "Recruit",
                Content = "Instructor detected: " .. foundPlayer.Name,
                Duration = 3,
            })
        else
            RecruitState.InstructorName = value
        end
    end,
})

local AutoJJSection = RecruitTab:Section({ Title = "Auto JJ's", Opened = true })

AutoJJSection:Input({
    Title = "Start From",
    Flag = "recruit_jjs_start",
    Placeholder = "Ex: 1",
    Value = "1",
    Callback = function(value)
        local number = tonumber(value)
        if number then RecruitState.JJsStartNumber = math.clamp(number, 1, 5000) end
    end,
})

AutoJJSection:Input({
    Title = "End At",
    Flag = "recruit_jjs_end",
    Placeholder = "Ex: 10",
    Value = "10",
    Callback = function(value)
        local number = tonumber(value)
        if number then RecruitState.JJsEndNumber = math.clamp(number, 1, 5000) end
    end,
})

AutoJJSection:Input({
    Title = "Suffix",
    Flag = "recruit_jjs_suffix",
    Placeholder = "Ex: !",
    Value = "!",
    Callback = function(value)
        RecruitState.JJsSuffix = value or "!"
    end,
})

AutoJJSection:Input({
    Title = "Interval",
    Flag = "recruit_jjs_wait_time",
    Placeholder = "Ex: 1.5",
    Value = "1.5",
    Callback = function(value)
        local number = tonumber(value)
        if number then RecruitState.JJsWaitTime = number end
    end,
})

AutoJJSection:Toggle({
    Title = "Reverse Mode",
    Flag = "recruit_jjs_reverse",
    Value = false,
    Callback = function(state)
        RecruitState.JJsReverseMode = state
    end,
})

RecruitState.JJsPlayToggle = AutoJJSection:Toggle({
    Title = "Play Auto JJ's",
    Flag = "recruit_jjs_play",
    Value = false,
    Callback = function(state)
        RecruitState.JJsRunning = state
        if state then
            task.spawn(runRecruitJJs)
        end
    end,
})

-- ==================== RAGE TAB ====================
rageProjectileStatusLabel = RageTab:Paragraph({
    Title = "Projectile Status",
    Desc = "Carregando aimkill e silent aim, se demorar muito pegue uma arma...",
})
updateProjectileStatusLabel()

local WeaponSection = RageTab:Section({ Title = "Weapon", Opened = true })

WeaponSection:Button({
    Title = "Remove Recoil",
    Callback = function()
        if not ExecutorSupport.Getsenv then
            notifyMissingExecutorSupport("Remove Recoil", "getsenv")
            return
        end
        startRecoilRemoval()
        WindUI:Notify({
            Title = "Weapon",
            Content = "Remove Recoil activated.",
            Duration = 3,
        })
    end,
})

WeaponSection:Toggle({
    Title = "Infinite Ammo",
    Flag = "infinite_ammo_enabled",
    Value = false,
    Callback = function(state)
        infiniteAmmoEnabled = state
        if state then startInfiniteAmmo() else stopInfiniteAmmo() end
        WindUI:Notify({
            Title = "Weapon",
            Content = state and "Infinite Ammo activated." or "Infinite Ammo disabled.",
            Duration = 3,
        })
    end,
})

RageControls.AutoReloadToggle = WeaponSection:Toggle({
    Title = "Auto reload gun",
    Flag = "auto_reload_gun_enabled",
    Value = false,
    Callback = function(state)
        if state and not isAutoReloadSupported() then
            autoReloadEnabled = false
            stopAutoReload()
            WindUI:Notify({
                Title = "Weapon",
                Content = "Your executor does not support auto reload.",
                Duration = 3,
            })
            if RageControls.AutoReloadToggle then
                RageControls.AutoReloadToggle:Set(false)
            end
            return
        end
        autoReloadEnabled = state
        if state then startAutoReload() else stopAutoReload() end
        WindUI:Notify({
            Title = "Weapon",
            Content = state and "Auto reload gun activated." or "Auto reload gun disabled.",
            Duration = 3,
        })
    end,
})

local RageMovementSection = RageTab:Section({ Title = "Movement", Opened = true })

RageMovementSection:Toggle({
    Title = "Infinite Jump",
    Flag = "infinite_jump_enabled",
    Value = false,
    Callback = function(state)
        infiniteJumpEnabled = state
        if state then
            startInfiniteJump()
            WindUI:Notify({
                Title = "Warning",
                Content = "NAO PULE MUITO, SE VC PULAR MUITO IRA TOMAR BAN",
                Duration = 5,
            })
        else
            stopInfiniteJump()
        end
    end,
})

RageMovementSection:Toggle({
    Title = "Spinbot",
    Flag = "spinbot_enabled",
    Value = false,
    Callback = function(state)
        spinbotEnabled = state
        if state then startSpinbot() else stopSpinbot() end
    end,
})

RageControls.SpinbotSpeedSlider = RageMovementSection:Slider({
    Title = "Spinbot Speed",
    Flag = "spinbot_speed",
    Step = 1,
    Value = { Min = 1, Max = 100, Default = spinbotSpeed },
    Callback = function(value)
        spinbotSpeed = value
        if spinbotEnabled then applySpinbot() end
    end,
})

local AimkillSection = RageTab:Section({ Title = "Aimkill", Opened = true })

RageControls.KillAuraEnabledToggle = AimkillSection:Toggle({
    Title = "Enable Aimkill",
    Flag = "kill_aura_enabled",
    Value = false,
    Callback = function(state)
        killAuraEnabled = state
        if state then
            task.spawn(function()
                while killAuraEnabled do
                    local serverEvents = ReplicatedStorage:FindFirstChild("ServerEvents")
                    local projectileRemote = serverEvents and serverEvents:FindFirstChild("_Projectile")
                    local currentCharacter = getChar()
                    local currentWeapon = currentCharacter and currentCharacter:FindFirstChildWhichIsA("Tool")
                    local projectileKey = getProjectileKey()
                    if projectileRemote and projectileKey and currentWeapon then
                        local animation = currentWeapon:FindFirstChild("Animation")
                        local bullet = animation and animation:FindFirstChild("BulletDamage")
                        if bullet then
                            for _, targetData in ipairs(getKillAuraTargets()) do
                                if targetData.plr
                                    and isPlayerTargetable(targetData.plr)
                                    and targetData.character
                                    and not isLocalCharacter(targetData.character)
                                    and targetData.part
                                    and (not currentCharacter or not targetData.part:IsDescendantOf(currentCharacter))
                                then
                                    pcall(function()
                                        projectileRemote:FireServer(projectileKey, bullet, targetData.part, targetData.plr)
                                    end)
                                end
                            end
                        end
                    end
                    task.wait(0.1)
                end
            end)
        end
    end,
})

RageControls.KillAuraDistanceSlider = AimkillSection:Slider({
    Title = "Max Distance",
    Flag = "kill_aura_max_distance",
    Step = 10,
    Value = { Min = 50, Max = 2000, Default = killAuraMaxDistance },
    Callback = function(value)
        killAuraMaxDistance = value
    end,
})

RageControls.KillAuraIgnoreTeamsDropdown = AimkillSection:Dropdown({
    Title = "Ignore Teams",
    Flag = "kill_aura_ignore_teams",
    Values = getTeamList(),
    Multi = true,
    AllowNone = true,
    Search = true,
    Callback = function(value)
        killAuraIgnoreTeams = value or {}
    end,
})

RageControls.KillAuraIgnorePlayersDropdown = AimkillSection:Dropdown({
    Title = "Ignore Players",
    Flag = "kill_aura_ignore_players",
    Values = getPlayerList(),
    Multi = true,
    AllowNone = true,
    Search = true,
    Callback = function(value)
        killAuraIgnorePlayers = value or {}
    end,
})

RageControls.KillAuraShowTargetsToggle = AimkillSection:Toggle({
    Title = "Show Targets",
    Flag = "kill_aura_show_targets",
    Value = false,
    Callback = function(state)
        killAuraShowTargets = state
        if state then
            if killAuraHighlightThread then task.cancel(killAuraHighlightThread) end
            killAuraHighlightThread = task.spawn(function()
                while killAuraShowTargets and task.wait(0.3) do
                    pcall(updateKillAuraHighlights)
                end
            end)
        else
            if killAuraHighlightThread then
                task.cancel(killAuraHighlightThread)
                killAuraHighlightThread = nil
            end
            clearKillAuraHighlights()
        end
    end,
})

local SilentAimSection = RageTab:Section({ Title = "Silent Aim", Opened = true })

RageControls.SilentAimEnabledToggle = SilentAimSection:Toggle({
    Title = "Enable Silent Aim",
    Flag = "silent_aim_enabled",
    Value = false,
    Callback = function(state)
        if state and not ExecutorSupport.Hook then
            silentAimEnabled = false
            notifyMissingExecutorSupport("Silent Aim", "hookmetamethod")
            if RageControls.SilentAimEnabledToggle then
                RageControls.SilentAimEnabledToggle:Set(false)
            end
            return
        end
        silentAimEnabled = state
    end,
})

RageControls.SilentAimTargetPartDropdown = SilentAimSection:Dropdown({
    Title = "Target Part",
    Flag = "silent_aim_target_part",
    Values = { "Head", "HumanoidRootPart" },
    Value = "Head",
    Callback = function(value)
        silentAimTargetPart = value or "Head"
    end,
})

RageControls.SilentAimIgnoreTeamsDropdown = SilentAimSection:Dropdown({
    Title = "Ignore Teams",
    Flag = "silent_aim_ignore_teams",
    Values = getTeamList(),
    Multi = true,
    AllowNone = true,
    Search = true,
    Callback = function(value)
        silentAimIgnoreTeams = value or {}
    end,
})

RageControls.SilentAimIgnorePlayersDropdown = SilentAimSection:Dropdown({
    Title = "Ignore Players",
    Flag = "silent_aim_ignore_players",
    Values = getPlayerList(),
    Multi = true,
    AllowNone = true,
    Search = true,
    Callback = function(value)
        silentAimIgnorePlayers = value or {}
    end,
})

RageControls.SilentAimDistanceSlider = SilentAimSection:Slider({
    Title = "Max Distance",
    Flag = "silent_aim_max_distance",
    Step = 10,
    Value = { Min = 50, Max = 2000, Default = silentAimMaxDistance },
    Callback = function(value)
        silentAimMaxDistance = value
    end,
})

RageControls.SilentAimFOVModeDropdown = SilentAimSection:Dropdown({
    Title = "FOV Mode",
    Flag = "silent_aim_fov_mode",
    Values = { "Mouse", "Center" },
    Value = "Mouse",
    Callback = function(value)
        silentAimFOVMode = value or "Mouse"
    end,
})

RageControls.SilentAimFOVSizeSlider = SilentAimSection:Slider({
    Title = "FOV Size",
    Flag = "silent_aim_fov_size",
    Step = 5,
    Value = { Min = 50, Max = 500, Default = silentAimFOVRadius },
    Callback = function(value)
        silentAimFOVRadius = value
    end,
})

RageControls.SilentAimShowFOVToggle = SilentAimSection:Toggle({
    Title = "Show FOV",
    Flag = "silent_aim_show_fov",
    Value = false,
    Callback = function(state)
        if state and not ExecutorSupport.Drawing then
            silentAimFOVVisible = false
            notifyMissingExecutorSupport("Silent Aim FOV", "Drawing")
            if RageControls.SilentAimShowFOVToggle then
                RageControls.SilentAimShowFOVToggle:Set(false)
            end
            updateSilentAimFOVCircle()
            return
        end
        silentAimFOVVisible = state
        updateSilentAimFOVCircle()
    end,
})

RageControls.SilentAimFOVColorPicker = SilentAimSection:Colorpicker({
    Title = "FOV Color",
    Flag = "silent_aim_fov_color",
    Default = silentAimFOVColor,
    Transparency = silentAimFOVAlpha,
    Callback = function(color, alpha)
        silentAimFOVColor = color
        silentAimFOVAlpha = alpha or 1
        updateSilentAimFOVCircle()
    end,
})

local HitboxSection = RageTab:Section({ Title = "Hitbox Expander", Opened = true })

RageControls.HitboxExpanderEnabledToggle = HitboxSection:Toggle({
    Title = "Enable Hitbox Expander",
    Flag = "hitbox_expander_enabled",
    Value = false,
    Callback = function(state)
        hitboxExpanderEnabled = state
        if state then startHitboxExpander() else stopHitboxExpander() end
    end,
})

RageControls.HitboxExpanderSizeSlider = HitboxSection:Slider({
    Title = "Size Multiplier",
    Flag = "hitbox_expander_size",
    Step = 0.5,
    Value = { Min = 1, Max = 20, Default = hitboxExpanderSize },
    Callback = function(value)
        hitboxExpanderSize = value
        if hitboxExpanderEnabled then updateHitboxExpander() end
    end,
})

RageControls.HitboxExpanderTransparencySlider = HitboxSection:Slider({
    Title = "Transparency",
    Flag = "hitbox_expander_transparency",
    Step = 0.1,
    Value = { Min = 0, Max = 1, Default = hitboxExpanderTransparency },
    Callback = function(value)
        hitboxExpanderTransparency = value
        if hitboxExpanderEnabled then updateHitboxExpander() end
    end,
})

RageControls.HitboxExpanderIgnoreTeamsDropdown = HitboxSection:Dropdown({
    Title = "Ignore Teams",
    Flag = "hitbox_expander_ignore_teams",
    Values = getTeamList(),
    Multi = true,
    AllowNone = true,
    Callback = function(values)
        hitboxExpanderIgnoreTeams = values or {}
        if hitboxExpanderEnabled then updateHitboxExpander() end
    end,
})

RageControls.HitboxExpanderIgnorePlayersDropdown = HitboxSection:Dropdown({
    Title = "Ignore Players",
    Flag = "hitbox_expander_ignore_players",
    Values = getPlayerList(),
    Multi = true,
    AllowNone = true,
    Callback = function(values)
        hitboxExpanderIgnorePlayers = values or {}
        if hitboxExpanderEnabled then updateHitboxExpander() end
    end,
})

local AimbotSection = RageTab:Section({ Title = "Aimbot", Opened = true })

RageControls.AimbotEnabledToggle = AimbotSection:Toggle({
    Title = "Enable Aimbot",
    Flag = "aimbot_enabled",
    Value = false,
    Callback = function(state)
        AimbotState.Enabled = state
        if not state then AimbotState.CurrentTarget = nil end
    end,
})

RageControls.AimbotModeDropdown = AimbotSection:Dropdown({
    Title = "Aimbot Mode",
    Flag = "aimbot_mode",
    Values = { "Mouse", "Camera" },
    Value = AimbotState.AimMode,
    Callback = function(value)
        AimbotState.AimMode = value or "Mouse"
    end,
})

RageControls.AimbotTargetPartDropdown = AimbotSection:Dropdown({
    Title = "Target Part",
    Flag = "aimbot_target_part",
    Values = { "Head", "HumanoidRootPart" },
    Value = AimbotState.TargetPart,
    Callback = function(value)
        AimbotState.TargetPart = value or "Head"
    end,
})

RageControls.AimbotSmoothnessSlider = AimbotSection:Slider({
    Title = "Smoothness",
    Flag = "aimbot_smoothness",
    Step = 0.01,
    Value = { Min = 0.01, Max = 1, Default = AimbotState.Smoothness },
    Callback = function(value)
        AimbotState.Smoothness = value
    end,
})

RageControls.AimbotShowFOVToggle = AimbotSection:Toggle({
    Title = "Show FOV",
    Flag = "aimbot_show_fov",
    Value = false,
    Callback = function(state)
        if state and not ExecutorSupport.Drawing then
            AimbotState.FOVVisible = false
            notifyMissingExecutorSupport("Aimbot FOV", "Drawing")
            if RageControls.AimbotShowFOVToggle then
                RageControls.AimbotShowFOVToggle:Set(false)
            end
            return
        end
        AimbotState.FOVVisible = state
    end,
})

RageControls.AimbotFOVColorPicker = AimbotSection:Colorpicker({
    Title = "FOV Color",
    Flag = "aimbot_fov_color",
    Default = AimbotState.FOVColor,
    Transparency = AimbotState.FOVAlpha,
    Callback = function(color, alpha)
        AimbotState.FOVColor = color
        AimbotState.FOVAlpha = alpha or 1
    end,
})

RageControls.AimbotFOVModeDropdown = AimbotSection:Dropdown({
    Title = "FOV Mode",
    Flag = "aimbot_fov_mode",
    Values = { "Mouse", "Center" },
    Value = AimbotState.FOVMode,
    Callback = function(value)
        AimbotState.FOVMode = value or "Mouse"
    end,
})

RageControls.AimbotFOVRadiusSlider = AimbotSection:Slider({
    Title = "FOV Radius",
    Flag = "aimbot_fov_radius",
    Step = 1,
    Value = { Min = 20, Max = 300, Default = AimbotState.FOVRadius },
    Callback = function(value)
        AimbotState.FOVRadius = value
    end,
})

RageControls.AimbotMaxDistanceSlider = AimbotSection:Slider({
    Title = "Max Distance",
    Flag = "aimbot_max_distance",
    Step = 10,
    Value = { Min = 50, Max = 5000, Default = AimbotState.MaxDistance },
    Callback = function(value)
        AimbotState.MaxDistance = value
    end,
})

RageControls.AimbotTeamCheckToggle = AimbotSection:Toggle({
    Title = "Team Check",
    Flag = "aimbot_team_check",
    Value = true,
    Callback = function(state)
        AimbotState.TeamCheck = state
    end,
})

RageControls.AimbotWallCheckToggle = AimbotSection:Toggle({
    Title = "Wall Check",
    Flag = "aimbot_wall_check",
    Value = false,
    Callback = function(state)
        AimbotState.WallCheck = state
    end,
})

-- ==================== VISUALS TAB ====================
local ESPSection = VisualsTab:Section({ Title = "ESP", Opened = true })

VisualControls.ESPIgnoreTeamsDropdown = ESPSection:Dropdown({
    Title = "Ignore Teams",
    Flag = "esp_ignore_teams",
    Values = getTeamList(),
    Multi = true,
    AllowNone = true,
    Callback = function(value)
        ESPState.IgnoreTeams = value or {}
    end,
})

VisualControls.ESPShowBoxToggle = ESPSection:Toggle({
    Title = "ESP Box",
    Flag = "esp_show_box",
    Value = false,
    Callback = function(state)
        if state and not ExecutorSupport.Drawing then
            ESPState.ShowBox = false
            notifyMissingExecutorSupport("ESP Box", "Drawing")
            if VisualControls.ESPShowBoxToggle then
                VisualControls.ESPShowBoxToggle:Set(false)
            end
            refreshESPState()
            return
        end
        ESPState.ShowBox = state
        refreshESPState()
    end,
})

VisualControls.ESPBoxColorPicker = ESPSection:Colorpicker({
    Title = "Box Color",
    Flag = "esp_box_color",
    Default = ESPState.BoxColor,
    Transparency = ESPState.BoxAlpha,
    Callback = function(color, alpha)
        ESPState.BoxColor = color
        ESPState.BoxAlpha = alpha or 1
    end,
})

VisualControls.ESPShowNameToggle = ESPSection:Toggle({
    Title = "ESP Name",
    Flag = "esp_show_name",
    Value = false,
    Callback = function(state)
        if state and not ExecutorSupport.Drawing then
            ESPState.ShowName = false
            notifyMissingExecutorSupport("ESP Name", "Drawing")
            if VisualControls.ESPShowNameToggle then
                VisualControls.ESPShowNameToggle:Set(false)
            end
            refreshESPState()
            return
        end
        ESPState.ShowName = state
        refreshESPState()
    end,
})

VisualControls.ESPNameColorPicker = ESPSection:Colorpicker({
    Title = "Name Color",
    Flag = "esp_name_color",
    Default = ESPState.NameColor,
    Transparency = ESPState.NameAlpha,
    Callback = function(color, alpha)
        ESPState.NameColor = color
        ESPState.NameAlpha = alpha or 1
    end,
})

VisualControls.ESPShowDistanceToggle = ESPSection:Toggle({
    Title = "ESP Distance",
    Flag = "esp_show_distance",
    Value = false,
    Callback = function(state)
        if state and not ExecutorSupport.Drawing then
            ESPState.ShowDistance = false
            notifyMissingExecutorSupport("ESP Distance", "Drawing")
            if VisualControls.ESPShowDistanceToggle then
                VisualControls.ESPShowDistanceToggle:Set(false)
            end
            refreshESPState()
            return
        end
        ESPState.ShowDistance = state
        refreshESPState()
    end,
})

VisualControls.ESPDistanceColorPicker = ESPSection:Colorpicker({
    Title = "Distance Color",
    Flag = "esp_distance_color",
    Default = ESPState.DistanceColor,
    Transparency = ESPState.DistanceAlpha,
    Callback = function(color, alpha)
        ESPState.DistanceColor = color
        ESPState.DistanceAlpha = alpha or 1
    end,
})

VisualControls.ESPShowToolToggle = ESPSection:Toggle({
    Title = "ESP Tool",
    Flag = "esp_show_tool",
    Value = false,
    Callback = function(state)
        if state and not ExecutorSupport.Drawing then
            ESPState.ShowTool = false
            notifyMissingExecutorSupport("ESP Tool", "Drawing")
            if VisualControls.ESPShowToolToggle then
                VisualControls.ESPShowToolToggle:Set(false)
            end
            refreshESPState()
            return
        end
        ESPState.ShowTool = state
        refreshESPState()
    end,
})

VisualControls.ESPToolColorPicker = ESPSection:Colorpicker({
    Title = "Tool Color",
    Flag = "esp_tool_color",
    Default = ESPState.ToolColor,
    Transparency = ESPState.ToolAlpha,
    Callback = function(color, alpha)
        ESPState.ToolColor = color
        ESPState.ToolAlpha = alpha or 1
    end,
})

VisualControls.ESPShowTracersToggle = ESPSection:Toggle({
    Title = "ESP Tracers",
    Flag = "esp_show_tracers",
    Value = false,
    Callback = function(state)
        if state and not ExecutorSupport.Drawing then
            ESPState.ShowTracers = false
            notifyMissingExecutorSupport("ESP Tracers", "Drawing")
            if VisualControls.ESPShowTracersToggle then
                VisualControls.ESPShowTracersToggle:Set(false)
            end
            refreshESPState()
            return
        end
        ESPState.ShowTracers = state
        refreshESPState()
    end,
})

VisualControls.ESPTracerColorPicker = ESPSection:Colorpicker({
    Title = "Tracer Color",
    Flag = "esp_tracer_color",
    Default = ESPState.TracerColor,
    Transparency = ESPState.TracerAlpha,
    Callback = function(color, alpha)
        ESPState.TracerColor = color
        ESPState.TracerAlpha = alpha or 1
    end,
})

VisualControls.ESPTracerOriginDropdown = ESPSection:Dropdown({
    Title = "Tracer Origin",
    Flag = "esp_tracer_origin",
    Values = { "Bottom", "Center", "Top" },
    Value = ESPState.TracerOrigin,
    Callback = function(value)
        ESPState.TracerOrigin = value or "Bottom"
    end,
})

ESPSection:Toggle({
    Title = "ESP Chams",
    Flag = "esp_show_chams",
    Value = false,
    Callback = function(state)
        ESPState.ShowChams = state
        refreshESPState()
    end,
})

VisualControls.ESPChamsColorPicker = ESPSection:Colorpicker({
    Title = "Chams Color",
    Flag = "esp_chams_color",
    Default = ESPState.ChamsColor,
    Transparency = ESPState.ChamsAlpha,
    Callback = function(color, alpha)
        ESPState.ChamsColor = color
        ESPState.ChamsAlpha = alpha or 0.35
    end,
})

-- ==================== CONNECTIONS ====================
for _, player in ipairs(Players:GetPlayers()) do
    connectRecruitChat(player)
end

Players.PlayerAdded:Connect(function(player)
    connectRecruitChat(player)
    task.wait(0.3)
    if MainControls.SpectateDropdown and MainControls.SpectateDropdown.Refresh then
        MainControls.SpectateDropdown:Refresh(getPlayerList())
    end
    if RageControls.KillAuraIgnorePlayersDropdown and RageControls.KillAuraIgnorePlayersDropdown.Refresh then
        RageControls.KillAuraIgnorePlayersDropdown:Refresh(getPlayerList())
    end
    if RageControls.SilentAimIgnorePlayersDropdown and RageControls.SilentAimIgnorePlayersDropdown.Refresh then
        RageControls.SilentAimIgnorePlayersDropdown:Refresh(getPlayerList())
    end
    if RageControls.HitboxExpanderIgnorePlayersDropdown and RageControls.HitboxExpanderIgnorePlayersDropdown.Refresh then
        RageControls.HitboxExpanderIgnorePlayersDropdown:Refresh(getPlayerList())
    end
    if hitboxExpanderEnabled then
        task.wait(0.5)
        expandHitbox(player)
    end
end)

Players.PlayerRemoving:Connect(function(player)
    local connection = RecruitState.ChatConnections[player]
    if connection then
        connection:Disconnect()
        RecruitState.ChatConnections[player] = nil
    end
    task.wait(0.3)
    if MainControls.SpectateDropdown and MainControls.SpectateDropdown.Refresh then
        MainControls.SpectateDropdown:Refresh(getPlayerList())
    end
    if RageControls.KillAuraIgnorePlayersDropdown and RageControls.KillAuraIgnorePlayersDropdown.Refresh then
        RageControls.KillAuraIgnorePlayersDropdown:Refresh(getPlayerList())
    end
    if RageControls.SilentAimIgnorePlayersDropdown and RageControls.SilentAimIgnorePlayersDropdown.Refresh then
        RageControls.SilentAimIgnorePlayersDropdown:Refresh(getPlayerList())
    end
    if RageControls.HitboxExpanderIgnorePlayersDropdown and RageControls.HitboxExpanderIgnorePlayersDropdown.Refresh then
        RageControls.HitboxExpanderIgnorePlayersDropdown:Refresh(getPlayerList())
    end
    if selectedSpectatePlayer == player.Name then
        selectedSpectatePlayer = nil
        if spectateEnabled then
            local myHumanoid = getHumanoid()
            if myHumanoid then Camera.CameraSubject = myHumanoid end
        end
    end
    restoreHitbox(player)
end)

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.25)
    if spinbotEnabled then startSpinbot() end
end)

Teams.ChildAdded:Connect(function()
    task.wait(0.3)
    if RageControls.KillAuraIgnoreTeamsDropdown and RageControls.KillAuraIgnoreTeamsDropdown.Refresh then
        RageControls.KillAuraIgnoreTeamsDropdown:Refresh(getTeamList())
    end
    if RageControls.SilentAimIgnoreTeamsDropdown and RageControls.SilentAimIgnoreTeamsDropdown.Refresh then
        RageControls.SilentAimIgnoreTeamsDropdown:Refresh(getTeamList())
    end
    if VisualControls.ESPIgnoreTeamsDropdown and VisualControls.ESPIgnoreTeamsDropdown.Refresh then
        VisualControls.ESPIgnoreTeamsDropdown:Refresh(getTeamList())
    end
end)

Teams.ChildRemoved:Connect(function()
    task.wait(0.3)
    if RageControls.KillAuraIgnoreTeamsDropdown and RageControls.KillAuraIgnoreTeamsDropdown.Refresh then
        RageControls.KillAuraIgnoreTeamsDropdown:Refresh(getTeamList())
    end
    if RageControls.SilentAimIgnoreTeamsDropdown and RageControls.SilentAimIgnoreTeamsDropdown.Refresh then
        RageControls.SilentAimIgnoreTeamsDropdown:Refresh(getTeamList())
    end
    if VisualControls.ESPIgnoreTeamsDropdown and VisualControls.ESPIgnoreTeamsDropdown.Refresh then
        VisualControls.ESPIgnoreTeamsDropdown:Refresh(getTeamList())
    end
end)

-- Config tab info
ConfigTab:Paragraph({
    Title = "Config",
    Desc = "Configs são salvas automaticamente via Flags do WindUI na pasta RKZHUB/PAID.",
})

print("[RKZ Hub] Loaded successfully with WindUI")
