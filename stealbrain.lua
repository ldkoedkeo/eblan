local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")

-- Конфигурация
local ESP_SETTINGS = {
    UpdateInterval = 0.5,
    MaxDistance = 500,
    TextSize = 18,
    Font = Enum.Font.GothamBold,
    PartColors = {
        Color3.new(1, 1, 1),    -- Белый
        Color3.new(0.2, 0.6, 1),-- Синий
        Color3.new(1, 0.2, 0.2) -- Красный
    },
    SoundId = "rbxassetid://130785805",
    SoundVolume = 1.5,
    PlaySoundOnce = false
}

-- Список объектов с эмодзи
local OBJECT_EMOJIS = {
    ["La Vacca Saturno Saturnita"] = "🐮",
    ["Chimpanzini Spiderini"] = "🕷",
    ["Los Tralaleritos"] = "🐟",
    ["Las Tralaleritas"] = "🌸",
    ["Graipuss Medussi"] = "🦑",
    ["Torrtuginni Dragonfrutini"] = "🐉",
    ["Pot Hotspot"] = "📱",
    ["La Grande Combinasion"] = "❗️",
    ["Garama and Madundung"] = "🥫",
    ["Secret Lucky Block"] = "⬛️",
    ["Brainrot God Lucky Block"] = "🟦",
    ["Nuclearo Dinossauro"] = "🦕",
    ["Las Vaquitas Saturnitas"] = "👦",
    ["Chicleteira Bicicleteira"] = "🚲"
}

-- Список отслеживаемых объектов
local OBJECT_NAMES = {
    "La Vacca Saturno Saturnita",
    "Chimpanzini Spiderini",
    "Los Tralaleritos",
    "Las Tralaleritas",
    "Graipuss Medussi",
    "Torrtuginni Dragonfrutini",
    "Pot Hotspot",
    "La Grande Combinasion",
    "Garama and Madundung",
    "Secret Lucky Block",
    "Brainrot God Lucky Block",
    "Nuclearo Dinossauro",
    "Las Vaquitas Saturnitas",
    "Chicleteira Bicicleteira"
}

-- Системные переменные
local camera = workspace.CurrentCamera
local espCache = {}
local lastUpdate = 0
local foundObjects = {}

-- Создаем ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SimpleESP"
screenGui.Parent = CoreGui
screenGui.ResetOnSpawn = false

-- Создаем индикатор ESP: ON
local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "ESPStatus"
statusLabel.Text = "ESP: ON"
statusLabel.TextColor3 = Color3.fromRGB(50, 200, 50) -- Зеленый цвет
statusLabel.TextSize = 20
statusLabel.Font = Enum.Font.GothamBold
statusLabel.BackgroundTransparency = 1
statusLabel.Position = UDim2.new(0, 10, 0, 10)
statusLabel.Size = UDim2.new(0, 100, 0, 30)
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
statusLabel.TextStrokeTransparency = 0.5
statusLabel.Parent = screenGui

-- Функция воспроизведения звука обнаружения
local function playDetectionSound()
    local sound = Instance.new("Sound")
    sound.SoundId = ESP_SETTINGS.SoundId
    sound.Volume = ESP_SETTINGS.SoundVolume
    sound.Parent = workspace
    sound:Play()
    game:GetService("Debris"):AddItem(sound, 3)
end

-- Функция создания цветного текста
local function createColoredText(name)
    local emoji = OBJECT_EMOJIS[name] or "🔹"
    local displayName = emoji .. " " .. name
    
    local parts = {}
    for part in displayName:gmatch("%S+") do
        table.insert(parts, part)
    end
    
    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.TextSize = ESP_SETTINGS.TextSize
    textLabel.Font = ESP_SETTINGS.Font
    textLabel.TextXAlignment = Enum.TextXAlignment.Center
    textLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    textLabel.TextStrokeTransparency = 0.3
    
    local richText = ""
    for i, part in ipairs(parts) do
        local colorIndex = math.min(i, #ESP_SETTINGS.PartColors)
        local color = ESP_SETTINGS.PartColors[colorIndex]
        local hexColor = string.format(
            "rgb(%d,%d,%d)", 
            math.floor(color.r * 255),
            math.floor(color.g * 255),
            math.floor(color.b * 255)
        )
        richText = richText .. string.format('<font color="%s"><b>%s</b></font> ', hexColor, part)
    end
    
    textLabel.Text = richText
    textLabel.RichText = true
    
    return textLabel
end

-- Функция создания элемента ESP
local function createESPElement(obj)
    local rootPart = obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildWhichIsA("BasePart")) or obj
    if not rootPart then return end

    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(0, 350, 0, 50)
    billboard.AlwaysOnTop = true
    billboard.LightInfluence = 0
    billboard.MaxDistance = ESP_SETTINGS.MaxDistance
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    
    local textLabel = createColoredText(obj.Name)
    textLabel.Parent = billboard
    
    billboard.Adornee = rootPart
    billboard.Parent = screenGui
    
    return {
        labelGui = billboard,
        label = textLabel,
        rootPart = rootPart,
        object = obj
    }
end

-- Функция обновления ESP
local function updateESP(deltaTime)
    lastUpdate = lastUpdate + deltaTime
    if lastUpdate < ESP_SETTINGS.UpdateInterval then return end
    lastUpdate = 0

    -- Очистка несуществующих объектов
    for obj, data in pairs(espCache) do
        if not obj.Parent or not data.rootPart.Parent then
            data.labelGui:Destroy()
            espCache[obj] = nil
            foundObjects[obj] = nil
        end
    end

    -- Поиск новых объектов
    for _, obj in ipairs(workspace:GetDescendants()) do
        if table.find(OBJECT_NAMES, obj.Name) and (obj:IsA("BasePart") or obj:IsA("Model")) then
            local rootPart = obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildWhichIsA("BasePart")) or obj
            if not rootPart then continue end

            local distance = (rootPart.Position - camera.CFrame.Position).Magnitude
            if distance > ESP_SETTINGS.MaxDistance then
                if espCache[obj] then
                    espCache[obj].labelGui.Enabled = false
                end
                continue
            end

            local isNewObject = not foundObjects[obj]
            foundObjects[obj] = true

            if not espCache[obj] then
                espCache[obj] = createESPElement(obj)
                if isNewObject then
                    playDetectionSound()
                end
            end

            local data = espCache[obj]
            local screenPos, onScreen = camera:WorldToViewportPoint(rootPart.Position)
            data.labelGui.Enabled = onScreen
        end
    end
end

-- Запуск системы
RunService.Heartbeat:Connect(updateESP)

-- Обработка новых игроков
Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        updateESP(0)
    end)
end)

-- Первоначальное сканирование
updateESP(0)

print("Simple ESP System активирован!")
print("Отслеживается объектов: "..#OBJECT_NAMES)
