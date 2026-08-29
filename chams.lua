local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- Настройки чамсов
local CHAMS_OUTLINE = Color3.fromRGB(255, 255, 255)
local TARGET_FILL_TRANS = 0.5
local TARGET_OUTLINE_TRANS = 0
local TWEEN_DURATION = 0.15 

-- ЦВЕТА
local ENEMY_COLOR = Color3.fromRGB(255, 0, 0)      -- Красный для обычных врагов
local USER_COLOR = Color3.fromRGB(0, 255, 0)       -- Зеленый для юзеров этого скрипта

-- Настройка дистанции ближнего боя
local CLOSE_RADIUS = 40 

-- Таблица для отслеживания текущих анимаций
local activeTweens = {}

-- Настройка параметров луча (Raycast)
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.IgnoreWater = true

-- СЕТЕВАЯ СИНХРОНИЗАЦИЯ ЮЗЕРОВ (Создаем невидимую папку для тегов)
local networkFolder = ReplicatedStorage:FindFirstChild("ScriptUsersNetwork")
if not networkFolder then
    networkFolder = Instance.new("Folder")
    networkFolder.Name = "ScriptUsersNetwork"
    networkFolder.Parent = ReplicatedStorage
end

-- Регистрируем себя в сети юзеров
local myTag = networkFolder:FindFirstChild(LocalPlayer.Name)
if not myTag then
    myTag = Instance.new("BoolValue")
    myTag.Name = LocalPlayer.Name
    myTag.Parent = networkFolder
end

-- Функция проверки: использует ли другой игрок этот скрипт прямо сейчас
local function isScriptUser(player)
    return networkFolder:FindFirstChild(player.Name) ~= nil
end

-- Функция создания подсветки
local function createHighlight(player, color)
    local char = player.Character
    if char then
        local highlight = char:FindFirstChild("VisibleChams")
        if not highlight then
            highlight = Instance.new("Highlight")
            highlight.Name = "VisibleChams"
            highlight.FillColor = color
            highlight.OutlineColor = CHAMS_OUTLINE
            highlight.FillTransparency = 1 
            highlight.OutlineTransparency = 1
            highlight.Adornee = char
            highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            highlight.Enabled = true 
            highlight.Parent = char
        else
            -- Если чамсы уже есть, но цвет должен измениться (например, челик только что заинжектил скрипт)
            if highlight.FillColor ~= color then
                highlight.FillColor = color
            end
        end
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
            
            if player.Character and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0 and player.Character:FindFirstChild("HumanoidRootPart") then
                
                -- ОПРЕДЕЛЯЕМ ЦВЕТ: Если юзер скрипта — зеленый (даже если он союзник!). Если просто враг — красный.
                local finalColor = ENEMY_COLOR
                local shouldShow = isEnemy

                if isScriptUser(player) then
                    finalColor = USER_COLOR
                    shouldShow = true -- Юзеров скрипта показываем ВСЕГДА, даже если они за твою команду
                end

                if shouldShow then
                    createHighlight(player, finalColor)
                    
                    local distance = myHrp and (player.Character.HumanoidRootPart.Position - myHrp.Position).Magnitude or 99999
                    
                    local visible = false
                    if distance <= CLOSE_RADIUS then
                        visible = true 
                    else
                        visible = isInFOV(player) and not isBehindWall(player) 
                    end
                    
                    fadeChams(player, visible)
                else
                    -- Если это твой союзник и он НЕ юзер скрипта — убираем чамсы
                    if activeTweens[player] then
                        activeTweens[player].Tween:Cancel()
                        activeTweens[player] = nil
                    end
                    local highlight = player.Character and player.Character:FindFirstChild("VisibleChams")
                    if highlight then highlight:Destroy() end
                end
            else
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

-- Удаление своего тега из сети при выходе из игры или ресете скрипта
Players.PlayerRemoving:Connect(function(player)
    activeTweens[player] = nil
    local userTag = networkFolder:FindFirstChild(player.Name)
    if userTag then userTag:Destroy() end
end)
