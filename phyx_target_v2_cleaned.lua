-- ============================================================
-- PHYX TARGET SYSTEM v2 (Cleaned & Restructured)
-- Original: discord.gg/25ms | Obfuscated with LPH
-- Game: Da Hood / Hood Modded
-- ============================================================

-- LPH stubs (no-op when not obfuscated)
if not LPH_OBFUSCATED then
    function LPH_NO_VIRTUALIZE(...) return ... end
    function LPH_JIT_MAX(...) return ... end
    function LPH_JIT_ULTRA(...) return ... end
end

LPH_JIT_ULTRA(function()
    -- ============================================================
    -- SERVICES
    -- ============================================================
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local HttpService = game:GetService("HttpService")
    local TextService = game:GetService("TextService")
    local TweenService = game:GetService("TweenService")
    local Workspace = game:GetService("Workspace")
    local CoreGui = game:GetService("CoreGui")
    local GuiService = game:GetService("GuiService")
    local ServerStorage = game:GetService("ServerStorage")

    local LocalPlayer = Players.LocalPlayer
    local Camera = Workspace.CurrentCamera
    local Mouse = LocalPlayer:GetMouse()

    -- ============================================================
    -- CONFIG / STATE
    -- ============================================================
    local Config = getgenv().phyx_target
    local MainConfig = Config.Main
    local AimConfig = Config["Aim Assist"]
    local GuiConfig = Config.GUIs

    -- State variables
    local AimEnabled = false
    local TargetPlayer = nil
    local IsAirEnabled = false
    local IsBulletTPEnabled = false
    local IsMacroEnabled = false
    local IsTriggerEnabled = false
    local IsSpeedHacking = false
    local AirLocked = false

    local GuiCounter = 0
    local GuiRegistry = {}
    local SoundFolder = Instance.new("Folder", Workspace)
    local NotificationSystem = {}

    -- Prediction & resolver data
    local ResolverData = {
        OldPos = Vector3.zero,
        OldTick = tick(),
        ResolvedVelocity = Vector3.zero,
    }

    -- Air weapon whitelist
    local AirWeapons = { "Katana", "cookie", "knife" }

    -- Developer IDs
    local DEV_ID = 1428011334
    local SOUND_ID = 1079408535

    -- ============================================================
    -- COLOR PALETTE
    -- ============================================================
    local Theme = {
        FontColor      = Color3.fromRGB(255, 255, 255),
        MainColor      = Color3.fromRGB(28, 28, 28),
        BackgroundColor= Color3.fromRGB(20, 20, 20),
        AccentColor    = Color3.fromRGB(240, 196, 7),
        OutlineColor   = Color3.fromRGB(50, 50, 50),
        RiskColor      = Color3.fromRGB(255, 50, 50),
        Black          = Color3.new(0, 0, 0),
        Gold           = Color3.fromRGB(255, 215, 18),
        Blue           = Color3.fromRGB(9, 44, 99),
        DarkTheme      = Color3.fromRGB(30, 30, 30),
    }

    -- ============================================================
    -- UTILITY FUNCTIONS
    -- ============================================================

    -- Play a sound by Roblox asset ID
    local function playSound(soundId, volume)
        local sound = Instance.new("Sound")
        sound.SoundId = "rbxassetid://" .. tostring(soundId)
        sound.Volume = volume or 1
        sound.Parent = SoundFolder
        sound:Play()
        sound.Ended:Connect(function()
            sound:Destroy()
        end)
    end

    -- Play a custom sound from local file
    local function playCustomSound(filename, volume)
        local path = "phyx_sounds/" .. filename
        if not isfile(path) then
            warn("Sound file not found:", path)
            return
        end
        local sound = Instance.new("Sound")
        sound.SoundId = getcustomasset(path)
        sound.Volume = volume or 1
        sound.PlayOnRemove = true
        sound.Parent = Workspace
        sound:Destroy()
    end

    -- Get text bounds for UI sizing
    local function getTextBounds(text, font, size, maxSize)
        local bounds = TextService:GetTextSize(text, size, font, maxSize or Vector2.new(1920, 1080))
        return bounds.X, bounds.Y
    end

    -- Create an Instance with properties
    local function create(className, properties)
        local instance = Instance.new(className)
        for prop, value in pairs(properties) do
            instance[prop] = value
        end
        return instance
    end

    -- Get darker color variant
    local function getDarkerColor(color)
        local h, s, v = Color3.toHSV(color)
        return Color3.fromHSV(h, s, v / 1.5)
    end

    -- ============================================================
    -- GUI POSITION SAVE/LOAD
    -- ============================================================

    local SAVE_FILE = "phyx_by_pluh.txt"

    local function loadGuiPositions()
        if not GuiConfig["Save Position"] or not isfile(SAVE_FILE) then
            return {}
        end
        local success, data = pcall(function()
            return HttpService:JSONDecode(readfile(SAVE_FILE))
        end)
        if success and data then
            local positions = {}
            for name, pos in pairs(data) do
                positions[name] = UDim2.new(0, pos.X, 0, pos.Y)
            end
            return positions
        end
        return {}
    end

    local function saveGuiPositions(positions)
        local data = {}
        for name, pos in pairs(loadGuiPositions()) do
            data[name] = { X = pos.X.Offset, Y = pos.Y.Offset }
        end
        for name, pos in pairs(positions) do
            data[name] = { X = pos.X.Offset, Y = pos.Y.Offset }
        end
        writefile(SAVE_FILE, HttpService:JSONEncode(data))
    end

    local function resetGuiPositions()
        if isfile(SAVE_FILE) then
            delfile(SAVE_FILE)
        end
        saveGuiPositions({})
        for name, gui in pairs(GuiRegistry) do
            gui.Frame.Position = UDim2.new(0, 10 + gui.Counter * 110, 0, 10)
        end
        print("GUI positions reset to defaults.")
    end

    -- ============================================================
    -- NOTIFICATION SYSTEM
    -- ============================================================

    local ScreenGui = create("ScreenGui", {
        Name = "PhyxNotifications",
        Parent = CoreGui,
        ZIndexBehavior = Enum.ZIndexBehavior.Global,
    })

    -- Protect GUI from screen capture
    local protect = protectgui or (syn and syn.protect_gui) or function() end
    protect(ScreenGui)

    local NotificationArea = create("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, 40),
        Size = UDim2.new(0, 300, 0, 200),
        ZIndex = 100,
        Parent = ScreenGui,
    })

    create("UIListLayout", {
        Padding = UDim.new(0, 4),
        FillDirection = Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = NotificationArea,
    })

    function NotificationSystem:Notify(text, duration)
        if not MainConfig.Notification then return end

        local width, height = getTextBounds(text, Enum.Font.Code, 14)
        local totalHeight = height + 7

        local frame = create("Frame", {
            BorderColor3 = Theme.Black,
            Position = UDim2.new(0, 100, 0, 10),
            Size = UDim2.new(0, 0, 0, totalHeight),
            ClipsDescendants = true,
            ZIndex = 100,
            Parent = NotificationArea,
        })

        local inner = create("Frame", {
            BackgroundColor3 = Theme.MainColor,
            BorderColor3 = Theme.OutlineColor,
            BorderMode = Enum.BorderMode.Inset,
            Size = UDim2.new(1, 0, 1, 0),
            ZIndex = 101,
            Parent = frame,
        })

        local content = create("Frame", {
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0,
            Position = UDim2.new(0, 1, 0, 1),
            Size = UDim2.new(1, -2, 1, -2),
            ZIndex = 102,
            Parent = inner,
        })

        create("UIGradient", {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, getDarkerColor(Theme.MainColor)),
                ColorSequenceKeypoint.new(1, Theme.MainColor),
            }),
            Rotation = -90,
            Parent = content,
        })

        create("TextLabel", {
            BackgroundTransparency = 1,
            Font = Enum.Font.Code,
            TextColor3 = Theme.FontColor,
            TextSize = 14,
            TextStrokeTransparency = 0,
            Position = UDim2.new(0, 4, 0, 0),
            Size = UDim2.new(1, -4, 1, 0),
            Text = text,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 103,
            Parent = content,
        })

        create("Frame", {
            BackgroundColor3 = Theme.AccentColor,
            BorderSizePixel = 0,
            Position = UDim2.new(0, -1, 0, -1),
            Size = UDim2.new(0, 3, 1, 2),
            ZIndex = 104,
            Parent = frame,
        })

        pcall(frame.TweenSize, frame, UDim2.new(0, width + 12, 0, totalHeight), "Out", "Quad", 0.4, true)

        task.spawn(function()
            task.wait(duration or 5)
            pcall(frame.TweenSize, frame, UDim2.new(0, 0, 0, totalHeight), "Out", "Quad", 0.4, true)
            task.wait(0.4)
            frame:Destroy()
        end)
    end

    -- ============================================================
    -- DRAGGABLE GUI BUTTON CREATOR
    -- ============================================================

    local function createGuiButton(name, size, color, text, callback)
        local savedPositions = loadGuiPositions()
        local defaultPos = UDim2.new(0, 10 + GuiCounter * 110, 0, 10)

        local gui = create("ScreenGui", {
            Name = name,
            Parent = CoreGui,
        })

        local frame = create("Frame", {
            Size = size,
            Position = savedPositions[name] or defaultPos,
            BackgroundColor3 = color,
            Active = true,
            Draggable = true,
            Parent = gui,
        })

        create("UIStroke", {
            Color = Theme.Black,
            Thickness = 2,
            Parent = frame,
        })

        create("UICorner", {
            CornerRadius = UDim.new(0, 10),
            Parent = frame,
        })

        local btnWidth, btnHeight, btnX, btnY
        if size ~= UDim2.new(0, 100, 0, 50) then
            btnWidth = size.X.Offset - 10
            btnHeight = size.Y.Offset - 10
            btnX, btnY = 5, 5
        else
            btnWidth, btnHeight = 80, 30
            btnX = (size.X.Offset - btnWidth) / 2
            btnY = (size.Y.Offset - btnHeight) / 2
        end

        local button = create("TextButton", {
            Size = UDim2.new(0, btnWidth, 0, btnHeight),
            Position = UDim2.new(0, btnX, 0, btnY),
            Text = text or "Button",
            Font = Enum.Font.Fantasy,
            TextScaled = true,
            TextWrapped = true,
            TextColor3 = Theme.Gold,
            BackgroundColor3 = Theme.Black,
            Parent = frame,
        })

        create("UIPadding", {
            PaddingTop = UDim.new(0, 2),
            PaddingBottom = UDim.new(0, 2),
            PaddingLeft = UDim.new(0, 2),
            PaddingRight = UDim.new(0, 2),
            Parent = button,
        })

        create("UICorner", {
            CornerRadius = UDim.new(0, 10),
            Parent = button,
        })

        button.MouseButton1Click:Connect(callback)

        frame:GetPropertyChangedSignal("Position"):Connect(function()
            local positions = loadGuiPositions()
            positions[name] = frame.Position
            saveGuiPositions(positions)
        end)

        GuiRegistry[name] = {
            Frame = frame,
            Counter = GuiCounter,
        }
        GuiCounter += 1

        return button, frame
    end

    -- ============================================================
    -- AIMBOT / SILENT AIM LOGIC
    -- ============================================================

    -- Get closest player to screen center
    local function getClosestPlayerToCursor()
        local closestDist = math.huge
        local closestPlayer = nil
        local screenCenter = Vector2.new(
            GuiService:GetScreenResolution().X / 2,
            GuiService:GetScreenResolution().Y / 2
        )

        for _, player in ipairs(Players:GetPlayers()) do
            if player == LocalPlayer then continue end

            local character = player.Character
            if not character then continue end

            local hrp = character:FindFirstChild("HumanoidRootPart")
            local humanoid = character:FindFirstChild("Humanoid")
            if not hrp or not humanoid or humanoid.Health <= 0 then continue end

            local pos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
            if not onScreen then continue end

            local dist = (screenCenter - Vector2.new(pos.X, pos.Y)).Magnitude
            if dist < closestDist then
                closestPlayer = player
                closestDist = dist
            end
        end

        return closestPlayer
    end

    -- Check if player is in air (velocity-based)
    local function isInAir(player)
        if not player or not player.Character then return false end
        local velocity = player.Character.HumanoidRootPart.Velocity
        return velocity.Y < -70
            or velocity.X > 450 or velocity.X < -35
            or velocity.Y > 60
            or velocity.Z > 35 or velocity.Z < -35
    end

    -- Resolver: smooth velocity calculation
    local function updateResolver()
        if not TargetPlayer or not TargetPlayer.Character then return end
        local hrp = TargetPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        local now = tick()
        local delta = now - ResolverData.OldTick
        if delta == 0 then return end

        local velocity = (hrp.Position - ResolverData.OldPos) / delta
        local smoothness = MainConfig["Resolver Smoothness"] or 0.145

        ResolverData.ResolvedVelocity = (ResolverData.ResolvedVelocity or Vector3.zero)
            + (velocity - (ResolverData.ResolvedVelocity or Vector3.zero)) * smoothness
        ResolverData.OldPos = hrp.Position
        ResolverData.OldTick = now
    end

    -- Calculate predicted position
    local function getPredictedPosition(partName)
        local targetPart = TargetPlayer.Character[partName]
        local velocity = isInAir(TargetPlayer)
            and Vector3.new(
                ResolverData.ResolvedVelocity.X * HorizontalPrediction,
                math.clamp(ResolverData.ResolvedVelocity.Y, -23, 50) * VerticalPrediction,
                ResolverData.ResolvedVelocity.Z * HorizontalPrediction
            )
            or Vector3.new(
                TargetPlayer.Character[partName].AssemblyLinearVelocity.X * HorizontalPrediction,
                math.clamp(TargetPlayer.Character[partName].AssemblyLinearVelocity.Y, -23, 50) * VerticalPrediction,
                TargetPlayer.Character[partName].AssemblyLinearVelocity.Z * HorizontalPrediction
            )

        return targetPart.Position + velocity
    end

    -- ============================================================
    -- ESP SYSTEM
    -- ============================================================

    local ESPFolder = Instance.new("Folder", Workspace)
    local GuiMain = Instance.new("Folder", Workspace) -- referenced as "guimain" in original

    local function createESP(player)
        if player == LocalPlayer then return end

        repeat task.wait() until player.Character
        local hrp = player.Character:WaitForChild("HumanoidRootPart")

        local billboard = create("BillboardGui", {
            Name = "PP",
            Adornee = hrp,
            Size = UDim2.new(0.1, 1, 0.1, 1),
            AlwaysOnTop = MainConfig.Dot,
            Parent = GuiMain,
        })

        local dot = create("Frame", {
            Size = MainConfig.Dot and UDim2.new(1, 1, 1, 1) or UDim2.new(0, 0, 0, 0),
            BackgroundColor3 = Theme.Blue,
            Transparency = MainConfig.Dot and 0 or 1,
            BackgroundTransparency = MainConfig.Dot and 0 or 1,
            Parent = billboard,
        })

        create("UICorner", {
            CornerRadius = UDim.new(1, 1),
            Parent = dot,
        })

        create("UIStroke", {
            Thickness = 1.4,
            Color = Theme.Black,
            Transparency = 0,
            Parent = dot,
        })

        billboard.Name = player.Name

        -- Update on respawn
        player.CharacterAdded:Connect(function(newChar)
            billboard.Adornee = newChar:WaitForChild("HumanoidRootPart")
        end)
    end

    -- Initialize ESP for all players
    for _, player in ipairs(Players:GetPlayers()) do
        createESP(player)
    end

    Players.PlayerAdded:Connect(createESP)

    -- ============================================================
    -- AIM PART RANDOMIZER
    -- ============================================================

    local AimParts = MainConfig.Partz
    local CurrentAimPart = AimParts[1]
    local LastAimPart = CurrentAimPart

    local function getRandomAimPart()
        if #AimParts == 1 then return AimParts[1] end
        local part
        repeat
            part = AimParts[math.random(1, #AimParts)]
        until part ~= LastAimPart
        return part
    end

    task.spawn(function()
        while true do
            CurrentAimPart = getRandomAimPart()
            LastAimPart = CurrentAimPart
            task.wait(0.001)
        end
    end)

    -- ============================================================
    -- PING-BASED PREDICTION
    -- ============================================================

    local HorizontalPrediction = MainConfig.Prediction.Horizontal
    local VerticalPrediction = MainConfig.Prediction.Vertical
    local AirDelay = MainConfig["Air Delay"][1] and MainConfig["Air Delay"].delay or 0

    RunService.Heartbeat:Connect(function()
        local pingStr = game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValueString()
        local ping = tonumber(string.split(pingStr, "(")[1])

        local pingBased = MainConfig["Ping Based"]

        if pingBased == "vertical" or pingBased == "all" then
            VerticalPrediction = ping / 1000
            AirDelay = ping / 100004
        end

        if pingBased == "horizontal" or pingBased == "all" then
            -- Ping-to-prediction mapping
            local pingMap = {
                [200] = 0.2198343243234332,
                [170] = 0.2165713,
                [160] = 0.16242,
                [150] = 0.158041,
                [140] = 0.155313,
                [130] = 0.152692,
                [120] = 0.153017,
                [110] = 0.15165,
                [100] = 0.1483987,
                [80]  = 0.145134,
                [70]  = 0.143633,
                [65]  = 0.1374236,
                [50]  = 0.13644,
                [30]  = 0.12452476,
            }

            for threshold, value in pairs(pingMap) do
                if ping < threshold then
                    HorizontalPrediction = value
                    break
                end
            end
        end
    end)

    -- ============================================================
    -- SILENT AIM (METATABLE HOOK)
    -- ============================================================

    local SilentAimPart = Instance.new("Part", Workspace)
    SilentAimPart.Anchored = true
    SilentAimPart.CanCollide = false
    SilentAimPart.Size = Vector3.zero
    SilentAimPart.Transparency = 1

    -- Visual marker for silent aim
    if MainConfig.Dot then
        createESP(SilentAimPart, SilentAimPart, Color3.fromRGB(255, 215, 18), 0.4, 0)
    end

    RunService.Heartbeat:Connect(function()
        updateResolver()

        if AimEnabled and TargetPlayer and TargetPlayer.Character
           and TargetPlayer.Character:FindFirstChild("HumanoidRootPart") then
            SilentAimPart.CFrame = CFrame.new(getPredictedPosition(AimConfig.Partz))
        else
            SilentAimPart.CFrame = CFrame.new(0, 9999, 0)
        end
    end)

    -- Hook __namecall for silent aim
    local mt = getrawmetatable(game)
    local oldNamecall = mt.__namecall
    setreadonly(mt, false)

    mt.__namecall = newcclosure(function(self, ...)
        local args = {...}
        local method = getnamecallmethod()

        if checkcaller() or not AimEnabled or (method ~= "FireServer" and method ~= "InvokeServer") then
            return oldNamecall(self, ...)
        end

        if TargetPlayer and TargetPlayer.Character then
            for i, arg in ipairs(args) do
                if typeof(arg) == "Vector3" then
                    args[i] = getPredictedPosition(CurrentAimPart)
                end
            end
        end

        return oldNamecall(self, unpack(args))
    end)

    -- ============================================================
    -- CAMERA LOCK (SMOOTH AIM)
    -- ============================================================

    RunService.Heartbeat:Connect(function()
        if AimConfig["Cam Enabled"] and AimEnabled and TargetPlayer then
            local targetPos = getPredictedPosition(AimConfig.Partz)
            local smoothness = tonumber(AimConfig["Smoothness Value"])
            local targetCFrame = CFrame.new(Camera.CFrame.Position, targetPos)

            Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, smoothness)

            -- Disable camera manipulation connections
            for _, conn in pairs(getconnections(Camera.Changed)) do
                conn:Disable()
            end
            for _, conn in pairs(getconnections(Camera:GetPropertyChangedSignal("CFrame"))) do
                conn:Disable()
            end
        end

        -- Auto-disable when target dies
        if MainConfig["Knock Unlock"] and TargetPlayer and TargetPlayer.Character
           and TargetPlayer.Character:FindFirstChild("Humanoid")
           and TargetPlayer.Character.Humanoid.Health <= 1 then
            AimEnabled = false
            TargetPlayer = nil
            NotificationSystem:Notify("Bozo Died :Skull:", 2)
        end
    end)

    -- ============================================================
    -- AIR ATTACK (AUTO HIT WHEN TARGET JUMPS)
    -- ============================================================

    RunService.Heartbeat:Connect(function()
        if not IsAirEnabled or not TargetPlayer then return end

        local character = TargetPlayer.Character
        if not character then return end

        local hrp = character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        local velocityY = isInAir(TargetPlayer) and ResolverData.ResolvedVelocity.Y or hrp.Velocity.Y

        if velocityY > 15 and not AirLocked then
            AirLocked = true

            task.delay(AirDelay, function()
                if not AirLocked then return end

                local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
                if not tool then
                    AirLocked = false
                    return
                end

                local toolName = tool.Name:lower()
                local isWhitelisted = false
                for _, name in ipairs(AirWeapons) do
                    if toolName == name:lower() then
                        isWhitelisted = true
                        break
                    end
                end

                if not isWhitelisted then
                    tool:Activate()
                end

                task.delay(MainConfig["Air Delay"].delay2, function()
                    AirLocked = false
                end)
            end)
        end
    end)

    -- ============================================================
    -- BULLET TELEPORT (MELEE RANGE EXTENDER)
    -- ============================================================

    local BulletTPConnection = nil

    local function getGripOffset(handCFrame, targetCFrame)
        return (handCFrame * CFrame.new(0, -1, 0, 1, 0, 0, 0, 0, 1, 0, -1, 0))
            :ToObjectSpace(targetCFrame):Inverse()
    end

    local function teleportTool(tool)
        if not TargetPlayer or not TargetPlayer.Character then return end

        local originalGrip = tool.Grip
        local hand = LocalPlayer.Character.RightHand

        tool.Parent = LocalPlayer.Backpack
        hand.Anchored = false
        tool.Grip = getGripOffset(hand.CFrame, TargetPlayer.Character.HumanoidRootPart.CFrame)
        hand.Anchored = true
        tool.Parent = LocalPlayer.Character

        RunService.RenderStepped:Wait()

        tool.Parent = LocalPlayer.Backpack
        hand.Anchored = false
        tool.Grip = originalGrip
        tool.Parent = LocalPlayer.Character
    end

    local function setupBulletTP(character)
        if BulletTPConnection then
            BulletTPConnection:Disconnect()
        end

        character.ChildAdded:Connect(function(child)
            if IsBulletTPEnabled and child:IsA("Tool") then
                BulletTPConnection = child.Activated:Connect(function()
                    teleportTool(child)
                end)
            end
        end)

        character.ChildRemoved:Connect(function(child)
            if child:IsA("Tool") and BulletTPConnection then
                BulletTPConnection:Disconnect()
                BulletTPConnection = nil
            end
        end)
    end

    LocalPlayer.CharacterAdded:Connect(setupBulletTP)
    if LocalPlayer.Character then
        setupBulletTP(LocalPlayer.Character)
    end

    -- ============================================================
    -- MACRO SYSTEM (SPEED/LEGIT/CFRAME)
    -- ============================================================

    local MacroType = GuiConfig.Macro.type
    local WalkSpeedHook = nil

    if MacroType == "Speed" then
        local mt2 = getrawmetatable(game)
        local oldNewindex = mt2.__newindex
        WalkSpeedHook = hookfunction(mt2.__newindex, newcclosure(function(self, key, value)
            if key == "WalkSpeed" and IsSpeedHacking then
                value = math.max(value, 150)
            end
            return WalkSpeedHook(self, key, value)
        end))
    end

    RunService.RenderStepped:Connect(function()
        if not IsMacroEnabled then
            IsSpeedHacking = false
            return
        end

        local character = LocalPlayer.Character
        if not character then return end

        local hrp = character:FindFirstChild("HumanoidRootPart")
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not hrp or not humanoid then return end

        if MacroType == "CFrame" then
            hrp.CFrame = hrp.CFrame + humanoid.MoveDirection * 2
        elseif MacroType == "Speed" then
            IsSpeedHacking = true
        elseif MacroType == "Legit" then
            local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
            local ray = Camera:ViewportPointToRay(center.X / Camera.ViewportSize.X, center.Y / Camera.ViewportSize.Y, 0)
            local direction = (ray.Origin - hrp.Position).Unit

            if humanoid:GetState() ~= Enum.HumanoidStateType.Physics
               and humanoid:GetState() ~= Enum.HumanoidStateType.Ragdoll then
                mousemoveabs(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
                hrp.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + Vector3.new(-direction.X, 0, -direction.Z))
            end
        end
    end)

    -- ============================================================
    -- SHOP / AUTO BUY SYSTEM
    -- ============================================================

    local function findShopItem(path)
        local current = Workspace
        for i, name in ipairs(path) do
            current = current:FindFirstChild(name)
            if not current then
                if name == "Pads" then
                    path[i] = "Shops"
                    current = Workspace:FindFirstChild("Shops")
                end
                if not current then
                    return nil
                end
            end
        end
        return current
    end

    local function buyItem(primaryPath, fallbackPath)
        local item = findShopItem(primaryPath)
        if not item and fallbackPath then
            item = findShopItem(fallbackPath)
        end
        if item then
            local detector = item:FindFirstChild("ClickDetector")
            if detector then
                fireclickdetector(detector)
            end
        end
    end

    local function sortInventory()
        local layout = {
            Enabled = true,
            ["Slot 1"] = "rev",
            ["Slot 2"] = "tactical sg",
            ["Slot 3"] = "db",
            ["Slot 4"] = "",
            ["Slot 5"] = "",
            ["Slot 6"] = "",
            ["Slot 7"] = "",
            ["Slot 8"] = "",
            ["Slot 9"] = "",
            ["Slot 0"] = "",
        }

        if not layout.Enabled then return end

        local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
        if not backpack then return end

        local temp = Instance.new("Folder", ServerStorage)

        for _, tool in ipairs(backpack:GetChildren()) do
            tool.Parent = temp
        end

        for i = 1, 10 do
            local slotName = "Slot " .. tostring(i % 10)
            local toolName = layout[slotName]
            if toolName and toolName ~= "" then
                for j, tool in ipairs(temp:GetChildren()) do
                    if tool.Name == toolName then
                        tool.Parent = backpack
                        table.remove(temp:GetChildren(), j)
                        break
                    end
                end
            end
        end

        for _, tool in ipairs(temp:GetChildren()) do
            tool.Parent = backpack
        end

        temp:Destroy()
    end

    local function buyAndSortItems()
        buyItem({"MAP", "Pads", "[Tactical Shotgun]"}, {"MAP", "Shops", "[Tactical Shotgun]"})
        buyItem({"MAP", "Pads", "[Pizza]"}, {"MAP", "Shops", "[Pizza]"})
        buyItem({"MAP", "Pads", "[Medium Armor]"}, {"MAP", "Shops", "[Medium Armor]"})

        LocalPlayer:WaitForChild("Backpack")
        task.wait(0.3)
        sortInventory()
    end

    -- ============================================================
    -- MAIN TOGGLE GUI
    -- ============================================================

    local MainGui = create("ScreenGui", {
        Name = "plehh",
        Parent = CoreGui,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })

    local MainFrame = create("Frame", {
        BackgroundColor3 = Theme.Black,
        BackgroundTransparency = 0.5,
        BorderSizePixel = 0,
        Position = UDim2.new(0.1338, 0, 0.201, 0),
        Size = UDim2.new(0, 202, 0, 70),
        Active = true,
        Draggable = true,
        Parent = MainGui,
    })

    local stroke = create("UIStroke", {
        Thickness = 2,
        Color = Theme.Black,
        Parent = MainFrame,
    })

    create("UICorner", {
        CornerRadius = UDim.new(0, 10),
        Parent = MainFrame,
    })

    -- Animated stroke
    local tweenInfo = TweenInfo.new(2, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, true)
    local darkColor = { Color = Color3.fromRGB(64, 64, 64) }
    local blackColor = { Color = Theme.Black }

    local currentTween = TweenService:Create(stroke, tweenInfo, darkColor)
    currentTween.Completed:Connect(function()
        currentTween = TweenService:Create(stroke, tweenInfo,
            stroke.Color == darkColor.Color and blackColor or darkColor)
        currentTween:Play()
    end)
    currentTween:Play()

    local ToggleButton = create("TextButton", {
        BackgroundColor3 = Theme.Black,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 170, 0, 44),
        Position = UDim2.new(0.5, -85, 0.5, -22),
        TextSize = 20,
        TextColor3 = Theme.FontColor,
        Font = Enum.Font.Code,
        Text = "",
        Parent = MainFrame,
    })

    create("UICorner", {
        CornerRadius = UDim.new(0, 10),
        Parent = ToggleButton,
    })

    create("ImageLabel", {
        Size = UDim2.new(0, 120, 0, 120),
        Position = UDim2.new(0.5, -60, 0.5, -60),
        BackgroundTransparency = 1,
        Image = "rbxassetid://92076780674896",
        ScaleType = Enum.ScaleType.Fit,
        Parent = MainFrame,
    })

    ToggleButton.MouseButton1Click:Connect(function()
        AimEnabled = not AimEnabled

        if AimEnabled then
            TargetPlayer = getClosestPlayerToCursor()
            if TargetPlayer then
                NotificationSystem:Notify("Abusing: " .. tostring(TargetPlayer.Character.Humanoid.DisplayName), 2)
            end
        else
            if TargetPlayer then
                NotificationSystem:Notify("Spared: " .. tostring(TargetPlayer.Character.Humanoid.DisplayName), 2)
            end
            TargetPlayer = nil
        end
    end)

    -- ============================================================
    -- OPTIONAL GUI BUTTONS
    -- ============================================================

    local GuiSize = GuiConfig["Big Gui"] == true and UDim2.new(0, 100, 0, 50)
        or GuiConfig["Big Gui"] == false and UDim2.new(0, 75, 0, 35)
        or UDim2.new(0, 75, 0, 35)

    -- Auto Air Button
    local AirButton = nil
    if GuiConfig["Auto Air"] then
        local btn, _ = createGuiButton("AutoAirGui", GuiSize, Theme.DarkTheme, "Air Off", function()
            if AirButton then
                IsAirEnabled = not IsAirEnabled
                AirButton.Text = IsAirEnabled and "Air - On" or "Air - Off"
            end
        end)
        AirButton = btn
    end

    -- Bullet TP Button
    local BulletTPButton = nil
    if GuiConfig["Bullet Tp"] then
        local btn, _ = createGuiButton("BulletTP", GuiSize, Theme.DarkTheme, "Bullet Tp Off", function()
            if BulletTPButton then
                IsBulletTPEnabled = not IsBulletTPEnabled
                BulletTPButton.Text = IsBulletTPEnabled and "Bullet Tp On" or "Bullet Tp Off"
            end
        end)
        BulletTPButton = btn
    end

    -- Macro Button
    local MacroButton = nil
    if GuiConfig.Macro[1] then
        local btn, _ = createGuiButton("MacroGui", GuiSize, Theme.DarkTheme, "Toggle Macro", function()
            if not MacroButton then return end

            local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")

            if IsMacroEnabled or not humanoid then
                IsMacroEnabled = false
                MacroButton.Text = "Macro Off"
            else
                -- Legit macro: play emote then equip katana
                if GuiConfig.Macro.type == "Legit"
                   and humanoid.MoveDirection.Magnitude == 0
                   and humanoid:PlayEmoteAndGetAnimTrackById(15610015346) then
                    task.wait(0.25)
                    local katana = LocalPlayer.Backpack:FindFirstChild("katana")
                    if katana then
                        humanoid:EquipTool(katana)
                    end
                end

                IsMacroEnabled = true
                MacroButton.Text = "Macro On"
            end
        end)
        MacroButton = btn
    end

    -- Trigger Bot Button
    local TriggerButton = nil
    local TriggerConnection = nil
    if GuiConfig["Trigger Bot"][1] then
        local btn, _ = createGuiButton("TriggerGui", GuiSize, Theme.DarkTheme, "Trigger - Off", function()
            if not TriggerButton then return end

            IsTriggerEnabled = not IsTriggerEnabled

            if IsTriggerEnabled then
                TriggerButton.Text = "Trigger - On"
                if not TriggerConnection then
                    TriggerConnection = RunService.Stepped:Connect(function()
                        local tool = TargetPlayer and LocalPlayer.Character
                            and LocalPlayer.Character:FindFirstChildWhichIsA("Tool")
                        if tool then
                            tool:Activate()
                            task.delay(GuiConfig["Trigger Bot"].delay)
                        end
                    end)
                end
            else
                TriggerButton.Text = "Trigger - Off"
                if TriggerConnection then
                    TriggerConnection:Disconnect()
                    TriggerConnection = nil
                end
            end
        end)
        TriggerButton = btn
    end

    -- Buy Items Button
    if GuiConfig["Buy Items"] then
        createGuiButton("BuyGui", GuiSize, Theme.DarkTheme, "Buy", function()
            buyAndSortItems()
        end)
    end

    -- Leave Button
    if GuiConfig.Leave then
        createGuiButton("LeaveGui", GuiSize, Theme.DarkTheme, "Leave", function()
            LocalPlayer:Kick("You have been permanently banned: Locking")
        end)
    end

    -- Reset Button
    if GuiConfig.Reset then
        createGuiButton("ResetGui", GuiSize, Theme.DarkTheme, "Reset Character", function()
            local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid.Health = 0
            end
        end)
    end

    -- ============================================================
    -- CHAT COMMANDS
    -- ============================================================

    LocalPlayer.Chatted:Connect(function(message)
        if string.lower(message) == "/e phyx.reset" then
            resetGuiPositions()
        end
    end)

    -- ============================================================
    -- ANTI-CHEAT BYPASS
    -- ============================================================

    for _, obj in pairs(getgc(true)) do
        if type(obj) == "table" then
            setreadonly(obj, false)
            local indexInstance = rawget(obj, "indexInstance")
            if type(indexInstance) == "table" and indexInstance[1] == "kick" then
                setreadonly(indexInstance, false)
                rawset(obj, "Table", {
                    "kick",
                    function() coroutine.yield() end,
                })
                NotificationSystem:Notify("AntiCheat bypassed - pluh", 8)
                break
            end
        end
    end

    -- ============================================================
    -- DEVELOPER NOTIFICATION
    -- ============================================================

    Players.PlayerAdded:Connect(function(player)
        if player.UserId == DEV_ID and player ~= LocalPlayer then
            NotificationSystem:Notify("someone joined...", 5)
            task.wait(3)
            playSound(SOUND_ID, 1)
        end
    end)

    -- ============================================================
    -- CUSTOM SOUNDS SETUP
    -- ============================================================

    local SoundUrls = {
        ["bawat_piyesa.ogg"] = "https://github.com/kian22kian/sounds/raw/refs/heads/main/bawat%20piiyesa.ogg",
        ["ksi"] = "https://github.com/kian22kian/sounds/raw/refs/heads/main/KSI%20-%20Thick%20Of%20It%20(feat.%20Trippie%20Redd)%20%5BOfficial%20Music%20Video%5D.mp3",
        ["apple_pay.wav"] = "https://github.com/LionTheGreatRealFrFr/hitsounds1/raw/refs/heads/master/applepay.wav",
    }

    local SOUND_FOLDER = "phyx_sounds"
    if not isfolder(SOUND_FOLDER) then
        makefolder(SOUND_FOLDER)
    end

    for filename, url in pairs(SoundUrls) do
        local path = SOUND_FOLDER .. "/" .. filename
        if not isfile(path) then
            writefile(path, game:HttpGet(url))
        end
        while not isfile(path) do
            task.wait(0.1)
        end
    end

    -- ============================================================
    -- INTRO SOUND
    -- ============================================================

    local introSounds = {
        "3450794184", "3997124966", "9060788686", "1548304764",
        "2027986581", "3601621507", "7036390821", "5153737200",
    }
    playSound(introSounds[math.random(1, #introSounds)], 1)

    print("3")
    print("4")
end)()

-- FPS cap loop
while true do
    setfpscap(1000)
    task.wait(0.001)
end
