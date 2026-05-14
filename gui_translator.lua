--[[
    examples/gui_translator.lua
    Versão standalone com overlay de debug visual na tela.
    Útil para verificar quais TextLabels estão sendo encontradas.
]]

local genv = getgenv()
if genv.__TRANSLATESCRIPT_GUI_LOADED then
    print("[GUITranslator] ⚠ Já está rodando!")
    return
end
genv.__TRANSLATESCRIPT_GUI_LOADED = true

local LIB_URL = "https://raw.githubusercontent.com/NixScripts/TranslateScript/refs/heads/main/Translate"

local ok, TranslatorLib = pcall(function()
    return loadstring(game:HttpGet(LIB_URL))()
end)

if not ok or not TranslatorLib then
    genv.__TRANSLATESCRIPT_GUI_LOADED = nil
    warn("[GUITranslator] ❌ Falha ao carregar biblioteca: " .. tostring(TranslatorLib))
    return
end

local translator  = TranslatorLib.new()
local TARGET_LANG = "pt"
local DEBUG_MODE  = true  -- false para reduzir prints no console

-- ============================================================
-- OVERLAY DE DEBUG (contador no canto da tela)
-- ============================================================
local player    = game:GetService("Players").LocalPlayer
local playerGui = player:WaitForChild("PlayerGui", 10)

local screenGui = Instance.new("ScreenGui")
screenGui.Name         = "TranslatorDebugGui"
screenGui.ResetOnSpawn = false
screenGui.Parent       = playerGui

local debugLabel = Instance.new("TextLabel")
debugLabel.Size                  = UDim2.new(0, 220, 0, 40)
debugLabel.Position              = UDim2.new(0, 10, 0, 10)
debugLabel.BackgroundColor3      = Color3.fromRGB(0, 0, 0)
debugLabel.BackgroundTransparency = 0.5
debugLabel.TextColor3            = Color3.fromRGB(255, 255, 255)
debugLabel.Font                  = Enum.Font.Code
debugLabel.TextSize              = 13
debugLabel.Text                  = "🌐 Tradutor: 0 textos"
debugLabel.Parent                = screenGui

local count       = 0
local processing  = {}

-- ============================================================
-- TRADUZ UM OBJETO
-- ============================================================
local function tryTranslate(obj)
    -- IsA com pcall para não explodir em objetos destruídos
    local isText = pcall(function()
        return obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")
    end)
    if not isText then return end
    if not (obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")) then return end
    if processing[obj] then return end
    if not obj.Parent then return end

    local original = obj.Text
    if not original or #original < 2 then return end

    processing[obj] = true

    local success, result = pcall(function()
        return translator:translate(original, TARGET_LANG)
    end)

    if success and result and result ~= original then
        if obj.Parent and obj.Text == original then
            obj.Text = result
            count += 1
            debugLabel.Text = string.format("🌐 Tradutor: %d textos", count)
            if DEBUG_MODE then
                print(string.format("[GUITranslator] '%s' → '%s'",
                    original:sub(1, 40), result:sub(1, 40)))
            end
        end
    end

    processing[obj] = nil
end

-- ============================================================
-- SCAN — usa task.spawn para não travar a thread principal
-- ============================================================
local function scanContainer(container)
    local ok, descendants = pcall(function()
        return container:GetDescendants()
    end)
    if not ok then return end

    for _, desc in ipairs(descendants) do
        task.spawn(tryTranslate, desc)
    end
end

-- ============================================================
-- INICIA
-- ============================================================
if playerGui then
    scanContainer(playerGui)

    playerGui.DescendantAdded:Connect(function(desc)
        task.delay(0.8, function()  -- debounce para typewriter
            task.spawn(tryTranslate, desc)
        end)
    end)
end

print("[GUITranslator] ✅ Rodando! Debug visual no canto superior esquerdo.")
print("[GUITranslator] 💡 Mude DEBUG_MODE = false para reduzir prints.")
