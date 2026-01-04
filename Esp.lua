local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"

local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

-- 1. ЗАГРУЗКА БИБЛИОТЕКИ ОТРИСОВКИ (MS-ESP)
-- Именно её использует mspaint
local ESPLibrary = loadstring(game:HttpGet("https://raw.githubusercontent.com/mstudio45/MS-ESP/refs/heads/main/source.lua"))()

local Window = Library:CreateWindow({
    Title = "NexusHack ESP ┃ Standalone",
    Footer = "mspaint copy",
    Icon = 95816097006870,
    NotifySide = "Right",
    ShowCustomCursor = true,
})

local Tabs = {
    Visuals = Window:AddTab("Visuals", "eye"),
    Settings = Window:AddTab("Settings", "settings"),
}

local Options = Library.Options
local Toggles = Library.Toggles

-- == ПЕРЕМЕННЫЕ И ТАБЛИЦЫ MSPAINT ==

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer

local gameData = ReplicatedStorage:WaitForChild("GameData")
local floor = gameData:WaitForChild("Floor")
local latestRoom = gameData:WaitForChild("LatestRoom")

local isMines = floor.Value == "Mines"
local isRooms = floor.Value == "Rooms"
local isHotel = floor.Value == "Hotel"
local isBackdoor = floor.Value == "Backdoor"
local isFools = floor.Value == "Fools"

local HidingPlaceName = {
    ["Hotel"] = "Closet",
    ["Backdoor"] = "Closet",
    ["Fools"] = "Closet",
    ["Rooms"] = "Locker",
    ["Mines"] = "Locker"
}

local EntityName = {"BackdoorRush", "BackdoorLookman", "RushMoving", "AmbushMoving", "Eyes", "JeffTheKiller", "A60", "A120"}
local SideEntityName = {"FigureRig", "GiggleCeiling", "GrumbleRig", "Snare"}
local ShortNames = {
    ["BackdoorRush"] = "Blitz",
    ["JeffTheKiller"] = "Jeff The Killer"
}
local SlotsName = {"Oval", "Square", "Tall", "Wide"}

-- Структура скрипта (как в mspaint)
local Script = {
    ESPTable = {
        Chest = {},
        Door = {},
        Entity = {},
        SideEntity = {},
        Gold = {},
        Guiding = {},
        Item = {},
        Objective = {},
        Player = {},
        HidingSpot = {},
        None = {}
    },
    Functions = {},
    FeatureConnections = {
        Player = {},
        Door = {},
    },
    Connections = {},
    Temp = {
        Guidance = {},
    }
}

-- == ФУНКЦИИ (КОПИЯ 1:1) ==

function Script.Functions.Warn(message: string)
    warn("WARN - NexusESP:", message)
end

function Script.Functions.GetShortName(entityName: string)
    if ShortNames[entityName] then
        return ShortNames[entityName]
    end

    local suffixPrefix = {
        ["Backdoor"] = "",
        ["Ceiling"] = "",
        ["Moving"] = "",
        ["Ragdoll"] = "",
        ["Rig"] = "",
        ["Wall"] = "",
        ["Clock"] = " Clock",
        ["Key"] = " Key",
        ["Pack"] = " Pack",
        ["Swarm"] = " Swarm",
    }

    for suffix, fix in pairs(suffixPrefix) do
        entityName = entityName:gsub(suffix, fix)
    end

    return entityName
end

function Script.Functions.ItemCondition(item)
    return item:IsA("Model") and (item:GetAttribute("Pickup") or item:GetAttribute("PropType")) and not item:GetAttribute("FuseID")
end

function Script.Functions.ESP(args)
    if not args.Object then return Script.Functions.Warn("ESP Object is nil") end

    local ESPManager = {
        Object = args.Object,
        Text = args.Text or "No Text",
        Color = args.Color or Color3.new(),
        Offset = args.Offset or Vector3.zero,
        IsDoubleDoor = args.IsDoubleDoor or false,
        Type = args.Type or "None"
    }

    local highlight = ESPLibrary.ESP.Highlight({
        Name = ESPManager.Text,
        Model = ESPManager.Object,
        StudsOffset = ESPManager.Offset,

        FillColor = ESPManager.Color,
        OutlineColor = ESPManager.Color,
        TextColor = ESPManager.Color,
        TextSize = Options.ESPTextSize.Value or 16,

        Tracer = {
            Enabled = Toggles.ESPTracer.Value,
            From = Options.ESPTracerStart.Value,
            Color = ESPManager.Color
        }
    })

    table.insert(Script.ESPTable[args.Type], highlight)
    return highlight
end

function Script.Functions.DoorESP(room)
    local door = room:WaitForChild("Door", 5)

    if door then
        local doorNumber = tonumber(room.Name) + 1
        if isMines then
            doorNumber += 100
        end

        local opened = door:GetAttribute("Opened")
        local locked = room:GetAttribute("RequiresKey")

        local doorState = if opened then " [Opened]" elseif locked then " [Locked]" else ""
        local doorEsp = Script.Functions.ESP({
            Type = "Door",
            Object = door:WaitForChild("Door"),
            Text = string.format("Door %s%s", doorNumber, doorState),
            Color = Options.DoorEspColor.Value
        })

        Script.Connections[room.Name .. "Opened"] = door:GetAttributeChangedSignal("Opened"):Connect(function()
            if doorEsp then doorEsp.SetText(string.format("Door %s [Opened]", doorNumber)) end
        end)
    end
end 

function Script.Functions.ObjectiveESP(child)
    if child.Name == "TimerLever" then
        Script.Functions.ESP({
            Type = "Objective",
            Object = child,
            Text = string.format("Timer Lever [+%s]", child.TakeTimer.TextLabel.Text),
            Color = Options.ObjectiveEspColor.Value
        })
    elseif child.Name == "KeyObtain" then
        Script.Functions.ESP({
            Type = "Objective",
            Object = child,
            Text = "Key",
            Color = Options.ObjectiveEspColor.Value
        })
    elseif child.Name == "ElectricalKeyObtain" then
        Script.Functions.ESP({
            Type = "Objective",
            Object = child,
            Text = "Electrical Key",
            Color = Options.ObjectiveEspColor.Value
        })
    elseif child.Name == "LeverForGate" then
        Script.Functions.ESP({
            Type = "Objective",
            Object = child,
            Text = "Gate Lever",
            Color = Options.ObjectiveEspColor.Value
        })
    elseif child.Name == "LiveHintBook" then
        Script.Functions.ESP({
            Type = "Objective",
            Object = child,
            Text = "Book",
            Color = Options.ObjectiveEspColor.Value
        })
    elseif child.Name == "LiveBreakerPolePickup" then
        Script.Functions.ESP({
            Type = "Objective",
            Object = child,
            Text = "Breaker",
            Color = Options.ObjectiveEspColor.Value
        })
    elseif child.Name == "MinesGenerator" then
        Script.Functions.ESP({
            Type = "Objective",
            Object = child,
            Text = "Generator",
            Color = Options.ObjectiveEspColor.Value
        })
    elseif child.Name == "MinesGateButton" then
        Script.Functions.ESP({
            Type = "Objective",
            Object = child,
            Text = "Gate Power Button",
            Color = Options.ObjectiveEspColor.Value
        })
    elseif child.Name == "FuseObtain" then
        Script.Functions.ESP({
            Type = "Objective",
            Object = child,
            Text = "Fuse",
            Color = Options.ObjectiveEspColor.Value
        })
    elseif child.Name == "MinesAnchor" then
        local sign = child:WaitForChild("Sign", 5)

        if sign and sign:FindFirstChild("TextLabel") then
            Script.Functions.ESP({
                Type = "Objective",
                Object = child,
                Text = string.format("Anchor %s", sign.TextLabel.Text),
                Color = Options.ObjectiveEspColor.Value
            })
        end
    elseif child.Name == "WaterPump" then
        local wheel = child:WaitForChild("Wheel", 5)

        if wheel then
            Script.Functions.ESP({
                Type = "Objective",
                Object = wheel,
                Text = "Water Pump",
                Color = Options.ObjectiveEspColor.Value
            })
        end
    end
end

function Script.Functions.EntityESP(entity)
    Script.Functions.ESP({
        Type = "Entity",
        Object = entity,
        Text = Script.Functions.GetShortName(entity.Name),
        Color = Options.EntityEspColor.Value,
        IsEntity = entity.Name ~= "JeffTheKiller",
    })
end

function Script.Functions.SideEntityESP(entity)
    Script.Functions.ESP({
        Type = "SideEntity",
        Object = entity,
        Text = Script.Functions.GetShortName(entity.Name),
        TextParent = entity.PrimaryPart,
        Color = Options.EntityEspColor.Value,
    })
end

function Script.Functions.ItemESP(item)
    Script.Functions.ESP({
        Type = "Item",
        Object = item,
        Text = Script.Functions.GetShortName(item.Name),
        Color = Options.ItemEspColor.Value
    })
end

function Script.Functions.ChestESP(chest)
    local locked = chest:GetAttribute("Locked")

    Script.Functions.ESP({
        Type = "Chest",
        Object = chest,
        Text = if locked then "Chest [Locked]" else "Chest",
        Color = Options.ChestEspColor.Value
    })
end

function Script.Functions.PlayerESP(player)
    if not (player.Character and player.Character.PrimaryPart and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0) then return end

    local playerEsp = Script.Functions.ESP({
        Type = "Player",
        Object = player.Character,
        Text = string.format("%s [%.1f]", player.DisplayName, player.Character.Humanoid.Health),
        TextParent = player.Character.PrimaryPart,
        Color = Options.PlayerEspColor.Value
    })

    Script.FeatureConnections.Player[player.Name] = player.Character.Humanoid.HealthChanged:Connect(function(newHealth)
        if newHealth > 0 then
            playerEsp.SetText(string.format("%s [%.1f]", player.DisplayName, newHealth))
        else
            if Script.FeatureConnections.Player[player.Name] then Script.FeatureConnections.Player[player.Name]:Disconnect() end
            playerEsp.Destroy()
        end
    end)
end

function Script.Functions.HidingSpotESP(spot)
    Script.Functions.ESP({
        Type = "HidingSpot",
        Object = spot,
        Text = if spot:GetAttribute("LoadModule") == "Bed" then "Bed" else HidingPlaceName[floor.Value] or "Closet",
        Color = Options.HidingSpotEspColor.Value
    })
end

function Script.Functions.GoldESP(gold)
    Script.Functions.ESP({
        Type = "Gold",
        Object = gold,
        Text = string.format("Gold [%s]", gold:GetAttribute("GoldValue")),
        Color = Options.GoldEspColor.Value
    })
end

function Script.Functions.GuidingLightEsp(guidance)
    local part = guidance:Clone()
    part.Anchored = true
    part.Size = Vector3.new(3, 3, 3)
    part.Transparency = 0.5
    part.Name = "_Guidance"

    part:ClearAllChildren()
    part.Parent = workspace

    Script.Temp.Guidance[guidance] = part

    local guidanceEsp = Script.Functions.ESP({
        Type = "Guiding",
        Object = part,
        Text = "Guidance",
        Color = Options.GuidingLightEspColor.Value
    })

    guidance.AncestryChanged:Connect(function()
        if not guidance:IsDescendantOf(workspace) then
            if Script.Temp.Guidance[guidance] then Script.Temp.Guidance[guidance] = nil end
            if part then part:Destroy() end
            if guidanceEsp then guidanceEsp.Destroy() end
        end
    end)
end

-- == ИНТЕРФЕЙС (OBSIDIAN UI) ==

local ESPTabBox = Tabs.Visuals:AddLeftTabbox() 
local ESPTab = ESPTabBox:AddTab("ESP")
local ESPSettingsTab = ESPTabBox:AddTab("Settings")

ESPTab:AddToggle("DoorESP", {Text = "Door", Default = false}):AddColorPicker("DoorEspColor", {Default = Color3.new(0, 1, 1)})
ESPTab:AddToggle("ObjectiveESP", {Text = "Objective", Default = false}):AddColorPicker("ObjectiveEspColor", {Default = Color3.new(0, 1, 0)})
ESPTab:AddToggle("EntityESP", {Text = "Entity", Default = false}):AddColorPicker("EntityEspColor", {Default = Color3.new(1, 0, 0)})
ESPTab:AddToggle("ItemESP", {Text = "Item", Default = false}):AddColorPicker("ItemEspColor", {Default = Color3.new(1, 0, 1)})
ESPTab:AddToggle("ChestESP", {Text = "Chest", Default = false}):AddColorPicker("ChestEspColor", {Default = Color3.new(1, 1, 0)})
ESPTab:AddToggle("PlayerESP", {Text = "Player", Default = false}):AddColorPicker("PlayerEspColor", {Default = Color3.new(1, 1, 1)})
ESPTab:AddToggle("HidingSpotESP", {Text = "Hiding Spot", Default = false}):AddColorPicker("HidingSpotEspColor", {Default = Color3.new(0, 0.5, 0)})
ESPTab:AddToggle("GoldESP", {Text = "Gold", Default = false}):AddColorPicker("GoldEspColor", {Default = Color3.new(1, 1, 0)})
ESPTab:AddToggle("GuidingLightESP", {Text = "Guiding Light", Default = false}):AddColorPicker("GuidingLightEspColor", {Default = Color3.new(0, 0.5, 1)})

ESPSettingsTab:AddToggle("ESPHighlight", {Text = "Enable Highlight", Default = true})
ESPSettingsTab:AddToggle("ESPTracer", {Text = "Enable Tracer", Default = true})
ESPSettingsTab:AddToggle("ESPRainbow", {Text = "Rainbow ESP", Default = false})
ESPSettingsTab:AddSlider("ESPFillTransparency", {Text = "Fill Transparency", Default = 0.75, Min = 0, Max = 1, Rounding = 2})
ESPSettingsTab:AddSlider("ESPOutlineTransparency", {Text = "Outline Transparency", Default = 0, Min = 0, Max = 1, Rounding = 2})
ESPSettingsTab:AddSlider("ESPTextSize", {Text = "Text Size", Default = 22, Min = 16, Max = 26, Rounding = 0})
ESPSettingsTab:AddDropdown("ESPTracerStart", {AllowNull = false, Values = {"Bottom", "Center", "Top", "Mouse"}, Default = "Bottom", Multi = false, Text = "Tracer Start Position"})

-- == ЛОГИКА ОБНОВЛЕНИЯ ==

-- Настройки
Toggles.ESPHighlight:OnChanged(function(value)
    for _, espType in pairs(Script.ESPTable) do
        for _, esp in pairs(espType) do esp.SetVisible(value, false) end
    end
end)
Toggles.ESPTracer:OnChanged(function(value) ESPLibrary.Tracers.Set(value) end)
Toggles.ESPRainbow:OnChanged(function(value) ESPLibrary.Rainbow.Set(value) end)
Options.ESPFillTransparency:OnChanged(function(value)
    for _, espType in pairs(Script.ESPTable) do for _, esp in pairs(espType) do esp.Update({ FillTransparency = value }) end end
end)
Options.ESPOutlineTransparency:OnChanged(function(value)
    for _, espType in pairs(Script.ESPTable) do for _, esp in pairs(espType) do esp.Update({ OutlineTransparency = value }) end end
end)
Options.ESPTextSize:OnChanged(function(value)
    for _, espType in pairs(Script.ESPTable) do for _, esp in pairs(espType) do esp.Update({ TextSize = value }) end end
end)
Options.ESPTracerStart:OnChanged(function(value)
    for _, espType in pairs(Script.ESPTable) do for _, esp in pairs(espType) do esp.Update({ Tracer = { From = value } }) end end
end)

-- Обновление цветов
local function UpdateColor(optionName, espTableKey)
    Options[optionName]:OnChanged(function(value)
        for _, esp in pairs(Script.ESPTable[espTableKey]) do
            esp.Update({ FillColor = value, OutlineColor = value, TextColor = value })
        end
    end)
end
UpdateColor("DoorEspColor", "Door")
UpdateColor("ObjectiveEspColor", "Objective")
UpdateColor("EntityEspColor", "Entity")
UpdateColor("EntityEspColor", "SideEntity")
UpdateColor("ItemEspColor", "Item")
UpdateColor("ChestEspColor", "Chest")
UpdateColor("PlayerEspColor", "Player")
UpdateColor("HidingSpotEspColor", "HidingSpot")
UpdateColor("GoldEspColor", "Gold")
UpdateColor("GuidingLightEspColor", "Guiding")

-- Сканирование комнаты
local function UpdateRoomESP()
    local currentRoom = LocalPlayer:GetAttribute("CurrentRoom")
    local nextRoom = currentRoom + 1
    local currentRoomModel = Workspace.CurrentRooms:FindFirstChild(currentRoom)
    local nextRoomModel = Workspace.CurrentRooms:FindFirstChild(nextRoom)

    -- Очистка
    if Toggles.DoorESP.Value then for _, e in pairs(Script.ESPTable.Door) do e.Destroy() end end
    if Toggles.ObjectiveESP.Value then for _, e in pairs(Script.ESPTable.Objective) do e.Destroy() end end
    if Toggles.EntityESP.Value then for _, e in pairs(Script.ESPTable.SideEntity) do e.Destroy() end end
    if Toggles.ItemESP.Value then for _, e in pairs(Script.ESPTable.Item) do e.Destroy() end end
    if Toggles.ChestESP.Value then for _, e in pairs(Script.ESPTable.Chest) do e.Destroy() end end
    if Toggles.HidingSpotESP.Value then for _, e in pairs(Script.ESPTable.HidingSpot) do e.Destroy() end end
    if Toggles.GoldESP.Value then for _, e in pairs(Script.ESPTable.Gold) do e.Destroy() end end

    -- Отрисовка
    if Toggles.DoorESP.Value then
        if currentRoomModel then task.spawn(Script.Functions.DoorESP, currentRoomModel) end
        if nextRoomModel then task.spawn(Script.Functions.DoorESP, nextRoomModel) end
    end

    if currentRoomModel then
        for _, asset in pairs(currentRoomModel:GetDescendants()) do
            if Toggles.ObjectiveESP.Value then task.spawn(Script.Functions.ObjectiveESP, asset) end
            if Toggles.EntityESP.Value and table.find(SideEntityName, asset.Name) then task.spawn(Script.Functions.SideEntityESP, asset) end
            if Toggles.ItemESP.Value and Script.Functions.ItemCondition(asset) then task.spawn(Script.Functions.ItemESP, asset) end
            if Toggles.ChestESP.Value and asset:GetAttribute("Storage") == "ChestBox" then task.spawn(Script.Functions.ChestESP, asset) end
            if Toggles.HidingSpotESP.Value and (asset:GetAttribute("LoadModule") == "Wardrobe" or asset:GetAttribute("LoadModule") == "Bed" or asset.Name == "Rooms_Locker") then Script.Functions.HidingSpotESP(asset) end
            if Toggles.GoldESP.Value and asset.Name == "GoldPile" then Script.Functions.GoldESP(asset) end
        end
    end
end

LocalPlayer:GetAttributeChangedSignal("CurrentRoom"):Connect(UpdateRoomESP)

-- Биндинг Тоглов
local function BindESP(toggleName)
    Toggles[toggleName]:OnChanged(function(val)
        if val then UpdateRoomESP() else 
            local key = toggleName:gsub("ESP", "")
            if key == "Door" then key = "Door"
            elseif key == "Entity" then key = "SideEntity"
            end
            
            if Script.ESPTable[key] then
                for _, e in pairs(Script.ESPTable[key]) do e.Destroy() end 
            end
            if key == "Entity" then -- очищаем и обычных энтити (Rush и тд)
                 for _, e in pairs(Script.ESPTable.Entity) do e.Destroy() end
            end
        end
    end)
end

BindESP("DoorESP")
BindESP("ObjectiveESP")
BindESP("EntityESP")
BindESP("ItemESP")
BindESP("ChestESP")
BindESP("HidingSpotESP")
BindESP("GoldESP")

Toggles.GuidingLightESP:OnChanged(function(val)
    if val then
        for _, g in pairs(Workspace.CurrentCamera:GetChildren()) do
            if g.Name == "Guidance" then Script.Functions.GuidingLightEsp(g) end
        end
    else
        for _, e in pairs(Script.ESPTable.Guiding) do e.Destroy() end
    end
end)

-- Глобальные события
Workspace.Drops.ChildAdded:Connect(function(child)
    if Toggles.ItemESP.Value and Script.Functions.ItemCondition(child) then Script.Functions.ItemESP(child) end
end)

Workspace.ChildAdded:Connect(function(child)
    if Toggles.EntityESP.Value then
        if table.find(EntityName, child.Name) then
            task.spawn(function()
                repeat task.wait() until (LocalPlayer.Character.HumanoidRootPart.Position - child:GetPivot().Position).Magnitude < 2000 or not child.Parent
                if child.Parent then Script.Functions.EntityESP(child) end
            end)
        end
    end
end)

-- Разгрузка
Library:OnUnload(function()
    for _, espType in pairs(Script.ESPTable) do
        for _, esp in pairs(espType) do
            esp.Destroy()
        end
    end
    print("ESP Unloaded")
end)

-- Тема
ThemeManager:SetLibrary(Library)
ThemeManager:SetFolder("NexusESP")
ThemeManager:ApplyToTab(Tabs.Settings)
