--[[
    examples/gui_translator.lua
    Integração de tradução com GUI — versão standalone com debug visual.
    Útil para debugar quais TextLabels estão sendo encontradas no jogo.
]]

local LIB_URL = "https://raw.githubusercontent.com/NixScripts/TranslateScript/refs/heads/main/Translate.lua"

local ok, TranslatorLib = pcall(function()
    return loadstring(game:HttpGet(LIB_URL))()
end)

if not ok then
    warn("[GUITranslator] ❌ " .. tostring(TranslatorLib))
    return
end

local translator = TranslatorLib.new()
local TARGET_LANG = "pt"
local DEBUG_MODE  = true  -- false para desligar prints de tradução individual

-- Cria uma ScreenGui com contador no canto da tela (debug visual)
local Players = game:GetService("Players")
local player  = Players.LocalPlayer

local screenGui = Instance.new("ScreenGui")
screenGui.Name  = "TranslatorDebugGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local debugLabel = Instance.new("TextLabel")
debugLabel.Size       = UDim2.new(0, 220, 0, 40)
debugLabel.Position   = UDim2.new(0, 10, 0, 10)
debugLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
debugLabel.BackgroundTransparency = 0.5
debugLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
debugLabel.Font       = Enum.Font.Code
debugLabel.TextSize   = 13
debugLabel.Text       = "🌐 Tradutor: 0 textos"
debugLabel.Parent     = screenGui

local count = 0

local function tryTranslate(obj)
    if not obj or not obj.Parent then return end
    if not obj:IsA("TextLabel") and not obj:IsA("TextButton") and not obj:IsA("TextBox") then return end

    local original = obj.Text
    if not original or #original < 2 then return end

    local result = translator:translate(original, TARGET_LANG)
    if result and result ~= original then
        obj.Text = result
        count += 1
        debugLabel.Text = string.format("🌐 Tradutor: %d textos", count)
        if DEBUG_MODE then
            print(string.format("[GUI] '%s' → '%s'", original:sub(1, 40), result:sub(1, 40)))
        end
    end
end

-- Scan de um container
local function scanContainer(container)
    for _, desc in ipairs(container:GetDescendants()) do
        task.spawn(tryTranslate, desc)
        task.wait(0.05) -- pequeno delay para não travar
    end
end

-- Começa pelo PlayerGui
local playerGui = player:WaitForChild("PlayerGui", 10)
if playerGui then
    scanContainer(playerGui)

    playerGui.DescendantAdded:Connect(function(desc)
        task.wait(1) -- aguarda o texto estabilizar
        task.spawn(tryTranslate, desc)
    end)
end

print("[GUITranslator] ✅ Rodando! Debug visual no canto superior esquerdo.")
print("[GUITranslator] 💡 Defina DEBUG_MODE = false para reduzir prints.")
