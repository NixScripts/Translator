--[[
    TranslateScript — Loader para Executor
    v1.4.0 — by NixScripts

    Cole este script no seu executor (Xeno, Wave, Solara, etc.) e execute.

    Atalhos:
        F1  → Liga / Desliga + Rescan completo
        F2  → Limpa cache + Re-traduz tudo
        F3  → Estatísticas detalhadas
        F4  → Log de erros (últimos 20)
]]

-- ============================================================
-- PROTEÇÃO CONTRA DUPLA EXECUÇÃO
-- ============================================================
local genv = (type(getgenv) == "function" and getgenv()) or _G
if genv.__TRANSLATESCRIPT_LOADED then
    print("[TranslateScript] ⚠ Já está rodando! Use F2 para resetar.")
    return
end
genv.__TRANSLATESCRIPT_LOADED = true

-- ============================================================
-- CARREGA A BIBLIOTECA DO GITHUB
-- ============================================================
local LIB_URLS = {
    "https://raw.githubusercontent.com/NixScripts/Translator/refs/heads/main/Translate.lua",
}

local TranslatorLib
for _, url in ipairs(LIB_URLS) do
    local ok, raw = pcall(function()
        return game:HttpGet(url)
    end)
    if ok and raw and #raw > 0 then
        local chunk, compileErr = loadstring(raw)
        if chunk then
            local ok2, result = pcall(chunk)
            if ok2 and result then
                TranslatorLib = result
                print("[TranslateScript] ✅ Biblioteca carregada de: " .. url)
                break
            else
                warn("[TranslateScript] ⚠ Erro ao executar chunk: " .. tostring(result))
            end
        else
            warn("[TranslateScript] ⚠ Erro de compilação: " .. tostring(compileErr))
        end
    else
        warn("[TranslateScript] ⚠ Falha ao baixar: " .. url)
    end
end

if not TranslatorLib then
    genv.__TRANSLATESCRIPT_LOADED = nil
    warn("[TranslateScript] ❌ Não foi possível carregar a biblioteca.")
    return
end

-- ============================================================
-- CONFIGURAÇÃO
-- ============================================================
local TARGET_LANG   = "pt"
local SOURCE_LANG   = "auto"
local DEBOUNCE_TIME = 0.8   -- segundos aguardando typewriter
local RATE_DELAY    = 0.2   -- intervalo entre requisições (segundos)
local DEBUG_SKIP    = false -- true = loga no console cada texto pulado com motivo

-- ============================================================
-- INSTÂNCIA
-- ============================================================
local translator = TranslatorLib.new()

-- ============================================================
-- ESTATÍSTICAS DETALHADAS
-- ============================================================
local Stats = {
    translated      = 0,  -- traduzidos com sucesso
    skipIntentional = 0,  -- pulados pelo shouldSkip (números, SKIP_WORDS, etc.)
    skipSameText    = 0,  -- API retornou o mesmo texto (já era no idioma alvo, ou falha silenciosa)
    failed          = 0,  -- pcall explodiu com erro
    apiHits         = 0,  -- requisições que foram à API
    cacheHits       = 0,  -- servidos do cache
    startTime       = tick(),
}

-- ============================================================
-- LOG DE ERROS (máx. 20 entradas, circular)
-- ============================================================
local ErrorLog    = {}
local MAX_ERRORS  = 20

local function logError(category, text, detail)
    if #ErrorLog >= MAX_ERRORS then
        table.remove(ErrorLog, 1)
    end
    table.insert(ErrorLog, {
        time     = os.date("%H:%M:%S"),
        category = category,
        text     = tostring(text):sub(1, 60),
        detail   = tostring(detail):sub(1, 80),
    })
end

-- ============================================================
-- CONTROLES
-- ============================================================
local isEnabled     = true
local processingSet = {}
local pendingQueue  = {}

-- ============================================================
-- TRADUZ UM OBJETO DE TEXTO
-- ============================================================
local function translateObject(obj)
    if processingSet[obj] then return end

    -- obj pode ter sido destruído entre o agendamento e a execução
    local ok0, stillValid = pcall(function()
        return obj and obj.Parent ~= nil
    end)
    if not ok0 or not stillValid then return end

    local original = obj.Text
    if not original or original == "" then return end

    processingSet[obj] = true

    local success, result, reason = pcall(function()
        return translator:translateVerbose(original, TARGET_LANG, SOURCE_LANG)
    end)

    if not success then
        Stats.failed = Stats.failed + 1
        logError("RUNTIME ERROR", original, tostring(result))
        processingSet[obj] = nil
        return
    end

    -- Contabiliza pelo motivo exato retornado pela lib
    if reason == "api" or reason == "api_fb" then
        Stats.apiHits   = Stats.apiHits + 1
        Stats.translated = Stats.translated + 1
        if obj.Parent and obj.Text == original then obj.Text = result end

    elseif reason == "cache" then
        Stats.cacheHits  = Stats.cacheHits + 1
        Stats.translated = Stats.translated + 1
        if obj.Parent and obj.Text == original then obj.Text = result end

    elseif reason == "custom" then
        Stats.translated = Stats.translated + 1
        if obj.Parent and obj.Text == original then obj.Text = result end

    elseif reason == "skip_short" or reason == "skip_num"
        or reason == "skip_word" or reason == "skip_noltr" then
        Stats.skipIntentional = Stats.skipIntentional + 1
        if DEBUG_SKIP then
            print(string.format("[TranslateScript] ⏭ %s: '%s'", reason, original:sub(1,50)))
        end

    elseif reason == "same" then
        Stats.skipSameText = Stats.skipSameText + 1
        if DEBUG_SKIP then
            print(string.format("[TranslateScript] ≈ SAME: '%s'", original:sub(1,50)))
        end

    elseif reason == "api_failed" then
        Stats.failed = Stats.failed + 1
        logError("API FAILED", original, "Google + MyMemory falharam")
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
    local ok, isText = pcall(function()
        return obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")
    end)
    if not ok or not isText then return end

    if isEnabled then
        task.spawn(translateObject, obj)
    end

    local ok2, conn = pcall(function()
        return obj:GetPropertyChangedSignal("Text"):Connect(function()
            if isEnabled and not processingSet[obj] then
                scheduleTranslation(obj)
            end
        end)
    end)

    if ok2 and conn then
        table.insert(connections, conn)
    else
        -- GetPropertyChangedSignal falhou (objeto destruído ou sem permissão)
        logError("WATCH ERROR", obj.Name or "?", tostring(conn))
    end
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
        logError("SCAN ERROR", tostring(root), tostring(err))
        warn("[TranslateScript] scanGui: " .. tostring(err))
    end
end

local function fullScan()
    print("[TranslateScript] 🔍 Scanning GUI...")
    Stats.startTime = tick()

    local playerGui = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
    if playerGui then
        scanGui(playerGui)
        local conn = playerGui.DescendantAdded:Connect(function(desc)
            if isEnabled then task.spawn(watchObject, desc) end
        end)
        table.insert(connections, conn)
    else
        warn("[TranslateScript] ⚠ PlayerGui não encontrado, aguardando...")
        task.spawn(function()
            local pg = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui", 10)
            if pg then
                scanGui(pg)
                local conn = pg.DescendantAdded:Connect(function(desc)
                    if isEnabled then task.spawn(watchObject, desc) end
                end)
                table.insert(connections, conn)
            else
                logError("SCAN ERROR", "PlayerGui", "WaitForChild timeout após 10s")
            end
        end)
    end

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
    connections       = {}
    pendingQueue      = {}
    processingSet     = {}
    ErrorLog          = {}
    translator:clearCache()
    Stats.translated      = 0
    Stats.skipIntentional = 0
    Stats.skipSameText    = 0
    Stats.failed          = 0
    Stats.apiHits         = 0
    Stats.cacheHits       = 0
    Stats.startTime       = tick()
end

-- ============================================================
-- ATALHOS DE TECLADO
-- ============================================================
local UIS = game:GetService("UserInputService")
UIS.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    -- F1: liga/desliga
    if input.KeyCode == Enum.KeyCode.F1 then
        isEnabled = not isEnabled
        if isEnabled then
            print("[TranslateScript] ▶ ATIVADO — rescanning...")
            fullScan()
        else
            print("[TranslateScript] ⏸ DESATIVADO")
        end

    -- F2: reset total
    elseif input.KeyCode == Enum.KeyCode.F2 then
        print("[TranslateScript] 🔄 Resetando e re-traduzindo...")
        resetAll()
        isEnabled = true
        fullScan()

    -- F3: estatísticas detalhadas
    elseif input.KeyCode == Enum.KeyCode.F3 then
        local totalSkipped = Stats.skipIntentional + Stats.skipSameText
        local total = Stats.translated + totalSkipped + Stats.failed
        local pct = total > 0 and math.floor(Stats.translated / total * 100) or 0
        print(string.format(
            "[TranslateScript] 📊 Stats (v1.4.0):\n"..
            "  ✅ Traduzidos       : %d (%d%%)\n"..
            "  ⏭  Skip intencional : %d  (números, SKIP_WORDS, <2 chars)\n"..
            "  ≈  Skip mesmo texto : %d  (já no idioma alvo ou API sem retorno)\n"..
            "  ❌ Falhas (runtime) : %d\n"..
            "  📡 API hits         : %d\n"..
            "  💾 Cache hits       : %d\n"..
            "  🕒 Uptime           : %ds\n"..
            "  📦 Cache size       : %d\n"..
            "  🐛 Erros no log     : %d  (F4 para ver)",
            Stats.translated, pct,
            Stats.skipIntentional,
            Stats.skipSameText,
            Stats.failed,
            Stats.apiHits,
            Stats.cacheHits,
            math.floor(tick() - Stats.startTime),
            translator:getCacheSize(),
            #ErrorLog
        ))

    -- F4: log de erros
    elseif input.KeyCode == Enum.KeyCode.F4 then
        if #ErrorLog == 0 then
            print("[TranslateScript] 📋 Nenhum erro registrado.")
        else
            print(string.format("[TranslateScript] 📋 Log de erros (%d/%d):", #ErrorLog, MAX_ERRORS))
            for i, entry in ipairs(ErrorLog) do
                print(string.format(
                    "  [%s] #%d %s | texto: '%s' | detalhe: %s",
                    entry.time, i, entry.category, entry.text, entry.detail
                ))
            end
        end
    end
end)

-- ============================================================
-- INICIA
-- ============================================================
print("[TranslateScript] 🚀 TranslateScript v1.4.0 iniciando...")
print(string.format("[TranslateScript] 🌐 Lang: %s | Debounce: %.1fs | Rate: %.0fms",
    TARGET_LANG, DEBOUNCE_TIME, RATE_DELAY * 1000))
print("[TranslateScript] F1=Liga/Desliga | F2=Reset | F3=Stats | F4=Erros")

fullScan()

genv.TranslatorLib = TranslatorLib
genv.translator    = translator
