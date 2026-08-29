local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- Настройки чамсов
local CHAMS_COLOR = Color3.fromRGB(255, 0, 0)
local CHAMS_OUTLINE = Color3.fromRGB(255, 255, 255)
local TARGET_FILL_TRANS = 0.5
local TARGET_OUTLINE_TRANS = 0
local TWEEN_DURATION = 0.15 -- Скорость плавного появления/исчезновения

-- Настройка дистанции ближнего боя
local CLOSE_RADIUS = 40 -- Внутри этого радиуса чамсы горят всегда (даже со спины и за стеной)

-- Таблица для отслеживания текущих анимаций
local activeTweens = {}

-- Настройка параметров луча (Raycast)
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.IgnoreWater = true

-- Функция создания подсветки
local function createHighlight(player)
    if player.Character and not player.Character:FindFirstChild("VisibleChams") then
        local highlight = Instance.new("Highlight")
        highlight.Name = "VisibleChams"
        highlight.FillColor = CHAMS_COLOR
        highlight.OutlineColor = CHAMS_OUTLINE
        highlight.FillTransparency = 1 -- Изначально скрыт для плавного появления
        highlight.OutlineTransparency = 1
        highlight.Adornee = player.Character
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.Enabled = true -- Всегда включен, управляем через прозрачность
        highlight.Parent = player.Character
    end
end

-- Функция плавного изменения прозрачности
local function fadeChams(player, visible)
    local char = player.Character
    if not char then return end
    
    local highlight = char:FindFirstChild("VisibleChams")
    if not highlight then return end
    
    local targetFill = visible and TARGET_FILL_TRANS or 1
    local targetOutline = visible and TARGET_OUTLINE_TRANS or 1
    
    if activeTweens[player] and activeTweens[player].TargetVisibility == visible then
        return
    end
    
    if activeTweens[player] then
        activeTweens[player].Tween:Cancel()
    end
    
    local tweenInfo = TweenInfo.new(TWEEN_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local tween = TweenService:Create(highlight, tweenInfo, {
        FillTransparency = targetFill,
        OutlineTransparency = targetOutline
    })
    
    activeTweens[player] = {
        Tween = tween,
        TargetVisibility = visible
    }
    
    tween:Play()
end

-- Проверка: виден ли игрок на экране
local function isInFOV(player)
    if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then 
        return false 
    end
    local _, onScreen = Camera:WorldToViewportPoint(player.Character.HumanoidRootPart.Position)
    return onScreen
end

-- Проверка: скрыт ли игрок НАСТОЯЩЕЙ стеной
local function isBehindWall(player)
    if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then 
        return true 
    end

    local origin = Camera.CFrame.Position
    local target = player.Character.HumanoidRootPart.Position
    local direction = target - origin
    
    -- ИСПРАВЛЕНИЕ: Игнорируем персонажей абсолютно всех игроков, чтобы луч не спотыкался о самого врага
    local ignoreList = {Camera, LocalPlayer.Character}
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character then table.insert(ignoreList, p.Character) end
    end
    raycastParams.FilterDescendantsInstances = ignoreList
    
    local result = workspace:Raycast(origin, direction, raycastParams)
    
    if result and result.Instance then
        local hit = result.Instance
        if hit.CanCollide == true and hit.Transparency < 0.8 then
            return true
        end
    end
    
    return false
end

-- Главный цикл
RunService.RenderStepped:Connect(function()
    local myChar = LocalPlayer.Character
    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local isEnemy = (not LocalPlayer.Team or player.Team ~= LocalPlayer.Team)
            
            if isEnemy and player.Character and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0 and player.Character:FindFirstChild("HumanoidRootPart") then
                createHighlight(player)
                
                -- Вычисляем дистанцию
                local distance = myHrp and (player.Character.HumanoidRootPart.Position - myHrp.Position).Magnitude or 99999
                
                local visible = false
                if distance <= CLOSE_RADIUS then
                    visible = true -- Если близко, то всегда видно
                else
                    visible = isInFOV(player) and not isBehindWall(player) -- Если далеко, проверяем FOV и стены
                end
                
                fadeChams(player, visible)
            else
                -- Очистка анимаций и удаление чамсов у мертвых/союзников
                if activeTweens[player] then
                    activeTweens[player].Tween:Cancel()
                    activeTweens[player] = nil
                end
                local highlight = player.Character and player.Character:FindFirstChild("VisibleChams")
                if highlight then highlight:Destroy() end
            end
        end
    end
end)

-- Очистка кэша при выходе игрока
Players.PlayerRemoving:Connect(function(player)
    activeTweens[player] = nil
end)
