local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
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

-- Настройка расстояния ближнего боя для красных врагов
local CLOSE_RADIUS = 40 

-- Секретное имя тега, которое будут искать читеры друг у друга
local SCRIPT_USER_TAG = "ChamsNetUser_v2"

-- Таблица для отслеживания текущих анимаций
local activeTweens = {}

-- Настройка параметров луча (Raycast)
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.IgnoreWater = true

-- ФУНКЦИЯ МАРКИРОВКИ: Вешаем скрытый знак на своего персонажа
local function tagMyself()
    local char = LocalPlayer.Character
    if char and not CollectionService:HasTag(char, SCRIPT_USER_TAG) then
        CollectionService:AddTag(char, SCRIPT_USER_TAG)
    end
end

-- Перепривязываем тег при каждом спавне, так как персонаж создается заново
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5) -- Ждем загрузки персонажа
    tagMyself()
end)
tagMyself() -- Вешаем тег при первом запуске

-- Функция проверки: использует ли другой игрок этот чит
local function isScriptUser(player)
    local char = player.Character
    if char then
        -- Проверяем, есть ли у его персонажа скрытый тег
        if CollectionService:HasTag(char, SCRIPT_USER_TAG) then
            return true
        end
        -- Дополнительная проверка на случай, если тег скрыли внутри хитбоксов
        if char:FindFirstChild(SCRIPT_USER_TAG) or char:FindFirstChild("HumanoidRootPart") and char.HumanoidRootPart:FindFirstChild(SCRIPT_USER_TAG) then
            return true
        end
    end
    return false
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

-- Дополнительный цикл для жесткой синхронизации тега через физику (на случай строгой фильтрации)
task.spawn(function()
    while task.wait(3) do
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            if not char.HumanoidRootPart:FindFirstChild(SCRIPT_USER_TAG) then
                local physicalMarker = Instance.new("StringValue")
                physicalMarker.Name = SCRIPT_USER_TAG
                physicalMarker.Value = "Verified"
                physicalMarker.Parent = char.HumanoidRootPart
            end
        end
    end
end)

-- Главный цикл
RunService.RenderStepped:Connect(function()
    local myChar = LocalPlayer.Character
    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local isEnemy = (not LocalPlayer.Team or player.Team ~= LocalPlayer.Team)
            
            if player.Character and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0 and player.Character:FindFirstChild("HumanoidRootPart") then
                
                local isUser = isScriptUser(player)
                local finalColor = isUser and USER_COLOR or ENEMY_COLOR
                local shouldShow = isEnemy or isUser

                if shouldShow then
                    createHighlight(player, finalColor)
                    
                    local distance = myHrp and (player.Character.HumanoidRootPart.Position - myHrp.Position).Magnitude or 99999
                    local visible = false
                    
                    if isUser then
                        -- Зеленые читеры видны СКВОЗЬ ВСЕ СТЕНЫ и всегда на любой дистанции
                        visible = true
                    else
                        -- Обычные враги работают по твоей идеальной логике
                        if distance <= CLOSE_RADIUS then
                            visible = true 
                        else
                            visible = isInFOV(player) and not isBehindWall(player) 
                        end
                    end
                    
                    fadeChams(player, visible)
                else
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

-- Очистка кэша
Players.PlayerRemoving:Connect(function(player)
    activeTweens[player] = nil
end)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
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

-- Настройка расстояния ближнего боя для красных врагов
local CLOSE_RADIUS = 40 

-- Секретное имя тега, которое будут искать читеры друг у друга
local SCRIPT_USER_TAG = "ChamsNetUser_v2"

-- Таблица для отслеживания текущих анимаций
local activeTweens = {}

-- Настройка параметров луча (Raycast)
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.IgnoreWater = true

-- ФУНКЦИЯ МАРКИРОВКИ: Вешаем скрытый знак на своего персонажа
local function tagMyself()
    local char = LocalPlayer.Character
    if char and not CollectionService:HasTag(char, SCRIPT_USER_TAG) then
        CollectionService:AddTag(char, SCRIPT_USER_TAG)
    end
end

-- Перепривязываем тег при каждом спавне, так как персонаж создается заново
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5) -- Ждем загрузки персонажа
    tagMyself()
end)
tagMyself() -- Вешаем тег при первом запуске

-- Функция проверки: использует ли другой игрок этот чит
local function isScriptUser(player)
    local char = player.Character
    if char then
        -- Проверяем, есть ли у его персонажа скрытый тег
        if CollectionService:HasTag(char, SCRIPT_USER_TAG) then
            return true
        end
        -- Дополнительная проверка на случай, если тег скрыли внутри хитбоксов
        if char:FindFirstChild(SCRIPT_USER_TAG) or char:FindFirstChild("HumanoidRootPart") and char.HumanoidRootPart:FindFirstChild(SCRIPT_USER_TAG) then
            return true
        end
    end
    return false
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

-- Дополнительный цикл для жесткой синхронизации тега через физику (на случай строгой фильтрации)
task.spawn(function()
    while task.wait(3) do
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            if not char.HumanoidRootPart:FindFirstChild(SCRIPT_USER_TAG) then
                local physicalMarker = Instance.new("StringValue")
                physicalMarker.Name = SCRIPT_USER_TAG
                physicalMarker.Value = "Verified"
                physicalMarker.Parent = char.HumanoidRootPart
            end
        end
    end
end)

-- Главный цикл
RunService.RenderStepped:Connect(function()
    local myChar = LocalPlayer.Character
    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local isEnemy = (not LocalPlayer.Team or player.Team ~= LocalPlayer.Team)
            
            if player.Character and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0 and player.Character:FindFirstChild("HumanoidRootPart") then
                
                local isUser = isScriptUser(player)
                local finalColor = isUser and USER_COLOR or ENEMY_COLOR
                local shouldShow = isEnemy or isUser

                if shouldShow then
                    createHighlight(player, finalColor)
                    
                    local distance = myHrp and (player.Character.HumanoidRootPart.Position - myHrp.Position).Magnitude or 99999
                    local visible = false
                    
                    if isUser then
                        -- Зеленые читеры видны СКВОЗЬ ВСЕ СТЕНЫ и всегда на любой дистанции
                        visible = true
                    else
                        -- Обычные враги работают по твоей идеальной логике
                        if distance <= CLOSE_RADIUS then
                            visible = true 
                        else
                            visible = isInFOV(player) and not isBehindWall(player) 
                        end
                    end
                    
                    fadeChams(player, visible)
                else
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

-- Очистка кэша
Players.PlayerRemoving:Connect(function(player)
    activeTweens[player] = nil
end)
