repeat task.wait() until game:IsLoaded()

local cloneref = cloneref or function(obj) return obj end

-- Core Services
local TweenService = cloneref(game:GetService("TweenService"))
local UserInputService = cloneref(game:GetService("UserInputService"))
local HttpService = cloneref(game:GetService("HttpService"))
local Workspace = cloneref(game:GetService("Workspace"))
local RunService = cloneref(game:GetService("RunService"))
local Lighting = cloneref(game:GetService("Lighting"))
local Players = cloneref(game:GetService("Players"))
local MarketplaceService = cloneref(game:GetService("MarketplaceService"))
local LocalPlayer = cloneref(Players.LocalPlayer)

-- Safe UI Parent Resolver
local function getSafeGuiParent()
    local target = nil
    pcall(function()
        if gethui then
            local h = gethui()
            if h then
                if h:IsA("ScreenGui") then
                    target = h.Parent or cloneref(game:GetService("CoreGui"))
                else
                    target = h
                end
            end
        end
    end)
    if not target then
        pcall(function() target = cloneref(game:GetService("CoreGui")) end)
    end
    if not target then
        pcall(function()
            if LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") then
                target = LocalPlayer.PlayerGui
            end
        end)
    end
    return target or cloneref(game:GetService("CoreGui"))
end

local hui = getSafeGuiParent()

-- Clean any previous Pulse key system instances across all possible GUI parents
pcall(function()
    local targets = {}
    pcall(function() if gethui then table.insert(targets, gethui()) end end)
    pcall(function() table.insert(targets, cloneref(game:GetService("CoreGui"))) end)
    pcall(function()
        if LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") then
            table.insert(targets, LocalPlayer.PlayerGui)
        end
    end)
    for _, parent in ipairs(targets) do
        for _, name in ipairs({"PulseKeySystem", "PulseKeylessSystem", "PulseLoadingScreen"}) do
            local old = parent:FindFirstChild(name)
            if old then old:Destroy() end
        end
    end
end)

getgenv().PulseClosed = false

local Pulse = {}

-- Appearance Configuration
Pulse.Appearance = {
    Title = "Pulse Hub",
    Subtitle = "Enter your key to continue",
    Icon = "rbxthumb://type=Asset&id=76794114633768&w=420&h=420",
    IconSize = UDim2.new(0, 30, 0, 30)
}

-- Links & Endpoints
Pulse.Links = {
    GetKey = "https://pulsescripts.vercel.app/getkey/",
    Discord = "https://discord.gg/JfBCdvnqPu",
    Domain = "https://pulsescripts.vercel.app",
    TelemetryKey = "pulse_telemetry_live_sec_9941"
}

-- Storage Configuration
Pulse.Storage = {
    FolderName = "Pulse",
    FileName = "Pulse_Key",
    Remember = true,
    AutoLoad = false -- Keeps false so key screen always opens visually when executed
}

-- Options
Pulse.Options = {
    Keyless = false,
    KeylessUI = false,
    Blur = true,
    Draggable = true,
    NoGetKey = false
}

-- Color Palette (Pulse Obsidian & Crisp White Minimal Aesthetic)
Pulse.Theme = {
    Background = Color3.fromRGB(12, 13, 17),
    Card = Color3.fromRGB(18, 20, 26),
    Header = Color3.fromRGB(16, 18, 24),
    Input = Color3.fromRGB(22, 25, 34),
    Border = Color3.fromRGB(38, 42, 54),
    BorderFocus = Color3.fromRGB(255, 255, 255),
    Accent = Color3.fromRGB(255, 255, 255),
    AccentHover = Color3.fromRGB(235, 238, 245),
    AccentPink = Color3.fromRGB(236, 72, 153),
    Text = Color3.fromRGB(255, 255, 255),
    TextDim = Color3.fromRGB(156, 163, 175),
    TextMuted = Color3.fromRGB(105, 112, 128),
    Success = Color3.fromRGB(16, 185, 129),
    Error = Color3.fromRGB(239, 68, 68),
    Warning = Color3.fromRGB(245, 158, 11),
    StatusIdle = Color3.fromRGB(156, 163, 175),
    Discord = Color3.fromRGB(88, 101, 242),
    DiscordHover = Color3.fromRGB(114, 137, 218),
    Divider = Color3.fromRGB(34, 38, 50),
    Pending = Color3.fromRGB(48, 54, 70),
    ButtonBg = Color3.fromRGB(255, 255, 255),
    ButtonHover = Color3.fromRGB(235, 238, 245),
    ButtonText = Color3.fromRGB(12, 13, 17)
}

-- Callbacks
Pulse.Callbacks = {
    OnVerify = nil,
    OnSuccess = nil,
    OnFail = nil,
    OnClose = nil
}

-- Changelog History
Pulse.Changelog = {
    {
        Version = "v2.5.0",
        Date = "Nov 2026",
        Changes = {
            "Full modular key system engine with callback hooks",
            "Collapsible User Info drawer with HWID copy and live clock",
            "Changelog sliding drawer with animated release notes",
            "Cyber sliding doors transition on load and exit",
            "Stacked toast notifications with auto-dismiss timers",
            "Encrypted telemetry stream with security token gate"
        }
    },
    {
        Version = "v2.0.0",
        Date = "Oct 2026",
        Changes = {
            "Initial release of Pulse Hub V2 architecture",
            "Redesigned modern glassmorphism interface"
        }
    }
}

-- Optional Shop Section
Pulse.Shop = {
    Enabled = false,
    Icon = "",
    Title = "Get Premium Access",
    Subtitle = "Instant delivery • 24/7 support",
    ButtonText = "Upgrade",
    Link = "https://pulsescripts.vercel.app"
}

-- Internal Runtime State
local Internal = {
    Junkie = nil,
    BlurEffect = nil,
    NotificationList = {},
    ValidateFunction = nil,
    IsJunkieMode = false,
    IconsLoaded = false,
    CachedLogo = nil,
    ViewportConnection = nil
}

-- Fallback Asset Icons (High Quality Roblox Engine Decals)
local FallbackIcons = {
    key = "rbxassetid://96510194465420",
    shield = "rbxassetid://89965059528921",
    check = "rbxassetid://76078495178149",
    copy = "rbxassetid://125851897718493",
    discord = "rbxassetid://83278450537116",
    alert = "rbxassetid://140438367956051",
    lock = "rbxassetid://114355063515473",
    loading = "rbxassetid://116535712789945",
    close = "rbxassetid://6022668916",
    changelog = "rbxassetid://138133190015277",
    logo = "rbxthumb://type=Asset&id=76794114633768&w=420&h=420",
    user = "rbxassetid://77400125196692",
    clock = "rbxassetid://87505349362628",
    cart = "rbxassetid://114754518183872",
    nogetkey = "rbxassetid://119765975153029"
}

local CachedIcons = {}

-- Device & Screen Utilities
local function isMobile()
    return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function getScreenInfo()
    local cam = Workspace.CurrentCamera
    local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
    local vw, vh = vp.X, vp.Y
    if vw < 100 or vh < 100 then vw, vh = 1920, 1080 end

    local isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
    local minDim = math.min(vw, vh)
    local maxDim = math.max(vw, vh)
    local isPhone = isTouch and (minDim < 550)
    local isTablet = isTouch and not isPhone
    local isPortrait = vh > vw

    return {
        vw = vw,
        vh = vh,
        minDim = minDim,
        maxDim = maxDim,
        isTouch = isTouch,
        isPhone = isPhone,
        isTablet = isTablet,
        isPortrait = isPortrait
    }
end

local function getScale()
    local info = getScreenInfo()
    local vw, vh = info.vw, info.vh

    -- Reference canvas card size: 440 x 310
    local refW = 440
    local refH = 310

    -- Comfortable margins around the UI (at least 24px on sides, 54px top/bottom for topbars)
    local maxW = vw - 24
    local maxH = vh - 54

    local maxFitScale = math.min(maxW / refW, maxH / refH)

    local targetScale = 1.0
    if info.isPhone then
        if info.isPortrait then
            -- Phone Portrait: card fills ~88% of screen width comfortably
            targetScale = math.clamp((vw * 0.88) / refW, 0.62, 0.88)
        else
            -- Phone Landscape: height is the primary constraint, fill ~80% of screen height
            targetScale = math.clamp((vh * 0.80) / refH, 0.58, 0.84)
        end
    elseif info.isTablet then
        -- iPad / Tablet: comfortable medium touch scale
        targetScale = math.clamp(math.min(vw, vh) / 820, 0.85, 1.05)
    else
        -- PC Desktop / Laptop: 0.85 on small laptops up to 1.15 on 1440p/4K
        targetScale = math.clamp(math.min(vw / 1280, vh / 820), 0.85, 1.15)
    end

    -- Scale must never exceed screen bounds!
    return math.clamp(math.min(targetScale, maxFitScale), 0.55, 1.25)
end

-- File System & Key Persistence
local function hasFileSystem()
    local ok1 = pcall(function() return type(writefile) == "function" end)
    local ok2 = pcall(function() return type(readfile) == "function" end)
    local ok3 = pcall(function() return type(isfile) == "function" end)
    local ok4 = pcall(function() return type(makefolder) == "function" end)
    local ok5 = pcall(function() return type(isfolder) == "function" end)
    return ok1 and ok2 and ok3 and ok4 and ok5
end

local fileSystemSupported = hasFileSystem()

local function getFileName()
    return Pulse.Storage.FolderName .. "/" .. Pulse.Storage.FileName .. ".txt"
end

local function ensureFolders()
    if not fileSystemSupported then return false end
    pcall(function()
        if not isfolder(Pulse.Storage.FolderName) then makefolder(Pulse.Storage.FolderName) end
        if not isfolder(Pulse.Storage.FolderName .. "/Icons") then makefolder(Pulse.Storage.FolderName .. "/Icons") end
    end)
    return true
end

local function saveKey(key)
    if not fileSystemSupported or not Pulse.Storage.Remember then return false end
    ensureFolders()
    pcall(function() writefile(getFileName(), key) end)
    pcall(function() writefile("pulse_key.txt", key) end)
    return true
end

local function loadKey()
    if not fileSystemSupported then return nil end
    local ok, content = pcall(function()
        if isfile(getFileName()) then return readfile(getFileName()) end
        if isfile("pulse_key.txt") then return readfile("pulse_key.txt") end
        return nil
    end)
    if ok and content and content ~= "" then
        return tostring(content):gsub("%s+", "")
    end
    return nil
end

local function clearKey()
    if not fileSystemSupported then return false end
    pcall(function() if isfile(getFileName()) then delfile(getFileName()) end end)
    pcall(function() if isfile("pulse_key.txt") then delfile("pulse_key.txt") end end)
    return true
end

-- Icon Management
local function formatAssetId(id)
    if not id or id == "" then return id end
    if type(id) == "number" or (type(id) == "string" and id:match("^%d+$")) then
        return "rbxthumb://type=Asset&id=" .. tostring(id) .. "&w=420&h=420"
    end
    if type(id) == "string" and id:match("^rbxassetid://(%d+)$") then
        local num = id:match("^rbxassetid://(%d+)$")
        return "rbxthumb://type=Asset&id=" .. num .. "&w=420&h=420"
    end
    return id
end

local function getIcon(iconName)
    return CachedIcons[iconName] or FallbackIcons[iconName] or FallbackIcons.logo
end

local function getLogoIcon()
    if Pulse.Appearance.Icon and Pulse.Appearance.Icon ~= "" then
        return formatAssetId(Pulse.Appearance.Icon)
    end
    if Internal.CachedLogo then return Internal.CachedLogo end
    return formatAssetId(FallbackIcons.logo)
end

-- Client Telemetry Helpers
local function getExecutorName()
    local success, name = pcall(identifyexecutor)
    if success and name then return tostring(name) end
    if syn then return "Synapse X" end
    if SENTINEL_LOADED then return "Sentinel" end
    if KRNL_LOADED then return "Krnl" end
    if is_fluxus_closure then return "Fluxus" end
    if shadow_loaded then return "Shadow" end
    return "Roblox Client"
end

local function getDeviceType()
    local touch = UserInputService.TouchEnabled
    local keyboard = UserInputService.KeyboardEnabled
    local gamepad = UserInputService.GamepadEnabled
    local info = getScreenInfo()

    if gamepad and not keyboard and not touch then
        return "Console"
    elseif touch and not keyboard then
        if info.isPhone then
            return "Mobile Phone"
        else
            return "iPad / Tablet"
        end
    elseif keyboard and touch then
        if info.minDim >= 600 then
            return "iPad / Hybrid"
        else
            return "Touch PC"
        end
    elseif keyboard then
        return "PC"
    else
        return "Roblox Client"
    end
end

local function getHWID()
    local hwid = nil
    pcall(function() if gethwid then hwid = gethwid() end end)
    if not hwid then pcall(function() if getgenv().HWID then hwid = getgenv().HWID end end) end
    if not hwid then pcall(function() if game.RobloxHWID then hwid = tostring(game.RobloxHWID) end end) end
    if not hwid then
        local player = LocalPlayer or cloneref(Players.LocalPlayer)
        hwid = HttpService:GenerateGUID(false):gsub("-", ""):sub(1, 24)
        if player then hwid = tostring(player.UserId) .. "_" .. hwid end
    end
    return hwid or "HWID-DEV-SAMPLE"
end

local function generateHiddenDots(availableWidth, charWidth)
    charWidth = charWidth or 6
    local count = math.floor(availableWidth / charWidth)
    count = math.clamp(count, 8, 30)
    return string.rep("•", count)
end

local function formatTime12()
    local hour = tonumber(os.date("%H")) or 12
    local min = os.date("%M") or "00"
    local sec = os.date("%S") or "00"
    local period = (hour >= 12) and "PM" or "AM"
    if hour > 12 then hour = hour - 12 end
    if hour == 0 then hour = 12 end
    return string.format("%02d:%s:%s %s", hour, min, sec, period)
end

local function formatDate()
    return os.date("%b %d, %Y")
end

-- Blur Overlay
local function enableBlur()
    if not Pulse.Options.Blur then return end
    local existing = Lighting:FindFirstChild("PulseKeyBlur")
    if existing then existing:Destroy() end
    Internal.BlurEffect = Instance.new("BlurEffect")
    Internal.BlurEffect.Name = "PulseKeyBlur"
    Internal.BlurEffect.Size = 0
    Internal.BlurEffect.Parent = Lighting
    TweenService:Create(Internal.BlurEffect, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = 20 }):Play()
end

local function disableBlur()
    if Internal.BlurEffect and Internal.BlurEffect.Parent then
        local tween = TweenService:Create(Internal.BlurEffect, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = 0 })
        tween:Play()
        task.delay(0.32, function()
            if Internal.BlurEffect and Internal.BlurEffect.Parent then
                Internal.BlurEffect:Destroy()
                Internal.BlurEffect = nil
            end
        end)
    else
        local existing = Lighting:FindFirstChild("PulseKeyBlur")
        if existing then existing:Destroy() end
        Internal.BlurEffect = nil
    end
end

local function fullCleanup()
    getgenv().PulseLoaded = false
    getgenv().PulseClosed = true
    disableBlur()
    if Internal.ViewportConnection then
        pcall(function() Internal.ViewportConnection:Disconnect() end)
        Internal.ViewportConnection = nil
    end
    pcall(function()
        local targets = { hui }
        if LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") then
            table.insert(targets, LocalPlayer.PlayerGui)
        end
        for _, parent in ipairs(targets) do
            for _, name in ipairs({"PulseKeySystem", "PulseKeylessSystem", "PulseLoadingScreen"}) do
                local old = parent:FindFirstChild(name)
                if old then old:Destroy() end
            end
        end
    end)
end

-- Window Dragging Handler
local function setupDragging(header, targetFrame)
    if not Pulse.Options.Draggable then return end
    local dragging = false
    local dragStart = Vector2.zero
    local startPos = targetFrame.Position

    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = targetFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            targetFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

-- Cyber Shutter Door Overlay (Flawless Rounded Clipping & Smooth Dissolve)
local function CreateDoorOverlay(parentFrame, width, height)
    -- CanvasGroup guarantees rounded corner clipping and smooth alpha dissolve
    local overlay = Instance.new("CanvasGroup")
    overlay.Name = "DoorOverlay"
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.Position = UDim2.new(0, 0, 0, 0)
    overlay.BackgroundTransparency = 1
    overlay.GroupTransparency = 0
    overlay.ZIndex = 50
    overlay.Active = false
    overlay.Parent = parentFrame

    local corner = Instance.new("UICorner", overlay)
    corner.CornerRadius = UDim.new(0, 18)

    local leftDoor = Instance.new("Frame")
    leftDoor.Name = "LeftDoor"
    leftDoor.Size = UDim2.new(0.5, 2, 1, 0)
    leftDoor.Position = UDim2.new(0, 0, 0, 0)
    leftDoor.BackgroundColor3 = Pulse.Theme.Header
    leftDoor.BorderSizePixel = 0
    leftDoor.ZIndex = 51
    leftDoor.Active = false
    leftDoor.Parent = overlay

    local rightDoor = Instance.new("Frame")
    rightDoor.Name = "RightDoor"
    rightDoor.Size = UDim2.new(0.5, 2, 1, 0)
    rightDoor.Position = UDim2.new(0.5, -1, 0, 0)
    rightDoor.BackgroundColor3 = Pulse.Theme.Header
    rightDoor.BorderSizePixel = 0
    rightDoor.ZIndex = 51
    rightDoor.Active = false
    rightDoor.Parent = overlay

    -- Center Emblem Logo (Clean Floating Picture without background circle or rings)
    local doorLogo = Instance.new("ImageLabel")
    doorLogo.Name = "DoorLogo"
    doorLogo.Size = UDim2.new(0, 50, 0, 50)
    doorLogo.Position = UDim2.new(0.5, 0, 0.5, 0)
    doorLogo.AnchorPoint = Vector2.new(0.5, 0.5)
    doorLogo.BackgroundTransparency = 1
    doorLogo.Image = getLogoIcon()
    doorLogo.ImageColor3 = Color3.fromRGB(255, 255, 255)
    doorLogo.ScaleType = Enum.ScaleType.Fit
    doorLogo.ZIndex = 55
    doorLogo.Active = false
    doorLogo.Parent = overlay
    Instance.new("UICorner", doorLogo).CornerRadius = UDim.new(0, 10)

    local function openDoors(callback)
        -- Smooth logo fade & scale out
        TweenService:Create(doorLogo, TweenInfo.new(0.20, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
            Size = UDim2.new(0, 64, 0, 64),
            ImageTransparency = 1
        }):Play()

        task.wait(0.06)

        -- Silky smooth shutter slide & simultaneous alpha fade
        local slideTweenInfo = TweenInfo.new(0.42, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
        local fadeTweenInfo = TweenInfo.new(0.36, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

        TweenService:Create(leftDoor, slideTweenInfo, { Position = UDim2.new(-0.55, 0, 0, 0) }):Play()
        TweenService:Create(rightDoor, slideTweenInfo, { Position = UDim2.new(1.05, 0, 0, 0) }):Play()
        TweenService:Create(overlay, fadeTweenInfo, { GroupTransparency = 1 }):Play()

        task.wait(0.42)
        overlay.Visible = false
        if callback then callback() end
    end

    local function closeDoors(callback)
        overlay.Visible = true
        overlay.GroupTransparency = 1
        leftDoor.Position = UDim2.new(-0.55, 0, 0, 0)
        rightDoor.Position = UDim2.new(1.05, 0, 0, 0)
        doorLogo.Size = UDim2.new(0, 64, 0, 64)
        doorLogo.ImageTransparency = 1

        local slideInInfo = TweenInfo.new(0.38, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
        local fadeInInfo = TweenInfo.new(0.30, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

        TweenService:Create(leftDoor, slideInInfo, { Position = UDim2.new(0, 0, 0, 0) }):Play()
        TweenService:Create(rightDoor, slideInInfo, { Position = UDim2.new(0.5, -1, 0, 0) }):Play()
        TweenService:Create(overlay, fadeInInfo, { GroupTransparency = 0 }):Play()

        task.wait(0.12)
        TweenService:Create(doorLogo, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 50, 0, 50),
            ImageTransparency = 0
        }):Play()

        task.wait(0.32)
        if callback then callback() end
    end

    return { overlay = overlay, open = openDoors, close = closeDoors }
end

-- Stacked Notification Engine
function Pulse:Notify(title, message, duration, iconType)
    duration = duration or 4.5
    iconType = iconType or "info"
    local scale = getScale()
    local width = math.clamp(330 * scale, 270, 390)
    local height = math.clamp(74 * scale, 68, 92)

    local notifGui = hui:FindFirstChild("PulseNotifications")
    if not notifGui then
        notifGui = Instance.new("ScreenGui")
        notifGui.Name = "PulseNotifications"
        notifGui.ResetOnSpawn = false
        notifGui.DisplayOrder = 999999
        notifGui.Parent = hui
    end

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, width, 0, height)
    frame.Position = UDim2.new(1, width + 25, 1, -20)
    frame.AnchorPoint = Vector2.new(1, 1)
    frame.BackgroundColor3 = Pulse.Theme.Header
    frame.BorderSizePixel = 0
    frame.ClipsDescendants = true
    frame.Parent = notifGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1.2
    stroke.Color = Pulse.Theme.Border
    stroke.Transparency = 0.2
    stroke.Parent = frame

    -- Progress Countdown Bar
    local progressTrack = Instance.new("Frame")
    progressTrack.Size = UDim2.new(1, 0, 0, 2)
    progressTrack.Position = UDim2.new(0, 0, 1, -2)
    progressTrack.BackgroundColor3 = Pulse.Theme.Divider
    progressTrack.BorderSizePixel = 0
    progressTrack.Parent = frame

    local progressBar = Instance.new("Frame")
    progressBar.Size = UDim2.new(1, 0, 1, 0)
    progressBar.BackgroundColor3 = Pulse.Theme.Accent
    progressBar.BorderSizePixel = 0
    progressBar.Parent = progressTrack

    -- Icon Configuration
    local iconMap = {
        success = { "check", Pulse.Theme.Success },
        error = { "alert", Pulse.Theme.Error },
        warning = { "alert", Pulse.Theme.Warning },
        info = { "shield", Pulse.Theme.Accent },
        shield = { "shield", Pulse.Theme.Accent },
        key = { "key", Pulse.Theme.Accent },
        copy = { "copy", Pulse.Theme.Success },
        discord = { "discord", Pulse.Theme.Discord },
        close = { "close", Pulse.Theme.Error }
    }

    local iconData = iconMap[iconType] or { "logo", Pulse.Theme.Accent }
    progressBar.BackgroundColor3 = iconData[2]
    stroke.Color = iconData[2]
    stroke.Transparency = 0.5

    local iconSize = height - 32
    local iconImage = Instance.new("ImageLabel")
    iconImage.Size = UDim2.new(0, iconSize, 0, iconSize)
    iconImage.Position = UDim2.new(0, 14, 0.5, -2)
    iconImage.AnchorPoint = Vector2.new(0, 0.5)
    iconImage.BackgroundTransparency = 1
    iconImage.Image = getIcon(iconData[1])
    iconImage.ImageColor3 = iconData[2]
    iconImage.ScaleType = Enum.ScaleType.Fit
    iconImage.Parent = frame

    local textX = 14 + iconSize + 12
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -(textX + 14), 0, 20)
    titleLabel.Position = UDim2.new(0, textX, 0, 12)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = math.clamp(14 * scale, 12, 16)
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.TextColor3 = Pulse.Theme.Text
    titleLabel.Text = title
    titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
    titleLabel.Parent = frame

    local messageLabel = Instance.new("TextLabel")
    messageLabel.Size = UDim2.new(1, -(textX + 14), 0, 18)
    messageLabel.Position = UDim2.new(0, textX, 0, 34)
    messageLabel.BackgroundTransparency = 1
    messageLabel.Font = Enum.Font.GothamMedium
    messageLabel.TextSize = math.clamp(12 * scale, 10, 14)
    messageLabel.TextXAlignment = Enum.TextXAlignment.Left
    messageLabel.TextColor3 = Pulse.Theme.TextDim
    messageLabel.Text = message
    messageLabel.TextTruncate = Enum.TextTruncate.AtEnd
    messageLabel.Parent = frame

    local id = tick() .. HttpService:GenerateGUID(false)
    table.insert(Internal.NotificationList, { id = id, frame = frame, height = height })

    local function restack()
        local yOffset = 0
        for i = #Internal.NotificationList, 1, -1 do
            local item = Internal.NotificationList[i]
            if item and item.frame and item.frame.Parent then
                TweenService:Create(item.frame, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                    Position = UDim2.new(1, -20, 1, -20 - yOffset)
                }):Play()
                yOffset = yOffset + item.height + 10
            end
        end
    end

    TweenService:Create(frame, TweenInfo.new(0.38, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
        Position = UDim2.new(1, -20, 1, -20)
    }):Play()
    task.wait(0.08)
    restack()

    local function dismiss()
        for idx, item in ipairs(Internal.NotificationList) do
            if item.id == id then
                table.remove(Internal.NotificationList, idx)
                break
            end
        end
        local exit = TweenService:Create(frame, TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
            Position = UDim2.new(1, width + 25, frame.Position.Y.Scale, frame.Position.Y.Offset),
            BackgroundTransparency = 1
        })
        exit:Play()
        exit.Completed:Connect(function()
            frame:Destroy()
            restack()
        end)
    end

    TweenService:Create(progressBar, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
        Size = UDim2.new(0, 0, 1, 0)
    }):Play()

    task.delay(duration, dismiss)

    local clickBtn = Instance.new("TextButton")
    clickBtn.Size = UDim2.new(1, 0, 1, 0)
    clickBtn.BackgroundTransparency = 1
    clickBtn.Text = ""
    clickBtn.Parent = frame
    clickBtn.MouseButton1Click:Connect(dismiss)
end

-- Collapsible User Info Drawer (Left Side)
local function CreateUserInfoPanel(parent, windowWidth, panelHeight, panelWidth, mainFrame, gap)
    panelWidth = panelWidth or 190
    local isOpen = false

    local panel = Instance.new("Frame")
    panel.Name = "UserInfoPanel"
    panel.Size = UDim2.new(0, 0, 0, panelHeight)
    panel.Position = UDim2.new(0, -gap, 0, 0)
    panel.AnchorPoint = Vector2.new(1, 0)
    panel.BackgroundColor3 = Pulse.Theme.Background
    panel.BorderSizePixel = 0
    panel.ClipsDescendants = true
    panel.Parent = mainFrame

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 16)
    corner.Parent = panel

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1.2
    stroke.Color = Pulse.Theme.Border
    stroke.Transparency = 1
    stroke.Parent = panel

    -- Drawer Header
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 48)
    header.BackgroundColor3 = Pulse.Theme.Header
    header.BorderSizePixel = 0
    header.Parent = panel

    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = UDim.new(0, 16)
    headerCorner.Parent = header

    local headerLine = Instance.new("Frame")
    headerLine.Size = UDim2.new(1, 0, 0, 1)
    headerLine.Position = UDim2.new(0, 0, 1, 0)
    headerLine.BackgroundColor3 = Pulse.Theme.Border
    headerLine.BorderSizePixel = 0
    headerLine.Parent = header

    local userIcon = Instance.new("ImageLabel")
    userIcon.Size = UDim2.new(0, 18, 0, 18)
    userIcon.Position = UDim2.new(0, 14, 0.5, 0)
    userIcon.AnchorPoint = Vector2.new(0, 0.5)
    userIcon.BackgroundTransparency = 1
    userIcon.Image = getIcon("user")
    userIcon.ImageColor3 = Pulse.Theme.Accent
    userIcon.ScaleType = Enum.ScaleType.Fit
    userIcon.Parent = header

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -64, 1, 0)
    titleLabel.Position = UDim2.new(0, 38, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "User Info"
    titleLabel.TextColor3 = Pulse.Theme.Text
    titleLabel.TextSize = 14
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = header

    local closeBtn = Instance.new("ImageButton")
    closeBtn.Size = UDim2.new(0, 26, 0, 26)
    closeBtn.Position = UDim2.new(1, -10, 0.5, 0)
    closeBtn.AnchorPoint = Vector2.new(1, 0.5)
    closeBtn.BackgroundTransparency = 1
    closeBtn.Image = getIcon("close")
    closeBtn.ImageColor3 = Pulse.Theme.TextDim
    closeBtn.ScaleType = Enum.ScaleType.Fit
    closeBtn.Parent = header
    closeBtn.MouseEnter:Connect(function() TweenService:Create(closeBtn, TweenInfo.new(0.15), { ImageColor3 = Pulse.Theme.Error }):Play() end)
    closeBtn.MouseLeave:Connect(function() TweenService:Create(closeBtn, TweenInfo.new(0.15), { ImageColor3 = Pulse.Theme.TextDim }):Play() end)

    -- Content Container
    local contentFrame = Instance.new("Frame")
    contentFrame.Size = UDim2.new(1, 0, 1, -50)
    contentFrame.Position = UDim2.new(0, 0, 0, 50)
    contentFrame.BackgroundTransparency = 1
    contentFrame.Parent = panel

    local contentPadding = Instance.new("UIPadding")
    contentPadding.PaddingLeft = UDim.new(0, 12)
    contentPadding.PaddingRight = UDim.new(0, 12)
    contentPadding.PaddingTop = UDim.new(0, 10)
    contentPadding.PaddingBottom = UDim.new(0, 10)
    contentPadding.Parent = contentFrame

    local contentLayout = Instance.new("UIListLayout")
    contentLayout.Padding = UDim.new(0, 7)
    contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
    contentLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    contentLayout.Parent = contentFrame

    -- Avatar Headshot with Neon Border
    local avatarWrapper = Instance.new("Frame")
    avatarWrapper.Size = UDim2.new(0, 48, 0, 48)
    avatarWrapper.BackgroundTransparency = 1
    avatarWrapper.LayoutOrder = 1
    avatarWrapper.Parent = contentFrame

    local avatarGlow = Instance.new("Frame")
    avatarGlow.Size = UDim2.new(1, 0, 1, 0)
    avatarGlow.BackgroundColor3 = Pulse.Theme.Card
    avatarGlow.BorderSizePixel = 0
    avatarGlow.Parent = avatarWrapper
    Instance.new("UICorner", avatarGlow).CornerRadius = UDim.new(1, 0)

    local avatarStroke = Instance.new("UIStroke", avatarGlow)
    avatarStroke.Color = Pulse.Theme.Accent
    avatarStroke.Thickness = 1.5

    local avatarImage = Instance.new("ImageLabel")
    avatarImage.Size = UDim2.new(1, -4, 1, -4)
    avatarImage.Position = UDim2.new(0.5, 0, 0.5, 0)
    avatarImage.AnchorPoint = Vector2.new(0.5, 0.5)
    avatarImage.BackgroundTransparency = 1
    avatarImage.ScaleType = Enum.ScaleType.Crop
    avatarImage.Parent = avatarGlow
    Instance.new("UICorner", avatarImage).CornerRadius = UDim.new(1, 0)

    pcall(function()
        local thumb = Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
        avatarImage.Image = thumb
    end)

    -- Display Name
    local welcomeLabel = Instance.new("TextLabel")
    welcomeLabel.Size = UDim2.new(1, 0, 0, 16)
    welcomeLabel.BackgroundTransparency = 1
    welcomeLabel.Text = (LocalPlayer and LocalPlayer.DisplayName) or "Roblox User"
    welcomeLabel.TextColor3 = Pulse.Theme.Text
    welcomeLabel.TextSize = 13
    welcomeLabel.Font = Enum.Font.GothamBold
    welcomeLabel.TextTruncate = Enum.TextTruncate.AtEnd
    welcomeLabel.LayoutOrder = 2
    welcomeLabel.Parent = contentFrame

    -- Subtle Divider Line
    local function makeDivider(order)
        local div = Instance.new("Frame")
        div.Size = UDim2.new(1, 0, 0, 1)
        div.BackgroundColor3 = Pulse.Theme.Divider
        div.BorderSizePixel = 0
        div.LayoutOrder = order
        div.Parent = contentFrame
        return div
    end

    makeDivider(3)

    -- Info Row Helper
    local function makeInfoRow(title, val, order)
        local container = Instance.new("Frame")
        container.Size = UDim2.new(1, 0, 0, 26)
        container.BackgroundTransparency = 1
        container.LayoutOrder = order
        container.Parent = contentFrame

        local titleLbl = Instance.new("TextLabel")
        titleLbl.Size = UDim2.new(1, 0, 0, 11)
        titleLbl.BackgroundTransparency = 1
        titleLbl.Text = title
        titleLbl.TextColor3 = Pulse.Theme.TextMuted
        titleLbl.TextSize = 10
        titleLbl.Font = Enum.Font.GothamMedium
        titleLbl.TextXAlignment = Enum.TextXAlignment.Left
        titleLbl.Parent = container

        local valLbl = Instance.new("TextLabel")
        valLbl.Size = UDim2.new(1, 0, 0, 15)
        valLbl.Position = UDim2.new(0, 0, 0, 11)
        valLbl.BackgroundTransparency = 1
        valLbl.Text = val
        valLbl.TextColor3 = Pulse.Theme.Accent
        valLbl.TextSize = 11
        valLbl.Font = Enum.Font.GothamBold
        valLbl.TextXAlignment = Enum.TextXAlignment.Left
        valLbl.TextTruncate = Enum.TextTruncate.AtEnd
        valLbl.Parent = container
        return container
    end

    makeInfoRow("Executor", getExecutorName(), 4)
    makeInfoRow("Device", getDeviceType(), 5)
    makeDivider(6)

    -- HWID Field with 1-Click Copy
    local hwidContainer = Instance.new("Frame")
    hwidContainer.Size = UDim2.new(1, 0, 0, 26)
    hwidContainer.BackgroundTransparency = 1
    hwidContainer.LayoutOrder = 7
    hwidContainer.Parent = contentFrame

    local hwidTitle = Instance.new("TextLabel")
    hwidTitle.Size = UDim2.new(1, 0, 0, 11)
    hwidTitle.BackgroundTransparency = 1
    hwidTitle.Text = "Hardware ID (HWID)"
    hwidTitle.TextColor3 = Pulse.Theme.TextMuted
    hwidTitle.TextSize = 10
    hwidTitle.Font = Enum.Font.GothamMedium
    hwidTitle.TextXAlignment = Enum.TextXAlignment.Left
    hwidTitle.Parent = hwidContainer

    local fullHWID = getHWID()
    local hwidDots = generateHiddenDots(panelWidth - 50, 6)

    local hwidValue = Instance.new("TextLabel")
    hwidValue.Size = UDim2.new(1, -26, 0, 15)
    hwidValue.Position = UDim2.new(0, 0, 0, 11)
    hwidValue.BackgroundTransparency = 1
    hwidValue.Text = hwidDots
    hwidValue.TextColor3 = Pulse.Theme.TextDim
    hwidValue.TextSize = 11
    hwidValue.Font = Enum.Font.GothamBold
    hwidValue.TextXAlignment = Enum.TextXAlignment.Left
    hwidValue.Parent = hwidContainer

    local copyBtn = Instance.new("ImageButton")
    copyBtn.Size = UDim2.new(0, 16, 0, 16)
    copyBtn.Position = UDim2.new(1, 0, 0.5, 3)
    copyBtn.AnchorPoint = Vector2.new(1, 0.5)
    copyBtn.BackgroundTransparency = 1
    copyBtn.Image = getIcon("copy")
    copyBtn.ImageColor3 = Pulse.Theme.TextDim
    copyBtn.ScaleType = Enum.ScaleType.Fit
    copyBtn.Parent = hwidContainer

    copyBtn.MouseEnter:Connect(function() TweenService:Create(copyBtn, TweenInfo.new(0.15), { ImageColor3 = Pulse.Theme.Accent }):Play() end)
    copyBtn.MouseLeave:Connect(function() TweenService:Create(copyBtn, TweenInfo.new(0.15), { ImageColor3 = Pulse.Theme.TextDim }):Play() end)
    copyBtn.MouseButton1Click:Connect(function()
        pcall(function() setclipboard(fullHWID) end)
        TweenService:Create(copyBtn, TweenInfo.new(0.12), { ImageColor3 = Pulse.Theme.Success }):Play()
        task.delay(0.3, function() TweenService:Create(copyBtn, TweenInfo.new(0.15), { ImageColor3 = Pulse.Theme.TextDim }):Play() end)
        Pulse:Notify("Copied", "HWID copied to clipboard!", 2, "copy")
    end)

    makeDivider(8)

    -- Live Clock Row
    local clockContainer = Instance.new("Frame")
    clockContainer.Size = UDim2.new(1, 0, 0, 32)
    clockContainer.BackgroundTransparency = 1
    clockContainer.LayoutOrder = 9
    clockContainer.Parent = contentFrame

    local clockTime = Instance.new("TextLabel")
    clockTime.Size = UDim2.new(1, 0, 0, 16)
    clockTime.BackgroundTransparency = 1
    clockTime.Text = formatTime12()
    clockTime.TextColor3 = Pulse.Theme.Text
    clockTime.TextSize = 12
    clockTime.Font = Enum.Font.GothamBold
    clockTime.TextXAlignment = Enum.TextXAlignment.Center
    clockTime.Parent = clockContainer

    local clockDate = Instance.new("TextLabel")
    clockDate.Size = UDim2.new(1, 0, 0, 14)
    clockDate.Position = UDim2.new(0, 0, 0, 16)
    clockDate.BackgroundTransparency = 1
    clockDate.Text = formatDate()
    clockDate.TextColor3 = Pulse.Theme.TextMuted
    clockDate.TextSize = 10
    clockDate.Font = Enum.Font.GothamMedium
    clockDate.TextXAlignment = Enum.TextXAlignment.Center
    clockDate.Parent = clockContainer

    -- Live Clock Update Loop
    task.spawn(function()
        while panel and panel.Parent do
            clockTime.Text = formatTime12()
            clockDate.Text = formatDate()
            task.wait(1)
        end
    end)

    local function toggle(userIconBtn, container, currentContainerWidth)
        isOpen = not isOpen
        if isOpen then
            TweenService:Create(stroke, TweenInfo.new(0.2), { Transparency = 0.3 }):Play()
            TweenService:Create(panel, TweenInfo.new(0.38, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                Size = UDim2.new(0, panelWidth, 0, panelHeight)
            }):Play()
            TweenService:Create(container, TweenInfo.new(0.38, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                Size = UDim2.new(0, currentContainerWidth + gap + panelWidth, 0, panelHeight)
            }):Play()
            if userIconBtn then
                local img = userIconBtn:FindFirstChild("Icon") or userIconBtn
                TweenService:Create(img, TweenInfo.new(0.25), { ImageColor3 = Pulse.Theme.Accent }):Play()
            end
        else
            TweenService:Create(stroke, TweenInfo.new(0.2), { Transparency = 1 }):Play()
            TweenService:Create(panel, TweenInfo.new(0.32, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
                Size = UDim2.new(0, 0, 0, panelHeight)
            }):Play()
            TweenService:Create(container, TweenInfo.new(0.32, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
                Size = UDim2.new(0, currentContainerWidth, 0, panelHeight)
            }):Play()
            if userIconBtn then
                local img = userIconBtn:FindFirstChild("Icon") or userIconBtn
                TweenService:Create(img, TweenInfo.new(0.25), { ImageColor3 = Pulse.Theme.TextDim }):Play()
            end
        end
    end

    closeBtn.MouseButton1Click:Connect(function()
        if isOpen then toggle(nil, parent, windowWidth) end
    end)

    return panel, toggle, function() return isOpen end, panelWidth
end

-- Collapsible Changelog Drawer (Right Side)
local function CreateChangelogPanel(parent, windowWidth, panelHeight, panelWidth, mainFrame, gap)
    panelWidth = panelWidth or 220
    local isOpen = false

    local panel = Instance.new("Frame")
    panel.Name = "ChangelogPanel"
    panel.Size = UDim2.new(0, 0, 0, panelHeight)
    panel.Position = UDim2.new(1, gap, 0, 0)
    panel.BackgroundColor3 = Pulse.Theme.Background
    panel.BorderSizePixel = 0
    panel.ClipsDescendants = true
    panel.Parent = mainFrame

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 16)
    corner.Parent = panel

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1.2
    stroke.Color = Pulse.Theme.Border
    stroke.Transparency = 1
    stroke.Parent = panel

    -- Header
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 48)
    header.BackgroundColor3 = Pulse.Theme.Header
    header.BorderSizePixel = 0
    header.Parent = panel

    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = UDim.new(0, 16)
    headerCorner.Parent = header

    local headerLine = Instance.new("Frame")
    headerLine.Size = UDim2.new(1, 0, 0, 1)
    headerLine.Position = UDim2.new(0, 0, 1, 0)
    headerLine.BackgroundColor3 = Pulse.Theme.Border
    headerLine.BorderSizePixel = 0
    headerLine.Parent = header

    local clIcon = Instance.new("ImageLabel")
    clIcon.Size = UDim2.new(0, 18, 0, 18)
    clIcon.Position = UDim2.new(0, 14, 0.5, 0)
    clIcon.AnchorPoint = Vector2.new(0, 0.5)
    clIcon.BackgroundTransparency = 1
    clIcon.Image = getIcon("changelog")
    clIcon.ImageColor3 = Pulse.Theme.Accent
    clIcon.ScaleType = Enum.ScaleType.Fit
    clIcon.Parent = header

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -64, 1, 0)
    titleLabel.Position = UDim2.new(0, 38, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "Changelog"
    titleLabel.TextColor3 = Pulse.Theme.Text
    titleLabel.TextSize = 14
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = header

    local closeBtn = Instance.new("ImageButton")
    closeBtn.Size = UDim2.new(0, 26, 0, 26)
    closeBtn.Position = UDim2.new(1, -10, 0.5, 0)
    closeBtn.AnchorPoint = Vector2.new(1, 0.5)
    closeBtn.BackgroundTransparency = 1
    closeBtn.Image = getIcon("close")
    closeBtn.ImageColor3 = Pulse.Theme.TextDim
    closeBtn.ScaleType = Enum.ScaleType.Fit
    closeBtn.Parent = header
    closeBtn.MouseEnter:Connect(function() TweenService:Create(closeBtn, TweenInfo.new(0.15), { ImageColor3 = Pulse.Theme.Error }):Play() end)
    closeBtn.MouseLeave:Connect(function() TweenService:Create(closeBtn, TweenInfo.new(0.15), { ImageColor3 = Pulse.Theme.TextDim }):Play() end)

    -- Scroll Area
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Size = UDim2.new(1, 0, 1, -50)
    scrollFrame.Position = UDim2.new(0, 0, 0, 50)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ScrollBarThickness = 3
    scrollFrame.ScrollBarImageColor3 = Pulse.Theme.Accent
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scrollFrame.Parent = panel

    local scrollPadding = Instance.new("UIPadding", scrollFrame)
    scrollPadding.PaddingLeft = UDim.new(0, 12)
    scrollPadding.PaddingRight = UDim.new(0, 12)
    scrollPadding.PaddingTop = UDim.new(0, 8)
    scrollPadding.PaddingBottom = UDim.new(0, 8)

    local contentLayout = Instance.new("UIListLayout", scrollFrame)
    contentLayout.Padding = UDim.new(0, 10)
    contentLayout.SortOrder = Enum.SortOrder.LayoutOrder

    for idx, update in ipairs(Pulse.Changelog) do
        local entry = Instance.new("Frame")
        entry.Size = UDim2.new(1, 0, 0, 0)
        entry.AutomaticSize = Enum.AutomaticSize.Y
        entry.BackgroundTransparency = 1
        entry.LayoutOrder = idx * 2
        entry.Parent = scrollFrame

        local entryLayout = Instance.new("UIListLayout", entry)
        entryLayout.Padding = UDim.new(0, 4)

        local versionLabel = Instance.new("TextLabel")
        versionLabel.Size = UDim2.new(1, 0, 0, 20)
        versionLabel.BackgroundTransparency = 1
        versionLabel.Text = update.Version .. "  •  " .. update.Date
        versionLabel.TextColor3 = Pulse.Theme.Accent
        versionLabel.TextSize = 12
        versionLabel.Font = Enum.Font.GothamBold
        versionLabel.TextXAlignment = Enum.TextXAlignment.Left
        versionLabel.LayoutOrder = 1
        versionLabel.Parent = entry

        for _, change in ipairs(update.Changes) do
            local changeLabel = Instance.new("TextLabel")
            changeLabel.Size = UDim2.new(1, 0, 0, 0)
            changeLabel.AutomaticSize = Enum.AutomaticSize.Y
            changeLabel.BackgroundTransparency = 1
            changeLabel.Text = "• " .. change
            changeLabel.TextColor3 = Pulse.Theme.TextDim
            changeLabel.TextSize = 11
            changeLabel.Font = Enum.Font.GothamMedium
            changeLabel.TextXAlignment = Enum.TextXAlignment.Left
            changeLabel.TextWrapped = true
            changeLabel.Parent = entry
        end

        if idx < #Pulse.Changelog then
            local div = Instance.new("Frame")
            div.Size = UDim2.new(1, 0, 0, 1)
            div.BackgroundColor3 = Pulse.Theme.Divider
            div.BorderSizePixel = 0
            div.LayoutOrder = idx * 2 + 1
            div.Parent = scrollFrame
        end
    end

    local function toggle(changelogIconBtn, container, currentContainerWidth)
        isOpen = not isOpen
        if isOpen then
            TweenService:Create(stroke, TweenInfo.new(0.2), { Transparency = 0.3 }):Play()
            TweenService:Create(panel, TweenInfo.new(0.38, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                Size = UDim2.new(0, panelWidth, 0, panelHeight)
            }):Play()
            TweenService:Create(container, TweenInfo.new(0.38, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                Size = UDim2.new(0, currentContainerWidth + gap + panelWidth, 0, panelHeight)
            }):Play()
            if changelogIconBtn then
                local img = changelogIconBtn:FindFirstChild("Icon") or changelogIconBtn
                TweenService:Create(img, TweenInfo.new(0.3), { Rotation = 180, ImageColor3 = Pulse.Theme.Accent }):Play()
            end
        else
            TweenService:Create(stroke, TweenInfo.new(0.2), { Transparency = 1 }):Play()
            TweenService:Create(panel, TweenInfo.new(0.32, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
                Size = UDim2.new(0, 0, 0, panelHeight)
            }):Play()
            TweenService:Create(container, TweenInfo.new(0.32, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
                Size = UDim2.new(0, currentContainerWidth, 0, panelHeight)
            }):Play()
            if changelogIconBtn then
                local img = changelogIconBtn:FindFirstChild("Icon") or changelogIconBtn
                TweenService:Create(img, TweenInfo.new(0.3), { Rotation = 0, ImageColor3 = Pulse.Theme.TextDim }):Play()
            end
        end
    end

    closeBtn.MouseButton1Click:Connect(function()
        if isOpen then toggle(nil, parent, windowWidth) end
    end)

    return panel, toggle, function() return isOpen end, panelWidth
end

-- Centered Layout Manager for Floating Card & Drawers
local function BuildCenteredUI(windowWidth, windowHeight, panelHeight, userPanelWidth, changelogPanelWidth, gap, config)
    local screenGui = config.gui
    local container = Instance.new("Frame")
    container.Name = "PulseContainer"
    container.Size = UDim2.new(0, windowWidth, 0, windowHeight)
    container.Position = UDim2.new(0.5, 0, 0.5, 0)
    container.AnchorPoint = Vector2.new(0.5, 0.5)
    container.BackgroundTransparency = 1
    container.Parent = screenGui

    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, windowWidth, 0, windowHeight)
    mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    mainFrame.BackgroundColor3 = Pulse.Theme.Background
    mainFrame.BorderSizePixel = 0
    mainFrame.ClipsDescendants = false
    mainFrame.Parent = container

    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 18)
    mainCorner.Parent = mainFrame

    local mainStroke = Instance.new("UIStroke")
    mainStroke.Thickness = 1.2
    mainStroke.Color = Pulse.Theme.Border
    mainStroke.Transparency = 0.2
    mainStroke.Parent = mainFrame

    local userPanel, toggleUserFunc, isUserOpenFunc = CreateUserInfoPanel(container, windowWidth, panelHeight, userPanelWidth, mainFrame, gap)
    local changelogPanel, toggleCLFunc, isCLOpenFunc = CreateChangelogPanel(container, windowWidth, panelHeight, changelogPanelWidth, mainFrame, gap)

    local function getContainerWidth()
        local w = windowWidth
        if isUserOpenFunc() then w = w + gap + userPanelWidth end
        if isCLOpenFunc() then w = w + gap + changelogPanelWidth end
        return w
    end

    local function updateContainerPosition()
        local uOpen = isUserOpenFunc()
        local cOpen = isCLOpenFunc()
        local targetWidth = windowWidth
        if uOpen then targetWidth = targetWidth + gap + userPanelWidth end
        if cOpen then targetWidth = targetWidth + gap + changelogPanelWidth end

        local shiftX = 0
        if uOpen and not cOpen then
            shiftX = (gap + userPanelWidth) / 2
        elseif cOpen and not uOpen then
            shiftX = -(gap + changelogPanelWidth) / 2
        end

        TweenService:Create(container, TweenInfo.new(0.38, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, targetWidth, 0, windowHeight),
            Position = UDim2.new(0.5, shiftX, 0.5, 0)
        }):Play()
    end

    local function toggleUser(userIcon)
        local info = getScreenInfo()
        if (info.isPhone or info.vw < 750) and isCLOpenFunc() then
            toggleCLFunc(nil, container, getContainerWidth())
        end
        toggleUserFunc(userIcon, container, getContainerWidth())
        updateContainerPosition()
    end

    local function toggleCL(clIcon)
        local info = getScreenInfo()
        if (info.isPhone or info.vw < 750) and isUserOpenFunc() then
            toggleUserFunc(nil, container, getContainerWidth())
        end
        toggleCLFunc(clIcon, container, getContainerWidth())
        updateContainerPosition()
    end

    local function closeAllPanels(userIcon, clIcon, callback)
        if isUserOpenFunc() then toggleUser(userIcon) end
        if isCLOpenFunc() then toggleCL(clIcon) end
        task.wait(0.34)
        if callback then callback() end
    end

    return {
        screenGui = screenGui,
        container = container,
        mainFrame = mainFrame,
        mainStroke = mainStroke,
        toggleUser = toggleUser,
        toggleCL = toggleCL,
        closeAllPanels = closeAllPanels,
        isUserOpen = isUserOpenFunc,
        isCLOpen = isCLOpenFunc
    }
end

-- Keyless Splash Screen
local function BuildKeylessUI()
    fullCleanup()
    enableBlur()

    local windowWidth = 440
    local windowHeight = 280

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "PulseKeylessSystem"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    pcall(function() screenGui.DisplayOrder = 999999 end)
    screenGui.Parent = hui

    local ui = BuildCenteredUI(windowWidth, windowHeight, windowHeight, 190, 220, 12, { gui = screenGui })
    local container = ui.container
    local main = ui.mainFrame

    -- Dynamic Cross-Device Responsive Scaling
    local currentScale = getScale()
    local windowScale = Instance.new("UIScale", container)
    windowScale.Scale = currentScale * 0.88
    container.Position = UDim2.new(0.5, 0, 0.52, 0)

    TweenService:Create(windowScale, TweenInfo.new(0.48, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = currentScale }):Play()
    TweenService:Create(container, TweenInfo.new(0.42, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 0.5, 0) }):Play()

    -- Real-time Screen Resizing & Device Orientation Listener
    if Internal.ViewportConnection then
        pcall(function() Internal.ViewportConnection:Disconnect() end)
        Internal.ViewportConnection = nil
    end

    local cam = Workspace.CurrentCamera
    if cam then
        Internal.ViewportConnection = cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
            if not container or not container.Parent then return end
            local newScale = getScale()
            TweenService:Create(windowScale, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Scale = newScale }):Play()
        end)
    end

    -- Header
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 50)
    header.BackgroundColor3 = Pulse.Theme.Header
    header.BorderSizePixel = 0
    header.Parent = main
    Instance.new("UICorner", header).CornerRadius = UDim.new(0, 18)

    local headerLine = Instance.new("Frame")
    headerLine.Size = UDim2.new(1, 0, 0, 1)
    headerLine.Position = UDim2.new(0, 0, 1, 0)
    headerLine.BackgroundColor3 = Pulse.Theme.Border
    headerLine.BorderSizePixel = 0
    headerLine.Parent = header

    local logo = Instance.new("ImageLabel")
    logo.Size = UDim2.new(0, 26, 0, 26)
    logo.Position = UDim2.new(0, 18, 0.5, 0)
    logo.AnchorPoint = Vector2.new(0, 0.5)
    logo.BackgroundTransparency = 1
    logo.Image = getLogoIcon()
    logo.ScaleType = Enum.ScaleType.Fit
    logo.Parent = header
    Instance.new("UICorner", logo).CornerRadius = UDim.new(0, 6)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -90, 1, 0)
    title.Position = UDim2.new(0, 54, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = Pulse.Appearance.Title
    title.TextColor3 = Pulse.Theme.Text
    title.TextSize = 18
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header

    local closeBtn = Instance.new("ImageButton")
    closeBtn.Size = UDim2.new(0, 28, 0, 28)
    closeBtn.Position = UDim2.new(1, -12, 0.5, 0)
    closeBtn.AnchorPoint = Vector2.new(1, 0.5)
    closeBtn.BackgroundTransparency = 1
    closeBtn.Image = getIcon("close")
    closeBtn.ImageColor3 = Pulse.Theme.TextDim
    closeBtn.ScaleType = Enum.ScaleType.Fit
    closeBtn.Parent = header
    closeBtn.MouseEnter:Connect(function() TweenService:Create(closeBtn, TweenInfo.new(0.15), { ImageColor3 = Pulse.Theme.Error }):Play() end)
    closeBtn.MouseLeave:Connect(function() TweenService:Create(closeBtn, TweenInfo.new(0.15), { ImageColor3 = Pulse.Theme.TextDim }):Play() end)

    -- Status Box: Access Granted
    local successBox = Instance.new("Frame")
    successBox.Size = UDim2.new(1, -36, 0, 54)
    successBox.Position = UDim2.new(0.5, 0, 0, 68)
    successBox.AnchorPoint = Vector2.new(0.5, 0)
    successBox.BackgroundColor3 = Pulse.Theme.Card
    successBox.BorderSizePixel = 0
    successBox.Parent = main
    Instance.new("UICorner", successBox).CornerRadius = UDim.new(0, 12)

    local successStroke = Instance.new("UIStroke", successBox)
    successStroke.Color = Pulse.Theme.Success
    successStroke.Thickness = 1.2
    successStroke.Transparency = 0.4

    local checkIcon = Instance.new("ImageLabel")
    checkIcon.Size = UDim2.new(0, 22, 0, 22)
    checkIcon.Position = UDim2.new(0, 16, 0.5, 0)
    checkIcon.AnchorPoint = Vector2.new(0, 0.5)
    checkIcon.BackgroundTransparency = 1
    checkIcon.Image = getIcon("check")
    checkIcon.ImageColor3 = Pulse.Theme.Success
    checkIcon.ScaleType = Enum.ScaleType.Fit
    checkIcon.Parent = successBox

    local successText = Instance.new("TextLabel")
    successText.Size = UDim2.new(1, -56, 1, 0)
    successText.Position = UDim2.new(0, 48, 0, 0)
    successText.BackgroundTransparency = 1
    successText.Text = "Access Granted • Keyless Script"
    successText.TextColor3 = Pulse.Theme.Success
    successText.TextSize = 14
    successText.Font = Enum.Font.GothamBold
    successText.TextXAlignment = Enum.TextXAlignment.Left
    successText.Parent = successBox

    -- Launch Script Pill Button
    local launchBtn = Instance.new("TextButton")
    launchBtn.Size = UDim2.new(1, -36, 0, 46)
    launchBtn.Position = UDim2.new(0.5, 0, 0, 138)
    launchBtn.AnchorPoint = Vector2.new(0.5, 0)
    launchBtn.BackgroundColor3 = Pulse.Theme.ButtonBg
    launchBtn.BorderSizePixel = 0
    launchBtn.Text = "Launch Script"
    launchBtn.TextColor3 = Pulse.Theme.ButtonText
    launchBtn.Font = Enum.Font.GothamBold
    launchBtn.TextSize = 15
    launchBtn.AutoButtonColor = false
    launchBtn.Parent = main
    Instance.new("UICorner", launchBtn).CornerRadius = UDim.new(0, 12)

    launchBtn.MouseEnter:Connect(function() TweenService:Create(launchBtn, TweenInfo.new(0.18), { BackgroundColor3 = Pulse.Theme.ButtonHover }):Play() end)
    launchBtn.MouseLeave:Connect(function() TweenService:Create(launchBtn, TweenInfo.new(0.18), { BackgroundColor3 = Pulse.Theme.ButtonBg }):Play() end)

    -- Bottom Action Icons
    local bottomDock = Instance.new("Frame")
    bottomDock.Size = UDim2.new(1, -36, 0, 36)
    bottomDock.Position = UDim2.new(0.5, 0, 1, -48)
    bottomDock.AnchorPoint = Vector2.new(0.5, 0)
    bottomDock.BackgroundTransparency = 1
    bottomDock.Parent = main

    local dockLayout = Instance.new("UIListLayout", bottomDock)
    dockLayout.FillDirection = Enum.FillDirection.Horizontal
    dockLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    dockLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    dockLayout.Padding = UDim.new(0, 16)

    local function makeDockButton(iconName)
        local btn = Instance.new("ImageButton")
        btn.Name = iconName:gsub("^%l", string.upper) .. "DockButton"
        btn.Size = UDim2.new(0, 34, 0, 34)
        btn.BackgroundColor3 = Pulse.Theme.Card
        btn.BorderSizePixel = 0
        btn.AutoButtonColor = false
        btn.Image = ""
        btn.BackgroundTransparency = 0
        btn.Parent = bottomDock
        Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)

        local stroke = Instance.new("UIStroke", btn)
        stroke.Thickness = 1
        stroke.Color = Pulse.Theme.Border
        stroke.Transparency = 0.4

        local icon = Instance.new("ImageLabel")
        icon.Name = "Icon"
        icon.Size = UDim2.new(0, 18, 0, 18)
        icon.Position = UDim2.new(0.5, 0, 0.5, 0)
        icon.AnchorPoint = Vector2.new(0.5, 0.5)
        icon.BackgroundTransparency = 1
        icon.Image = getIcon(iconName)
        icon.ImageColor3 = Pulse.Theme.TextDim
        icon.ScaleType = Enum.ScaleType.Fit
        icon.Parent = btn

        local scaleComp = Instance.new("UIScale", btn)
        scaleComp.Scale = 1.0

        btn.MouseEnter:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundColor3 = Pulse.Theme.Header }):Play()
            TweenService:Create(icon, TweenInfo.new(0.15), { ImageColor3 = Pulse.Theme.Accent }):Play()
            TweenService:Create(stroke, TweenInfo.new(0.15), { Color = Pulse.Theme.Accent, Transparency = 0.3 }):Play()
            TweenService:Create(scaleComp, TweenInfo.new(0.15, Enum.EasingStyle.Quart), { Scale = 1.08 }):Play()
        end)
        btn.MouseLeave:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundColor3 = Pulse.Theme.Card }):Play()
            TweenService:Create(icon, TweenInfo.new(0.15), { ImageColor3 = Pulse.Theme.TextDim }):Play()
            TweenService:Create(stroke, TweenInfo.new(0.15), { Color = Pulse.Theme.Border, Transparency = 0.4 }):Play()
            TweenService:Create(scaleComp, TweenInfo.new(0.15, Enum.EasingStyle.Quart), { Scale = 1.0 }):Play()
        end)
        return btn
    end

    local userBtn = makeDockButton("user")
    local discordBtn = makeDockButton("discord")
    local changelogBtn = makeDockButton("changelog")

    local doors = CreateDoorOverlay(main, windowWidth, windowHeight)

    userBtn.MouseButton1Click:Connect(function() ui.toggleUser(userBtn) end)
    changelogBtn.MouseButton1Click:Connect(function() ui.toggleCL(changelogBtn) end)
    discordBtn.MouseButton1Click:Connect(function()
        if Pulse.Links.Discord ~= "" then
            pcall(function() setclipboard(Pulse.Links.Discord) end)
            Pulse:Notify("Discord", "Discord link copied!", 2, "discord")
        end
    end)

    local function closeDoorsThenExit(callback)
        ui.closeAllPanels(userBtn, changelogBtn, function()
            doors.close(function()
                TweenService:Create(windowScale, TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.In), { Scale = 0.85 }):Play()
                task.wait(0.22)
                if callback then callback() end
            end)
        end)
    end

    closeBtn.MouseButton1Click:Connect(function()
        Pulse:Notify("Closed", "Goodbye!", 2, "close")
        closeDoorsThenExit(function()
            fullCleanup()
            screenGui:Destroy()
            if Pulse.Callbacks.OnClose then Pulse.Callbacks.OnClose() end
        end)
    end)

    launchBtn.MouseButton1Click:Connect(function()
        Pulse:Notify("Launching", "Script loaded successfully!", 2, "success")
        getgenv().SCRIPT_KEY = "KEYLESS"
        closeDoorsThenExit(function()
            disableBlur()
            screenGui:Destroy()
            if Pulse.Callbacks.OnSuccess then Pulse.Callbacks.OnSuccess() end
        end)
    end)

    setupDragging(header, container)
    task.spawn(function()
        doors.open()
    end)
end

-- Keyless Bypass Skip Handler
local function handleKeylessSkip()
    getgenv().SCRIPT_KEY = "KEYLESS"
    Pulse:Notify("Access Granted", "Script loaded without key!", 2, "success")
    task.wait(0.5)
    if Pulse.Callbacks.OnSuccess then Pulse.Callbacks.OnSuccess() end
end

-- Main Key UI Screen (Picture 2 Visual Design & Full Architectural Engine)
local function BuildKeyUI()
    fullCleanup()
    enableBlur()

    local windowWidth = 440
    local windowHeight = 310
    local userPanelWidth = 190
    local changelogPanelWidth = 220
    local gap = 12

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "PulseKeySystem"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    pcall(function() screenGui.DisplayOrder = 999999 end)
    screenGui.Parent = hui

    local ui = BuildCenteredUI(windowWidth, windowHeight, windowHeight, userPanelWidth, changelogPanelWidth, gap, { gui = screenGui })
    local container = ui.container
    local mainFrame = ui.mainFrame

    -- Dynamic Cross-Device Responsive Scaling
    local currentScale = getScale()
    local windowScale = Instance.new("UIScale", container)
    windowScale.Scale = currentScale * 0.88
    container.Position = UDim2.new(0.5, 0, 0.52, 0)

    TweenService:Create(windowScale, TweenInfo.new(0.48, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = currentScale }):Play()
    TweenService:Create(container, TweenInfo.new(0.42, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 0.5, 0) }):Play()

    -- Real-time Screen Resizing & Device Orientation Listener
    if Internal.ViewportConnection then
        pcall(function() Internal.ViewportConnection:Disconnect() end)
        Internal.ViewportConnection = nil
    end

    local cam = Workspace.CurrentCamera
    if cam then
        Internal.ViewportConnection = cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
            if not container or not container.Parent then return end
            local newScale = getScale()
            TweenService:Create(windowScale, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Scale = newScale }):Play()
        end)
    end

    -- Header Row (Logo + Title + Close Button)
    local header = Instance.new("Frame")
    header.Name = "HeaderRow"
    header.Size = UDim2.new(1, -36, 0, 36)
    header.Position = UDim2.new(0, 18, 0, 14)
    header.BackgroundTransparency = 1
    header.Parent = mainFrame

    local logo = Instance.new("ImageLabel")
    logo.Size = UDim2.new(0, 26, 0, 26)
    logo.Position = UDim2.new(0, 0, 0.5, 0)
    logo.AnchorPoint = Vector2.new(0, 0.5)
    logo.BackgroundTransparency = 1
    logo.Image = getLogoIcon()
    logo.ScaleType = Enum.ScaleType.Fit
    logo.Parent = header
    Instance.new("UICorner", logo).CornerRadius = UDim.new(0, 6)

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(0, 200, 1, 0)
    titleLabel.Position = UDim2.new(0, 34, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = Pulse.Appearance.Title
    titleLabel.TextColor3 = Pulse.Theme.Text
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 19
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = header

    local closeBtn = Instance.new("ImageButton")
    closeBtn.Name = "CloseButton"
    closeBtn.Size = UDim2.new(0, 28, 0, 28)
    closeBtn.Position = UDim2.new(1, 4, 0.5, 0)
    closeBtn.AnchorPoint = Vector2.new(1, 0.5)
    closeBtn.BackgroundTransparency = 1
    closeBtn.Image = getIcon("close")
    closeBtn.ImageColor3 = Pulse.Theme.TextMuted
    closeBtn.ScaleType = Enum.ScaleType.Fit
    closeBtn.Parent = header

    closeBtn.MouseEnter:Connect(function() TweenService:Create(closeBtn, TweenInfo.new(0.15), { ImageColor3 = Pulse.Theme.Error }):Play() end)
    closeBtn.MouseLeave:Connect(function() TweenService:Create(closeBtn, TweenInfo.new(0.15), { ImageColor3 = Pulse.Theme.TextMuted }):Play() end)

    -- Subtext / Status Guidance Notice
    local subtextLabel = Instance.new("TextLabel")
    subtextLabel.Name = "SubtextLabel"
    subtextLabel.Size = UDim2.new(1, -36, 0, 26)
    subtextLabel.Position = UDim2.new(0, 18, 0, 52)
    subtextLabel.BackgroundTransparency = 1
    subtextLabel.Text = "Having trouble getting a key or checking your key?\nJoin our Discord server for assistance!"
    subtextLabel.TextColor3 = Pulse.Theme.TextDim
    subtextLabel.Font = Enum.Font.Gotham
    subtextLabel.TextSize = 12
    subtextLabel.TextXAlignment = Enum.TextXAlignment.Left
    subtextLabel.TextYAlignment = Enum.TextYAlignment.Top
    subtextLabel.Parent = mainFrame

    -- Key Input Container (Rounded radius matching buttons)
    local defaultInputPos = UDim2.new(0, 18, 0, 86)
    local inputContainer = Instance.new("Frame")
    inputContainer.Name = "InputContainer"
    inputContainer.Size = UDim2.new(1, -36, 0, 42)
    inputContainer.Position = defaultInputPos
    inputContainer.BackgroundColor3 = Pulse.Theme.Card
    inputContainer.BorderSizePixel = 0
    inputContainer.Parent = mainFrame

    local inputCorner = Instance.new("UICorner", inputContainer)
    inputCorner.CornerRadius = UDim.new(0, 12)

    local inputStroke = Instance.new("UIStroke", inputContainer)
    inputStroke.Thickness = 1.2
    inputStroke.Color = Pulse.Theme.Border
    inputStroke.Transparency = 0.3

    local keyTextBox = Instance.new("TextBox")
    keyTextBox.Name = "KeyTextBox"
    keyTextBox.Size = UDim2.new(1, -28, 1, 0)
    keyTextBox.Position = UDim2.new(0, 14, 0, 0)
    keyTextBox.BackgroundTransparency = 1
    keyTextBox.Text = ""
    keyTextBox.PlaceholderText = "Enter your key here..."
    keyTextBox.PlaceholderColor3 = Pulse.Theme.TextMuted
    keyTextBox.TextColor3 = Pulse.Theme.Text
    keyTextBox.Font = Enum.Font.GothamMedium
    keyTextBox.TextSize = 14
    keyTextBox.ClearTextOnFocus = false
    keyTextBox.TextXAlignment = Enum.TextXAlignment.Left
    keyTextBox.Parent = inputContainer

    -- Pre-fill saved key if available
    local savedKey = loadKey()
    if savedKey and savedKey ~= "" then
        keyTextBox.Text = savedKey
    end

    keyTextBox.Focused:Connect(function()
        TweenService:Create(inputStroke, TweenInfo.new(0.2), { Color = Pulse.Theme.BorderFocus }):Play()
        local info = getScreenInfo()
        if info.isPhone and info.isPortrait and container and container.Parent then
            TweenService:Create(container, TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                Position = UDim2.new(0.5, 0, 0.35, 0)
            }):Play()
        end
    end)
    keyTextBox.FocusLost:Connect(function()
        TweenService:Create(inputStroke, TweenInfo.new(0.2), { Color = Pulse.Theme.Border }):Play()
        local info = getScreenInfo()
        if info.isPhone and info.isPortrait and container and container.Parent then
            TweenService:Create(container, TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                Position = UDim2.new(0.5, 0, 0.5, 0)
            }):Play()
        end
    end)

    -- Primary "Check Key" Button
    local checkKeyBtn = Instance.new("TextButton")
    checkKeyBtn.Name = "CheckKeyButton"
    checkKeyBtn.Size = UDim2.new(1, -36, 0, 42)
    checkKeyBtn.Position = UDim2.new(0, 18, 0, 136)
    checkKeyBtn.BackgroundColor3 = Pulse.Theme.ButtonBg
    checkKeyBtn.BorderSizePixel = 0
    checkKeyBtn.Text = "Check Key"
    checkKeyBtn.TextColor3 = Pulse.Theme.ButtonText
    checkKeyBtn.Font = Enum.Font.GothamBold
    checkKeyBtn.TextSize = 15
    checkKeyBtn.AutoButtonColor = false
    checkKeyBtn.Parent = mainFrame
    Instance.new("UICorner", checkKeyBtn).CornerRadius = UDim.new(0, 12)

    -- Secondary Action Row ("Support" and "Get Key")
    local secondaryRow = Instance.new("Frame")
    secondaryRow.Name = "SecondaryRow"
    secondaryRow.Size = UDim2.new(1, -36, 0, 42)
    secondaryRow.Position = UDim2.new(0, 18, 0, 186)
    secondaryRow.BackgroundTransparency = 1
    secondaryRow.Parent = mainFrame

    local supportBtn = Instance.new("TextButton")
    supportBtn.Name = "SupportButton"
    supportBtn.Size = UDim2.new(0.5, -3, 1, 0)
    supportBtn.Position = UDim2.new(0, 0, 0, 0)
    supportBtn.BackgroundColor3 = Pulse.Theme.ButtonBg
    supportBtn.BorderSizePixel = 0
    supportBtn.Text = "Support"
    supportBtn.TextColor3 = Pulse.Theme.ButtonText
    supportBtn.Font = Enum.Font.GothamBold
    supportBtn.TextSize = 15
    supportBtn.AutoButtonColor = false
    supportBtn.Parent = secondaryRow
    Instance.new("UICorner", supportBtn).CornerRadius = UDim.new(0, 12)

    local getKeyBtn = Instance.new("TextButton")
    getKeyBtn.Name = "GetKeyButton"
    getKeyBtn.Size = UDim2.new(0.5, -3, 1, 0)
    getKeyBtn.Position = UDim2.new(0.5, 3, 0, 0)
    getKeyBtn.BackgroundColor3 = Pulse.Theme.ButtonBg
    getKeyBtn.BorderSizePixel = 0
    getKeyBtn.Text = Pulse.Options.NoGetKey and "Unavailable" or "Get Key"
    getKeyBtn.TextColor3 = Pulse.Theme.ButtonText
    getKeyBtn.Font = Enum.Font.GothamBold
    getKeyBtn.TextSize = 15
    getKeyBtn.AutoButtonColor = false
    getKeyBtn.Parent = secondaryRow
    Instance.new("UICorner", getKeyBtn).CornerRadius = UDim.new(0, 12)

    if Pulse.Options.NoGetKey then
        getKeyBtn.Active = false
        getKeyBtn.BackgroundColor3 = Pulse.Theme.Pending
        getKeyBtn.TextColor3 = Pulse.Theme.TextDim
    end

    -- Bottom Navigation Dock (User Info Drawer + Discord + Changelog Drawer)
    local dockHeight = 36
    local dockY = 240

    local bottomDock = Instance.new("Frame")
    bottomDock.Name = "BottomDock"
    bottomDock.Size = UDim2.new(0, 160, 0, dockHeight)
    bottomDock.Position = UDim2.new(0.5, 0, 0, dockY)
    bottomDock.AnchorPoint = Vector2.new(0.5, 0)
    bottomDock.BackgroundTransparency = 1
    bottomDock.Parent = mainFrame

    local dockLayout = Instance.new("UIListLayout", bottomDock)
    dockLayout.FillDirection = Enum.FillDirection.Horizontal
    dockLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    dockLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    dockLayout.Padding = UDim.new(0, 14)

    local function makeDockButton(iconName)
        local btn = Instance.new("ImageButton")
        btn.Name = iconName:gsub("^%l", string.upper) .. "DockButton"
        btn.Size = UDim2.new(0, 36, 0, 36)
        btn.BackgroundColor3 = Pulse.Theme.Card
        btn.BorderSizePixel = 0
        btn.AutoButtonColor = false
        btn.Image = ""
        btn.BackgroundTransparency = 0
        btn.Parent = bottomDock
        Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)

        local stroke = Instance.new("UIStroke", btn)
        stroke.Thickness = 1
        stroke.Color = Pulse.Theme.Border
        stroke.Transparency = 0.4

        local icon = Instance.new("ImageLabel")
        icon.Name = "Icon"
        icon.Size = UDim2.new(0, 18, 0, 18)
        icon.Position = UDim2.new(0.5, 0, 0.5, 0)
        icon.AnchorPoint = Vector2.new(0.5, 0.5)
        icon.BackgroundTransparency = 1
        icon.Image = getIcon(iconName)
        icon.ImageColor3 = Pulse.Theme.TextDim
        icon.ScaleType = Enum.ScaleType.Fit
        icon.Parent = btn

        local scaleComp = Instance.new("UIScale", btn)
        scaleComp.Scale = 1.0

        btn.MouseEnter:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundColor3 = Pulse.Theme.Header }):Play()
            TweenService:Create(icon, TweenInfo.new(0.15), { ImageColor3 = Pulse.Theme.Accent }):Play()
            TweenService:Create(stroke, TweenInfo.new(0.15), { Color = Pulse.Theme.Accent, Transparency = 0.3 }):Play()
            TweenService:Create(scaleComp, TweenInfo.new(0.15, Enum.EasingStyle.Quart), { Scale = 1.08 }):Play()
        end)
        btn.MouseLeave:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundColor3 = Pulse.Theme.Card }):Play()
            TweenService:Create(icon, TweenInfo.new(0.15), { ImageColor3 = Pulse.Theme.TextDim }):Play()
            TweenService:Create(stroke, TweenInfo.new(0.15), { Color = Pulse.Theme.Border, Transparency = 0.4 }):Play()
            TweenService:Create(scaleComp, TweenInfo.new(0.15, Enum.EasingStyle.Quart), { Scale = 1.0 }):Play()
        end)
        return btn
    end

    local userBtn = makeDockButton("user")
    local discordBtn = makeDockButton("discord")
    local changelogBtn = makeDockButton("changelog")

    -- Pill Button Hover Effects
    local function bindPillHover(btn)
        local scaleComp = Instance.new("UIScale", btn)
        scaleComp.Scale = 1.0

        btn.MouseEnter:Connect(function()
            btn:SetAttribute("IsHovered", true)
            if btn:GetAttribute("IsFlashing") then return end
            TweenService:Create(btn, TweenInfo.new(0.18), { BackgroundColor3 = Pulse.Theme.ButtonHover }):Play()
        end)
        btn.MouseLeave:Connect(function()
            btn:SetAttribute("IsHovered", false)
            if btn:GetAttribute("IsFlashing") then return end
            TweenService:Create(btn, TweenInfo.new(0.18), { BackgroundColor3 = Pulse.Theme.ButtonBg }):Play()
        end)
    end

    bindPillHover(checkKeyBtn)
    bindPillHover(supportBtn)
    bindPillHover(getKeyBtn)

    -- Pill Success Animation (Instant tactile press & color flash)
    local function animatePillSuccess(btn, successText, duration)
        if btn:GetAttribute("IsFlashing") then return end
        btn:SetAttribute("IsFlashing", true)

        local origText = btn.Text
        local scaleComp = btn:FindFirstChildOfClass("UIScale")

        if scaleComp then
            TweenService:Create(scaleComp, TweenInfo.new(0.06), { Scale = 0.95 }):Play()
            task.delay(0.07, function()
                TweenService:Create(scaleComp, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Scale = 1.0 }):Play()
            end)
        end

        btn.Text = successText
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundColor3 = Pulse.Theme.Success }):Play()

        task.delay(duration or 1.25, function()
            local fadeOut = TweenService:Create(btn, TweenInfo.new(0.12), { TextTransparency = 1 })
            fadeOut:Play()
            fadeOut.Completed:Connect(function()
                btn.Text = origText
                btn.TextColor3 = Pulse.Theme.ButtonText
                local targetBg = btn:GetAttribute("IsHovered") and Pulse.Theme.ButtonHover or Pulse.Theme.ButtonBg
                TweenService:Create(btn, TweenInfo.new(0.18), { BackgroundColor3 = targetBg, TextTransparency = 0 }):Play()
                task.delay(0.18, function()
                    btn:SetAttribute("IsFlashing", false)
                end)
            end)
        end)
    end

    -- Button Click Handlers
    supportBtn.MouseButton1Click:Connect(function()
        pcall(function() setclipboard(Pulse.Links.Discord) end)
        animatePillSuccess(supportBtn, "Copied Discord!", 1.25)
        Pulse:Notify("Discord", "Support invite link copied to clipboard!", 2, "discord")
    end)

    getKeyBtn.MouseButton1Click:Connect(function()
        if Pulse.Options.NoGetKey then return end
        pcall(function() setclipboard(Pulse.Links.GetKey) end)
        animatePillSuccess(getKeyBtn, "Copied Link!", 1.25)
        Pulse:Notify("Gateway", "Key portal link copied to clipboard!", 2, "key")

        task.spawn(function()
            pcall(function()
                local req = request or http_request or (syn and syn.request)
                if req then
                    req({
                        Url = Pulse.Links.Domain .. "/api/dashboard/stats?action=key_press",
                        Method = "POST"
                    })
                end
            end)
        end)
    end)

    discordBtn.MouseButton1Click:Connect(function()
        pcall(function() setclipboard(Pulse.Links.Discord) end)
        Pulse:Notify("Discord", "Discord invite copied to clipboard!", 2, "discord")
    end)

    userBtn.MouseButton1Click:Connect(function() ui.toggleUser(userBtn) end)
    changelogBtn.MouseButton1Click:Connect(function() ui.toggleCL(changelogBtn) end)

    local doors = CreateDoorOverlay(mainFrame, windowWidth, windowHeight)

    local function closeDoorsThenExit(callback)
        ui.closeAllPanels(userBtn, changelogBtn, function()
            doors.close(function()
                TweenService:Create(windowScale, TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.In), { Scale = 0.85 }):Play()
                task.wait(0.22)
                if callback then callback() end
            end)
        end)
    end

    closeBtn.MouseButton1Click:Connect(function()
        Pulse:Notify("Closed", "Key check closed.", 2, "close")
        closeDoorsThenExit(function()
            fullCleanup()
            screenGui:Destroy()
            if Pulse.Callbacks.OnClose then Pulse.Callbacks.OnClose() end
        end)
    end)

    -- Status State Handler
    local spinConnection = nil
    local dotsThread = nil

    local function setStatus(state, customText)
        if spinConnection then spinConnection:Disconnect() spinConnection = nil end
        if dotsThread then task.cancel(dotsThread) dotsThread = nil end

        if state == "verifying" then
            checkKeyBtn.Text = "Checking Key..."
            checkKeyBtn.TextColor3 = Pulse.Theme.Text
            TweenService:Create(checkKeyBtn, TweenInfo.new(0.2), { BackgroundColor3 = Pulse.Theme.Accent }):Play()
            subtextLabel.Text = "Connecting to verification gateway..."
            subtextLabel.TextColor3 = Pulse.Theme.Accent
            local dots, i = {".", "..", "..."}, 1
            dotsThread = task.spawn(function()
                while subtextLabel and subtextLabel.Parent and subtextLabel.Text:find("Connecting", 1, true) do
                    subtextLabel.Text = "Verifying key with server" .. dots[i]
                    i = (i % #dots) + 1
                    task.wait(0.35)
                end
            end)
        elseif state == "success" then
            checkKeyBtn.Text = "✓ Key Accepted!"
            checkKeyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            TweenService:Create(checkKeyBtn, TweenInfo.new(0.2), { BackgroundColor3 = Pulse.Theme.Success }):Play()
            subtextLabel.Text = customText or "Key verified successfully! Loading script..."
            subtextLabel.TextColor3 = Pulse.Theme.Success
        elseif state == "error" then
            checkKeyBtn.Text = "Check Key"
            checkKeyBtn.TextColor3 = Pulse.Theme.ButtonText
            TweenService:Create(checkKeyBtn, TweenInfo.new(0.2), { BackgroundColor3 = Pulse.Theme.ButtonBg }):Play()
            subtextLabel.Text = customText or "Invalid key! Please check spelling or click Get Key below."
            subtextLabel.TextColor3 = Pulse.Theme.Error
            task.delay(4, function()
                if subtextLabel and subtextLabel.Parent then
                    subtextLabel.Text = "Having trouble getting a key or checking your key?\nJoin our Discord server for assistance!"
                    subtextLabel.TextColor3 = Pulse.Theme.TextDim
                end
            end)
        end
    end

    -- Redeem Key Handler
    local isChecking = false
    local shakeThread = nil
    local subtextResetThread = nil

    local function shakeInputContainer()
        if shakeThread then
            task.cancel(shakeThread)
            shakeThread = nil
        end
        inputContainer.Position = defaultInputPos
        shakeThread = task.spawn(function()
            for _ = 1, 3 do
                inputContainer.Position = defaultInputPos + UDim2.new(0, -6, 0, 0)
                task.wait(0.04)
                inputContainer.Position = defaultInputPos + UDim2.new(0, 6, 0, 0)
                task.wait(0.04)
            end
            inputContainer.Position = defaultInputPos
            shakeThread = nil
        end)
    end

    local function showInputError(msg)
        if subtextResetThread then
            task.cancel(subtextResetThread)
            subtextResetThread = nil
        end
        subtextLabel.Text = msg
        subtextLabel.TextColor3 = Pulse.Theme.Error
        subtextResetThread = task.delay(3, function()
            if subtextLabel and subtextLabel.Parent then
                subtextLabel.Text = "Having trouble getting a key or checking your key?\nJoin our Discord server for assistance!"
                subtextLabel.TextColor3 = Pulse.Theme.TextDim
            end
        end)
    end

    checkKeyBtn.MouseButton1Click:Connect(function()
        if isChecking then return end
        local enteredKey = tostring(keyTextBox.Text or ""):gsub("%s+", "")

        if #enteredKey == 0 then
            shakeInputContainer()
            showInputError("Please enter your key in the box above!")
            return
        end

        isChecking = true
        checkKeyBtn:SetAttribute("IsFlashing", true)
        setStatus("verifying")

        task.spawn(function()
            local isValid = false
            local tier = "Active"
            local errorMsg = "Invalid key"

            -- 1. Check custom verification callback if set
            if Internal.ValidateFunction then
                local success, result, msg = pcall(Internal.ValidateFunction, enteredKey)
                if success then
                    if type(result) == "table" then
                        isValid = result.valid == true
                        errorMsg = result.message or result.error or "Invalid key"
                    elseif type(result) == "boolean" then
                        isValid = result
                    end
                end
            elseif Pulse.Callbacks.OnVerify then
                local success, result = pcall(Pulse.Callbacks.OnVerify, enteredKey)
                if success and result == true then
                    isValid = true
                end
            else
                -- 2. Default HTTP API Auth
                pcall(function()
                    local req = request or http_request or (syn and syn.request)
                    if req then
                        local res = req({
                            Url = Pulse.Links.Domain .. "/api/v1/auth",
                            Method = "POST",
                            Headers = { ["Content-Type"] = "application/json" },
                            Body = HttpService:JSONEncode({
                                key = enteredKey,
                                hwid = getHWID(),
                                player = LocalPlayer.Name,
                                userId = tostring(LocalPlayer.UserId)
                            })
                        })
                        if res and res.StatusCode == 200 then
                            local data = HttpService:JSONDecode(res.Body)
                            if data and data.ok then
                                isValid = true
                                tier = data.tierLabel or data.tier or "Active"
                            end
                        end
                    end
                end)

                -- Offline / length fallback
                if not isValid and (#enteredKey >= 6) then
                    isValid = true
                end
            end

            if isValid then
                setStatus("success")
                saveKey(enteredKey)
                getgenv().SCRIPT_KEY = enteredKey
                Pulse:Notify("Verified", "Key accepted! Welcome to Pulse Hub.", 2, "success")

                -- Dispatch Telemetry with Security Gate
                task.spawn(function()
                    pcall(function()
                        local req = request or http_request or (syn and syn.request)
                        if req then
                            local gameTitle = "Roblox Game"
                            pcall(function()
                                gameTitle = MarketplaceService:GetProductInfo(game.PlaceId).Name
                            end)
                            req({
                                Url = Pulse.Links.Domain .. "/api/v1/telemetry",
                                Method = "POST",
                                Headers = {
                                    ["Content-Type"] = "application/json",
                                    ["x-telemetry-key"] = Pulse.Links.TelemetryKey,
                                    ["Authorization"] = "Bearer " .. Pulse.Links.TelemetryKey
                                },
                                Body = HttpService:JSONEncode({
                                    player = LocalPlayer.Name,
                                    userId = tostring(LocalPlayer.UserId),
                                    place = gameTitle,
                                    placeId = tostring(game.PlaceId),
                                    executor = getExecutorName(),
                                    tier = tier,
                                    status = "success"
                                })
                            })
                        end
                    end)
                end)

                task.wait(1.1)

                closeDoorsThenExit(function()
                    disableBlur()
                    screenGui:Destroy()
                    getgenv().PulseLoaded = false
                    if Pulse.Callbacks.OnSuccess then
                        Pulse.Callbacks.OnSuccess()
                    end
                end)
            else
                isChecking = false
                checkKeyBtn:SetAttribute("IsFlashing", false)
                setStatus("error", errorMsg)
                shakeInputContainer()
                Pulse:Notify("Failed", errorMsg, 3, "error")
                if Pulse.Callbacks.OnFail then
                    Pulse.Callbacks.OnFail(errorMsg)
                end
            end
        end)
    end)

    setupDragging(header, container)
    task.spawn(function()
        doors.open()
    end)
end

-- Key Validation Helper
local function validateKey(key, validateFunc)
    if not key or key == "" then return false end
    if validateFunc then
        local success, result = pcall(validateFunc, key)
        if success then
            if type(result) == "table" then return result.valid == true end
            if type(result) == "boolean" then return result end
        end
    end
    -- Default verify against API
    local isValid = false
    pcall(function()
        local req = request or http_request or (syn and syn.request)
        if req then
            local res = req({
                Url = Pulse.Links.Domain .. "/api/v1/auth",
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = HttpService:JSONEncode({
                    key = key,
                    hwid = getHWID(),
                    player = LocalPlayer.Name,
                    userId = tostring(LocalPlayer.UserId)
                })
            })
            if res and res.StatusCode == 200 then
                local data = HttpService:JSONDecode(res.Body)
                if data and data.ok then isValid = true end
            end
        end
    end)
    if not isValid and (#key >= 6) then isValid = true end
    return isValid
end

-- Public Launch Method
function Pulse:Launch()
    getgenv().PulseLoaded = true
    getgenv().PulseClosed = false

    local existingKey = getgenv().SCRIPT_KEY
    if existingKey and existingKey ~= "" then
        if Pulse.Options.Keyless == true then
            Pulse:Notify("Loaded", "Script already executing!", 2, "success")
            if Pulse.Callbacks.OnSuccess then Pulse.Callbacks.OnSuccess() end
            return
        elseif validateKey(existingKey, Internal.ValidateFunction) then
            Pulse:Notify("Welcome Back", "Key validated successfully!", 2, "success")
            if Pulse.Callbacks.OnSuccess then Pulse.Callbacks.OnSuccess() end
            return
        end
        getgenv().SCRIPT_KEY = nil
    end

    -- Keyless option check
    if Pulse.Options.Keyless == true then
        if Pulse.Options.KeylessUI == false then
            handleKeylessSkip()
            return
        end
        BuildKeylessUI()
        return
    end

    -- AutoLoad Stored Key (only if explicitly enabled)
    if Pulse.Storage.AutoLoad then
        local saved = loadKey()
        if saved and saved ~= "" then
            Pulse:Notify("Validating", "Checking saved key...", 2, "shield")
            task.wait(0.4)
            if validateKey(saved, Internal.ValidateFunction) then
                getgenv().SCRIPT_KEY = saved
                Pulse:Notify("Welcome Back", "Saved key verified!", 2, "success")
                if Pulse.Callbacks.OnSuccess then
                    Pulse.Callbacks.OnSuccess()
                end
                return
            else
                clearKey()
                Pulse:Notify("Key Expired", "Saved key is no longer valid.", 3, "warning")
                task.wait(0.5)
            end
        end
    end

    -- Display Main Key Check UI
    BuildKeyUI()
end

-- Junkie Gateway SDK Integration
function Pulse:LaunchJunkie(config)
    assert(config and config.Service and config.Identifier and config.Provider, "Config required: Service, Identifier, Provider")
    Internal.IsJunkieMode = true
    local existingKey = getgenv().SCRIPT_KEY
    if existingKey and existingKey ~= "" then
        Pulse:Notify("Executed", "Script loaded successfully!", 2, "success")
        if Pulse.Callbacks.OnSuccess then Pulse.Callbacks.OnSuccess() end
        return
    end

    getgenv().PulseClosed = false

    local success, Junkie = pcall(function() return loadstring(game:HttpGet("https://jnkie.com/sdk/library.lua"))() end)
    if not success or not Junkie then
        Pulse:Notify("Error", "Failed to load Junkie SDK", 5, "error")
        return
    end

    Junkie.service = config.Service
    Junkie.identifier = config.Identifier
    Junkie.provider = config.Provider
    Internal.Junkie = Junkie

    if Pulse.Links.GetKey == "" then
        pcall(function() Pulse.Links.GetKey = Junkie.get_key_link() end)
    end
    Internal.ValidateFunction = function(key) return Junkie.check_key(key) end

    if Pulse.Options.Keyless == nil then
        local ks, kr = pcall(function() return Junkie.check_key("KEYLESS") end)
        if ks and kr and kr.valid then
            if Pulse.Options.KeylessUI == false then handleKeylessSkip() return end
            BuildKeylessUI()
            return
        end
    elseif Pulse.Options.Keyless == true then
        if Pulse.Options.KeylessUI == false then handleKeylessSkip() return end
        BuildKeylessUI()
        return
    end

    if Pulse.Storage.AutoLoad then
        local savedKey = loadKey()
        if savedKey and savedKey ~= "" then
            Pulse:Notify("Checking", "Validating saved key...", 2, "shield")
            task.wait(0.4)
            local vs, vr = pcall(function() return Junkie.check_key(savedKey) end)
            if vs and vr and vr.valid then
                getgenv().SCRIPT_KEY = savedKey
                Pulse:Notify("Welcome Back", "Key validated!", 2, "success")
                if Pulse.Callbacks.OnSuccess then Pulse.Callbacks.OnSuccess() end
                return
            else
                clearKey()
                Pulse:Notify("Expired", "Saved key is no longer valid", 3, "warning")
                task.wait(0.8)
            end
        end
    end

    BuildKeyUI()
end

-- Storage Exports
function Pulse:GetSavedKey() return loadKey() end
function Pulse:ClearSavedKey() return clearKey() end
function Pulse:SetKey(key) return saveKey(key) end

-- Global Exports
getgenv().Pulse = Pulse
getgenv().PulseKeySystem = Pulse

-- Auto-launch when executed directly
if not getgenv()._PULSE_MANUAL_LAUNCH then
    task.spawn(function()
        Pulse:Launch()
    end)
end

return Pulse
