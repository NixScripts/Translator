--[[
    examples/gui_translator.lua
    Versão standalone com overlay de debug visual — v1.4.1
]]

local genv = (type(getgenv) == "function" and getgenv()) or _G
if genv.__TRANSLATESCRIPT_GUI_LOADED then
    print("[GUITranslator] ⚠ Já está rodando!")
    return
end
genv.__TRANSLATESCRIPT_GUI_LOADED = true

local LIB_URLS = {
    "https://raw.githubusercontent.com/NixScripts/Translator/refs/heads/main/Translate.lua",
}

local TranslatorLib
for _, url in ipairs(LIB_URLS) do
    local ok, raw = pcall(function() return game:HttpGet(url) end)
    if ok and raw and #raw > 0 then
        local chunk, err = loadstring(raw)
        if chunk then
            local ok2, result = pcall(chunk)
            if ok2 and result then TranslatorLib = result break end
        else
            warn("[GUITranslator] ⚠ Compile error: " .. tostring(err))
        end
    end
end

if not TranslatorLib then
    genv.__TRANSLATESCRIPT_GUI_LOADED = nil
    warn("[GUITranslator] ❌ Falha ao carregar biblioteca.")
    return
end

local translator  = TranslatorLib.new()
local TARGET_LANG = "pt"
local DEBUG_MODE  = true  -- false para reduzir prints

-- ============================================================
-- OVERLAY DE DEBUG
-- ============================================================
local player    = game:GetService("Players").LocalPlayer
local playerGui = player:FindFirstChild("PlayerGui")
                  or player:WaitForChild("PlayerGui", 10)

if not playerGui then
    genv.__TRANSLATESCRIPT_GUI_LOADED = nil
    warn("[GUITranslator] ❌ PlayerGui não encontrado.")
    return
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name         = "TranslatorDebugGui"
screenGui.ResetOnSpawn = false
screenGui.Parent       = playerGui

local debugLabel = Instance.new("TextLabel")
debugLabel.Size                   = UDim2.new(0, 260, 0, 44)
debugLabel.Position               = UDim2.new(0, 10, 0, 10)
debugLabel.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
debugLabel.BackgroundTransparency = 0.45
debugLabel.TextColor3             = Color3.fromRGB(255, 255, 255)
debugLabel.Font                   = Enum.Font.Code
debugLabel.TextSize               = 13
debugLabel.Text                   = "🌐 Tradutor: 0 traduzidos | 0 pulados"
debugLabel.Parent                 = screenGui

local stats = { translated = 0, skipped = 0, failed = 0 }
local processing = {}

local function updateLabel()
    debugLabel.Text = string.format(
        "🌐 %d traduzidos | %d pulados | %d falhas",
        stats.translated, stats.skipped, stats.failed
    )
end

-- ============================================================
-- TRADUZ UM OBJETO — usa translateVerbose para stats precisos
-- ============================================================
local function tryTranslate(obj)
    local ok, isText = pcall(function()
        return obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")
    end)
    if not ok or not isText then return end
    if processing[obj] then return end
    if not obj.Parent then return end

    local original = obj.Text
    if not original or #original < 2 then return end

    processing[obj] = true

    local success, result, reason = pcall(function()
        return translator:translateVerbose(original, TARGET_LANG)
    end)

    if not success then
        stats.failed = stats.failed + 1
        updateLabel()
        processing[obj] = nil
        return
    end

    if reason == "api" or reason == "api_fb" or reason == "cache" or reason == "custom" then
        if obj.Parent and obj.Text == original then
            obj.Text = result
            stats.translated = stats.translated + 1
            updateLabel()
            if DEBUG_MODE then
                print(string.format("[GUITranslator] (%s) '%s' → '%s'",
                    reason, original:sub(1,40), result:sub(1,40)))
            end
        end
    elseif reason == "api_failed" then
        stats.failed = stats.failed + 1
        updateLabel()
        if DEBUG_MODE then
            warn(string.format("[GUITranslator] ❌ api_failed: '%s'", original:sub(1,40)))
        end
    else
        -- skip_short, skip_num, skip_word, skip_noltr, same
        stats.skipped = stats.skipped + 1
        updateLabel()
    end

    processing[obj] = nil
end

-- ============================================================
-- SCAN
-- ============================================================
local function scanContainer(container)
    local ok, descendants = pcall(function() return container:GetDescendants() end)
    if not ok then return end
    for _, desc in ipairs(descendants) do
        task.spawn(tryTranslate, desc)
    end
end

-- ============================================================
-- INICIA
-- ============================================================
scanContainer(playerGui)

playerGui.DescendantAdded:Connect(function(desc)
    task.delay(0.8, function()
        task.spawn(tryTranslate, desc)
    end)
end)

print("[GUITranslator] ✅ v1.4.1 rodando! Debug visual no canto superior esquerdo.")
print("[GUITranslator] 💡 DEBUG_MODE = false para reduzir prints.")
