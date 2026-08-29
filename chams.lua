local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- ГЕНЕРАЦИЯ УНИКАЛЬНОГО ID ДЛЯ ТЕКУЩЕГО ЗАПУСКА
local scriptId = httpService and httpService:GenerateGUID(false) or tostring(math.random(100000, 999999))
getgenv().CurrentChamsScriptID = scriptId -- Перезаписываем глобальную переменную

-- НАСТРОЙКИ ЧАМСОВ
local CHAMS_COLOR = Color3.fromRGB(255, 0, 0)
local CHAMS_OUTLINE = Color3.fromRGB(255, 255, 255)
local TARGET_FILL_TRANS = 0.5
local TARGET_OUTLINE_TRANS = 0
local TWEEN_DURATION = 0.2

-- КЭШ И ОПТИМИЗАЦИЯ
local activeChams = {} 
local lastUpdateTime = 0
local UPDATE_INTERVAL = 0.1 

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.IgnoreWater = true

local tweenInfo = TweenInfo.new(TWEEN_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- Полная очистка чамсов (вызывается при остановке или удалении игрока)
local function removeChams(player)
    local data = activeChams[player]
    if data then
        if data.Tween then data.Tween:Cancel() end
        if data.Highlight then data.Highlight:Destroy() end
        activeChams[player] = nil
    end
end

-- Функция глобальной очистки при обнаружении нового скрипта
local function selfDestruct()
    for player in pairs(activeChams) do
        removeChams(player)
    end
    -- Также принудительно ищем оставшиеся объекты в персонажах (на всякий случай)
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character then
            local oldChams = player.Character:FindFirstChild("OptChams")
            if oldChams then oldChams:Destroy() end
        end
    end
end

local function getOrCreateChams(player)
    local data = activeChams[player]
    if data then return data end

    local char = player.Character
    if not char then return nil end

    local highlight = Instance.new("Highlight")
    highlight.Name = "OptChams"
    highlight.FillColor = CHAMS_COLOR
    highlight.OutlineColor = CHAMS_OUTLINE
    highlight.FillTransparency = 1
    highlight.OutlineTransparency = 1
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Adornee = char
    highlight.Enabled = true
    highlight.Parent = char

    activeChams[player] = {
        Highlight = highlight,
        IsVisible = false,
        Tween = nil
    }
    return activeChams[player]
end

local function setChamsVisibility(player, data, visible)
    if data.IsVisible == visible then return end 
    data.IsVisible = visible

    if data.Tween then data.Tween:Cancel() end

    local targetFill = visible and TARGET_FILL_TRANS or 1
    local targetOutline = visible and TARGET_OUTLINE_TRANS or 1

    data.Tween = TweenService:Create(data.Highlight, tweenInfo, {
        FillTransparency = targetFill,
        OutlineTransparency = targetOutline
    })
    data.Tween:Play()
end

local function isInFOV(hrp)
    local _, onScreen = Camera:WorldToViewportPoint(hrp.Position)
    return onScreen
end

local function isBehindWall(player, hrp)
    local origin = Camera.CFrame.Position
    local target = hrp.Position
    
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character, player.Character, Camera}
    local result = workspace:Raycast(origin, target - origin, raycastParams)
    
    if result and result.Instance then
        local hit = result.Instance
        if hit.CanCollide and hit.Transparency < 0.8 then
            return true
        end
    end
    return false
end

-- ГЛАВНЫЙ ЦИКЛ ОБНОВЛЕНИЯ
local connection
connection = RunService.Heartbeat:Connect(function()
    -- ПРОВЕРКА: Если в getgenv записан ID более нового скрипта, этот выключается
    if getgenv().CurrentChamsScriptID ~= scriptId then
        connection:Disconnect() -- Отключаем цикл Heartbeat
        selfDestruct()          -- Стираем все чамсы этой копии скрипта
        return
    end

    local currentTime = os.clock()
    if currentTime - lastUpdateTime < UPDATE_INTERVAL then return end
    lastUpdateTime = currentTime

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local char = player.Character
            local isEnemy = (not LocalPlayer.Team or player.Team ~= LocalPlayer.Team)
            
            if isEnemy and char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Humanoid") and char.Humanoid.Health > 0 then
                local hrp = char.HumanoidRootPart
                
                if not isInFOV(hrp) then
                    local data = activeChams[player]
                    if data then setChamsVisibility(player, data, false) end
                else
                    local data = getOrCreateChams(player)
                    if data then
                        local visible = not isBehindWall(player, hrp)
                        setChamsVisibility(player, data, visible)
                    end
                end
            else
                removeChams(player)
            end
        end
    end
end)

Players.PlayerRemoving:Connect(removeChams)
