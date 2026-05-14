--[[
    TranslateScript — Loader para Executor
    Cole este script no seu executor (Xeno, Synapse X, KRNL, etc.)
    e execute. Ele baixa a biblioteca do GitHub e ativa a tradução automática.

    Atalhos enquanto o jogo roda:
        F1  → Ligar / Desligar tradução + Rescan completo
        F2  → Limpar cache + Re-traduzir tudo
        F3  → Ver estatísticas no console
]]

-- ============================================================
-- 1. CARREGA A BIBLIOTECA DO GITHUB
-- ============================================================
local LIB_URL = "https://raw.githubusercontent.com/NixScripts/TranslateScript/refs/heads/main/Translate"

local ok, TranslatorLib = pcall(function()
    return loadstring(game:HttpGet(LIB_URL))()
end)

if not ok or not TranslatorLib then
    warn("[TranslateScript] ❌ Falha ao carregar biblioteca: " .. tostring(TranslatorLib))
    warn("[TranslateScript] Verifique se o executor tem acesso a game:HttpGet()")
    return
end

print("[TranslateScript] ✅ Biblioteca carregada!")

-- ============================================================
-- 2. INSTÂNCIA DO TRADUTOR
-- ============================================================
local translator = TranslatorLib.new()
local TARGET_LANG = "pt"   -- Idioma alvo (pt = Português)
local SOURCE_LANG = "auto" -- Detecta automaticamente

-- ============================================================
-- 3. ESTATÍSTICAS
-- ============================================================
local Stats = {
    translated    = 0,
    skipped       = 0,
    failed        = 0,
    apiHits       = 0,
    cacheHits     = 0,
    startTime     = tick(),
}

-- ============================================================
-- 4. CONTROLES
-- ============================================================
local isEnabled      = true
local processingSet  = {} -- guarda TextObjects em processamento (evita loop)
local pendingQueue   = {} -- fila de objetos esperando debounce
local DEBOUNCE_TIME  = 0.8  -- segundos de espera após última mudança (typewriter)
local RATE_DELAY     = 0.2  -- segundos entre requisições à API

-- ============================================================
-- 5. FUNÇÃO CENTRAL: traduz um TextObject
-- ============================================================
local function translateObject(obj)
    if processingSet[obj] then return end
    if not obj or not obj.Parent then return end

    local original = obj.Text
    if not original or original == "" then return end

    -- Marca como em processamento para evitar loop
    processingSet[obj] = true

    local cacheKey = original .. "|" .. TARGET_LANG
    local cacheSize = translator:getCacheSize()

    local result = translator:translate(original, TARGET_LANG, SOURCE_LANG)

    if result and result ~= original then
        -- Verifica se o cache cresceu (foi API, não cache)
        if translator:getCacheSize() > cacheSize then
            Stats.apiHits = Stats.apiHits + 1
        else
            Stats.cacheHits = Stats.cacheHits + 1
        end
        Stats.translated = Stats.translated + 1

        -- Aplica tradução apenas se o texto não mudou enquanto aguardávamos
        if obj.Parent and obj.Text == original then
            obj.Text = result
        end
    else
        Stats.skipped = Stats.skipped + 1
    end

    processingSet[obj] = nil
end

-- ============================================================
-- 6. DEBOUNCE: espera o typewriter terminar antes de traduzir
-- ============================================================
local function scheduleTranslation(obj)
    if not isEnabled then return end

    -- Cancela agendamento anterior deste objeto
    pendingQueue[obj] = tick()

    local scheduledAt = pendingQueue[obj]
    task.delay(DEBOUNCE_TIME, function()
        -- Só executa se não houve nova mudança depois
        if pendingQueue[obj] == scheduledAt then
            pendingQueue[obj] = nil
            translateObject(obj)
            task.wait(RATE_DELAY)
        end
    end)
end

-- ============================================================
-- 7. MONITORA UM OBJETO DE TEXTO
-- ============================================================
local connections = {}
local function watchObject(obj)
    if not obj:IsA("TextLabel")
        and not obj:IsA("TextButton")
        and not obj:IsA("TextBox") then
        return
    end

    -- Traduz texto atual imediatamente
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
-- 8. SCAN COMPLETO DA GUI
-- ============================================================
local function scanGui(root)
    local ok, err = pcall(function()
        local descendants = root:GetDescendants()
        for _, child in ipairs(descendants) do
            pcall(watchObject, child)
        end
    end)
    if not ok then
        warn("[TranslateScript] scanGui error: " .. tostring(err))
    end
end

local function fullScan()
    print("[TranslateScript] 🔍 Iniciando scan completo da GUI...")
    Stats.startTime = tick()

    -- PlayerGui (GUI do jogador)
    local ok1, playerGui = pcall(function()
        return game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui", 5)
    end)
    if ok1 and playerGui then
        scanGui(playerGui)

        -- Monitora novos elementos adicionados
        local conn = playerGui.DescendantAdded:Connect(function(desc)
            if isEnabled then
                task.spawn(watchObject, desc)
            end
        end)
        table.insert(connections, conn)
    end

    -- CoreGui (tentativa — pode falhar por permissões)
    pcall(function()
        scanGui(game:GetService("CoreGui"))
    end)

    print(string.format("[TranslateScript] ✅ Scan concluído! Cache: %d entradas",
        translator:getCacheSize()))
end

-- ============================================================
-- 9. LIMPA TUDO
-- ============================================================
local function clearAll()
    for _, conn in ipairs(connections) do
        pcall(function() conn:Disconnect() end)
    end
    connections  = {}
    pendingQueue = {}
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
-- 10. ATALHOS DE TECLADO
-- ============================================================
local UIS = game:GetService("UserInputService")
UIS.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    if input.KeyCode == Enum.KeyCode.F1 then
        isEnabled = not isEnabled
        if isEnabled then
            print("[TranslateScript] ▶ Tradução ATIVADA — Fazendo rescan...")
            fullScan()
        else
            print("[TranslateScript] ⏸ Tradução DESATIVADA")
        end

    elseif input.KeyCode == Enum.KeyCode.F2 then
        print("[TranslateScript] 🔄 Limpando cache e re-traduzindo tudo...")
        clearAll()
        isEnabled = true
        fullScan()

    elseif input.KeyCode == Enum.KeyCode.F3 then
        local elapsed = math.floor(tick() - Stats.startTime)
        print(string.format(
            "[TranslateScript] 📊 Estatísticas:\n"..
            "  ✅ Traduzidos : %d\n"..
            "  ⏭ Pulados    : %d\n"..
            "  ❌ Falhas     : %d\n"..
            "  📡 API hits   : %d\n"..
            "  💾 Cache hits : %d\n"..
            "  🕒 Rodando há : %ds\n"..
            "  📦 Cache size : %d",
            Stats.translated, Stats.skipped, Stats.failed,
            Stats.apiHits, Stats.cacheHits, elapsed,
            translator:getCacheSize()
        ))
    end
end)

-- ============================================================
-- 11. INICIA
-- ============================================================
print("[TranslateScript] 🚀 Iniciando tradutor universal...")
print(string.format("[TranslateScript] 🌐 Idioma alvo: %s | Debounce: %.1fs | Rate: %.0fms",
    TARGET_LANG, DEBOUNCE_TIME, RATE_DELAY * 1000))
print("[TranslateScript] Atalhos: F1 = Liga/Desliga | F2 = Rescan | F3 = Stats")

fullScan()

-- Exporta para _G (uso externo)
_G.TranslatorLib = TranslatorLib
_G.translator    = translator
