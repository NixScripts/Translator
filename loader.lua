--[[
    TranslateScript — Loader para Executor
    v1.2.0 — by NixScripts

    Cole este script no seu executor (Xeno, Wave, Solara, etc.) e execute.
    Baixa a biblioteca do GitHub e ativa a tradução automática no jogo.

    Atalhos:
        F1  → Liga / Desliga + Rescan completo
        F2  → Limpa cache + Re-traduz tudo
        F3  → Ver estatísticas no console
]]

-- ============================================================
-- PROTEÇÃO CONTRA DUPLA EXECUÇÃO
-- getgenv() é o padrão UNC — fallback para _G se não existir
-- ============================================================
local genv = (type(getgenv) == "function" and getgenv()) or _G
if genv.__TRANSLATESCRIPT_LOADED then
    print("[TranslateScript] ⚠ Já está rodando! Use F2 para resetar.")
    return
end
genv.__TRANSLATESCRIPT_LOADED = true

-- ============================================================
-- CARREGA A BIBLIOTECA DO GITHUB
-- Padrão de executor: loadstring(game:HttpGet("url"))()
-- ============================================================
local LIB_URL = "https://raw.githubusercontent.com/NixScripts/TranslateScript/refs/heads/main/Translate"

local ok, TranslatorLib = pcall(function()
    return loadstring(game:HttpGet(LIB_URL))()
end)

if not ok or not TranslatorLib then
    genv.__TRANSLATESCRIPT_LOADED = nil
    warn("[TranslateScript] ❌ Falha ao carregar biblioteca: " .. tostring(TranslatorLib))
    return
end

print("[TranslateScript] ✅ Biblioteca carregada!")

-- ============================================================
-- INSTÂNCIA E CONFIGURAÇÃO
-- ============================================================
local translator  = TranslatorLib.new()
local TARGET_LANG = "pt"    -- idioma alvo
local SOURCE_LANG = "auto"  -- detecta automaticamente

-- ============================================================
-- ESTATÍSTICAS
-- ============================================================
local Stats = {
    translated = 0,
    skipped    = 0,
    failed     = 0,
    apiHits    = 0,
    cacheHits  = 0,
    startTime  = tick(),
}

-- ============================================================
-- CONTROLES
-- ============================================================
local isEnabled     = true
local processingSet = {}   -- evita loop ao modificar .Text
local pendingQueue  = {}   -- debounce por objeto
local DEBOUNCE_TIME = 0.8  -- aguarda typewriter terminar (segundos)
local RATE_DELAY    = 0.2  -- intervalo entre requisições à API

-- ============================================================
-- TRADUZ UM OBJETO DE TEXTO
-- ============================================================
local function translateObject(obj)
    if processingSet[obj] then return end
    if not obj or not obj.Parent then return end

    local original = obj.Text
    if not original or original == "" then return end

    processingSet[obj] = true

    local cacheBefore = translator:getCacheSize()
    local success, result = pcall(function()
        return translator:translate(original, TARGET_LANG, SOURCE_LANG)
    end)

    if not success then
        Stats.failed = Stats.failed + 1
        processingSet[obj] = nil
        return
    end

    if result and result ~= original then
        if translator:getCacheSize() > cacheBefore then
            Stats.apiHits   = Stats.apiHits + 1
        else
            Stats.cacheHits = Stats.cacheHits + 1
        end
        Stats.translated = Stats.translated + 1

        -- Aplica só se o texto não mudou enquanto esperávamos
        if obj.Parent and obj.Text == original then
            obj.Text = result
        end
    else
        Stats.skipped = Stats.skipped + 1
    end

    processingSet[obj] = nil
end

-- ============================================================
-- DEBOUNCE — aguarda typewriter effect terminar
-- ============================================================
local function scheduleTranslation(obj)
    if not isEnabled then return end
    pendingQueue[obj] = tick()
    local scheduledAt = pendingQueue[obj]
    task.delay(DEBOUNCE_TIME, function()
        if pendingQueue[obj] == scheduledAt then
            pendingQueue[obj] = nil
            translateObject(obj)
            task.wait(RATE_DELAY)
        end
    end)
end

-- ============================================================
-- MONITORA UM OBJETO DE TEXTO
-- ============================================================
local connections = {}
local function watchObject(obj)
    if not pcall(function()
        return obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")
    end) then return end

    if not (obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")) then
        return
    end

    -- Traduz o texto atual
    if isEnabled then
        task.spawn(translateObject, obj)
    end

    -- Monitora mudanças futuras com debounce
    local conn = obj:GetPropertyChangedSignal("Text"):Connect(function()
        if isEnabled and not processingSet[obj] then
            scheduleTranslation(obj)
        end
    end)
    table.insert(connections, conn)
end

-- ============================================================
-- SCAN COMPLETO DA GUI
-- ============================================================
local function scanGui(root)
    local ok, err = pcall(function()
        for _, desc in ipairs(root:GetDescendants()) do
            pcall(watchObject, desc)
        end
    end)
    if not ok then
        warn("[TranslateScript] scanGui: " .. tostring(err))
    end
end

local function fullScan()
    print("[TranslateScript] 🔍 Scanning GUI...")
    Stats.startTime = tick()

    -- PlayerGui
    local ok1, playerGui = pcall(function()
        return game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui", 5)
    end)
    if ok1 and playerGui then
        scanGui(playerGui)
        local conn = playerGui.DescendantAdded:Connect(function(desc)
            if isEnabled then task.spawn(watchObject, desc) end
        end)
        table.insert(connections, conn)
    end

    -- CoreGui (pode falhar em alguns jogos — silencioso)
    pcall(function() scanGui(game:GetService("CoreGui")) end)

    print(string.format("[TranslateScript] ✅ Scan concluído! Cache: %d entradas",
        translator:getCacheSize()))
end

-- ============================================================
-- RESET TOTAL
-- ============================================================
local function resetAll()
    for _, conn in ipairs(connections) do
        pcall(function() conn:Disconnect() end)
    end
    connections   = {}
    pendingQueue  = {}
    processingSet = {}
    translator:clearCache()
    Stats.translated = 0
    Stats.skipped    = 0
    Stats.failed     = 0
    Stats.apiHits    = 0
    Stats.cacheHits  = 0
    Stats.startTime  = tick()
end

-- ============================================================
-- ATALHOS DE TECLADO
-- ============================================================
local UIS = game:GetService("UserInputService")
UIS.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    if input.KeyCode == Enum.KeyCode.F1 then
        isEnabled = not isEnabled
        if isEnabled then
            print("[TranslateScript] ▶ ATIVADO — rescanning...")
            fullScan()
        else
            print("[TranslateScript] ⏸ DESATIVADO")
        end

    elseif input.KeyCode == Enum.KeyCode.F2 then
        print("[TranslateScript] 🔄 Resetando e re-traduzindo...")
        resetAll()
        isEnabled = true
        fullScan()

    elseif input.KeyCode == Enum.KeyCode.F3 then
        print(string.format(
            "[TranslateScript] 📊 Stats:\n"..
            "  ✅ Traduzidos : %d\n"..
            "  ⏭  Pulados    : %d\n"..
            "  ❌ Falhas     : %d\n"..
            "  📡 API hits   : %d\n"..
            "  💾 Cache hits : %d\n"..
            "  🕒 Uptime     : %ds\n"..
            "  📦 Cache size : %d",
            Stats.translated, Stats.skipped, Stats.failed,
            Stats.apiHits, Stats.cacheHits,
            math.floor(tick() - Stats.startTime),
            translator:getCacheSize()
        ))
    end
end)

-- ============================================================
-- INICIA
-- ============================================================
print("[TranslateScript] 🚀 TranslateScript v1.2.0 iniciando...")
print(string.format("[TranslateScript] 🌐 Lang: %s | Debounce: %.1fs | Rate: %.0fms",
    TARGET_LANG, DEBOUNCE_TIME, RATE_DELAY * 1000))
print("[TranslateScript] F1 = Liga/Desliga | F2 = Reset | F3 = Stats")

fullScan()

-- Exporta via genv (getgenv() se disponível, _G caso contrário)
genv.TranslatorLib = TranslatorLib
genv.translator    = translator
