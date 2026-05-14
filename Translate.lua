--[[
    Universal Luau Translator Library
    v1.0.0 — by NixScripts

    Compatível com: HttpService, syn.request, http_request, request (executores)
    Uso via loadstring:
        local Translator = loadstring(game:HttpGet("https://raw.githubusercontent.com/NixScripts/TranslateScript/refs/heads/main/Translate.lua"))()
        local t = Translator.new()
        print(t:translate("Hello World", "pt"))

    Métodos disponíveis:
        Translator.new()                        → Cria nova instância
        translator:translate(text, targetLang)  → Traduz texto
        translator:clearCache()                 → Limpa o cache
        translator:getCacheSize()               → Retorna entradas no cache
        translator:setApiUrl(url)               → Altera URL da API principal
        translator:setRequestFunction(fn)       → Define função HTTP customizada
]]

local Translator = {}
Translator.__index = Translator

-- ============================================================
-- PALAVRAS QUE SÃO IGUAIS EM INGLÊS E PORTUGUÊS (não traduzir)
-- ============================================================
local SKIP_WORDS = {
    -- Teclas / Input
    ["shift"] = true, ["ctrl"] = true, ["alt"] = true, ["tab"] = true,
    ["esc"] = true, ["enter"] = true, ["delete"] = true, ["backspace"] = true,
    ["space"] = true, ["capslock"] = true, ["numlock"] = true,
    -- Teclas de letra comuns em jogos
    ["e"] = true, ["q"] = true, ["w"] = true, ["r"] = true,
    ["f"] = true, ["g"] = true, ["v"] = true, ["c"] = true,
    -- Termos de jogos iguais nos dois idiomas
    ["ui"] = true, ["npc"] = true, ["hp"] = true, ["mp"] = true,
    ["xp"] = true, ["pvp"] = true, ["pve"] = true, ["id"] = true,
    ["fps"] = true, ["dps"] = true, ["aoe"] = true, ["dot"] = true,
    ["buff"] = true, ["debuff"] = true, ["boss"] = true, ["mob"] = true,
    ["skill"] = true, ["level"] = true, ["loot"] = true, ["grind"] = true,
    ["spawn"] = true, ["map"] = true, ["slot"] = true, ["cd"] = true,
    -- Termos técnicos
    ["api"] = true, ["url"] = true, ["html"] = true, ["json"] = true,
    ["ok"] = true, ["status"] = true, ["error"] = true, ["debug"] = true,
    -- Números e símbolos (não tentar traduzir)
    ["%d+"] = true,
}

-- ============================================================
-- ABSTRAÇÃO DE REQUISIÇÃO HTTP
-- Detecta o ambiente automaticamente (executor ou Roblox padrão)
-- Usa rawget(_G, ...) para não explodir se a global não existir
-- ============================================================
local function getRequestFunc()
    -- Verifica cada global com rawget para não dar erro
    local r = rawget(_G, "request")
    if type(r) == "function" then return r end

    local hr = rawget(_G, "http_request")
    if type(hr) == "function" then return hr end

    local syn = rawget(_G, "syn")
    if type(syn) == "table" and type(syn.request) == "function" then
        return syn.request
    end

    local fluxus = rawget(_G, "fluxus")
    if type(fluxus) == "table" and type(fluxus.request) == "function" then
        return fluxus.request
    end

    local http = rawget(_G, "http")
    if type(http) == "table" and type(http.request) == "function" then
        return http.request
    end

    return nil
end

local function universalRequest(options)
    local requestFunc = getRequestFunc()

    if requestFunc then
        local ok, response = pcall(requestFunc, {
            Url     = options.Url,
            Method  = options.Method or "GET",
            Headers = options.Headers or { ["Content-Type"] = "application/json" },
            Body    = options.Body,
        })
        if ok and response then
            return response.Body or response.body or ""
        end
        return nil
    end

    -- Fallback: game:HttpGet() (funciona em muitos executores mesmo sem request)
    if options.Method ~= "POST" then
        local ok, result = pcall(function()
            return game:HttpGet(options.Url, true)
        end)
        if ok and result then return result end
    end

    -- Último fallback: HttpService do Roblox (Studio / servidor)
    local ok, HttpService = pcall(function()
        return game:GetService("HttpService")
    end)
    if not ok then return nil end

    if options.Method == "POST" then
        local success, result = pcall(function()
            return HttpService:PostAsync(options.Url, options.Body or "",
                Enum.HttpContentType.ApplicationJson)
        end)
        return success and result or nil
    else
        local success, result = pcall(function()
            return HttpService:GetAsync(options.Url)
        end)
        return success and result or nil
    end
end

-- ============================================================
-- SANITIZAÇÃO DE TEXTO
-- Remove tags de cor, fontes e entidades HTML
-- ============================================================
local function sanitizeText(text)
    if not text or text == "" then return "" end
    local clean = text

    -- Remove tags RichText do Roblox: <font color="...">, <b>, </b>, etc.
    clean = clean:gsub("<[^>]+>", "")

    -- Remove Color3 e outras tags de formatação do Roblox
    clean = clean:gsub("%[color=[^%]]+%]", "")
    clean = clean:gsub("%[/color%]", "")

    -- Converte entidades HTML comuns
    clean = clean:gsub("&nbsp;",  " ")
    clean = clean:gsub("&quot;",  '"')
    clean = clean:gsub("&#39;",   "'")
    clean = clean:gsub("&amp;",   "&")
    clean = clean:gsub("&lt;",    "<")
    clean = clean:gsub("&gt;",    ">")

    -- Remove espaços extras
    clean = clean:match("^%s*(.-)%s*$")
    return clean
end

-- ============================================================
-- VERIFICAÇÃO: precisa traduzir?
-- ============================================================
local function shouldSkip(text)
    if not text or #text < 2 then return true end
    -- Apenas números / pontuação
    if text:match("^[%d%s%p]+$") then return true end
    -- Palavra na lista de skip
    local lower = text:lower()
    if SKIP_WORDS[lower] then return true end
    -- Texto igual ao original (sem letras reais)
    if not text:match("%a") then return true end
    return false
end

-- ============================================================
-- CONSTRUTOR
-- ============================================================
function Translator.new(apiUrl)
    local self = setmetatable({}, Translator)
    self._cache       = {}
    self._cacheSize   = 0
    self._maxCache    = 1000
    self._customReqFn = nil
    self._apiUrl      = apiUrl or nil  -- nil = usa Google padrão
    return self
end

-- ============================================================
-- REQUISIÇÃO COM FALLBACK (Google → LibreTranslate → MyMemory)
-- ============================================================
function Translator:_doRequest(text, targetLang, sourceLang)
    sourceLang = sourceLang or "auto"

    -- Encoding da URL
    local function encode(str)
        local ok, hs = pcall(function() return game:GetService("HttpService") end)
        if ok and hs then
            return hs:UrlEncode(str)
        end
        -- Fallback manual
        return str:gsub("([^%w%-%.%_%~ ])", function(c)
            return string.format("%%%02X", string.byte(c))
        end):gsub(" ", "+")
    end

    local encoded = encode(text)

    -- --- API 1: Google Translate (mais rápida e ilimitada) ---
    local googleUrl = string.format(
        "https://translate.googleapis.com/translate_a/single?client=gtx&sl=%s&tl=%s&dt=t&q=%s",
        sourceLang, targetLang, encoded
    )
    local resp = universalRequest({ Url = googleUrl, Method = "GET" })
    if resp then
        -- Resposta é um JSON nested: [[[translated, original, ...], ...], ...]
        local translated = resp:match('%[%[%["(.-)"')
        if translated and translated ~= "" then
            -- Decode escapes unicode (\uXXXX) com fallback seguro
            translated = translated:gsub("\\u(%x%x%x%x)", function(h)
                local n = tonumber(h, 16)
                if n and utf8 and utf8.char then
                    local ok2, ch = pcall(utf8.char, n)
                    return ok2 and ch or ("\\u"..h)
                end
                return "\\u"..h
            end)
            return translated
        end
    end

    -- --- API 2: LibreTranslate (público) ---
    local libreUrl = string.format(
        "https://libretranslate.de/translate"
    )
    local ok2, hs = pcall(function() return game:GetService("HttpService") end)
    if ok2 and hs then
        local body = ok2 and pcall(function()
            return hs:JSONEncode({
                q      = text,
                source = sourceLang == "auto" and "en" or sourceLang,
                target = targetLang,
                format = "text",
            })
        end) or nil
        if body then
            local resp2 = universalRequest({
                Url     = libreUrl,
                Method  = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body    = body,
            })
            if resp2 then
                local tr2 = resp2:match('"translatedText":"(.-)"')
                if tr2 and tr2 ~= "" then return tr2 end
            end
        end
    end

    -- --- API 3: MyMemory (fallback final) ---
    local mmUrl = string.format(
        "https://api.mymemory.translated.net/get?q=%s&langpair=%s|%s",
        encoded, sourceLang == "auto" and "en" or sourceLang, targetLang
    )
    local resp3 = universalRequest({ Url = mmUrl, Method = "GET" })
    if resp3 then
        local tr3 = resp3:match('"translatedText":"(.-)"')
        if tr3 and tr3 ~= "" then return tr3 end
    end

    return nil -- todas as APIs falharam
end

-- ============================================================
-- MÉTODO PRINCIPAL: translate(text, targetLang, sourceLang?)
-- ============================================================
function Translator:translate(text, targetLang, sourceLang)
    targetLang = targetLang or "pt"
    sourceLang = sourceLang or "auto"

    -- Sanitiza antes de qualquer coisa
    local clean = sanitizeText(text)
    if shouldSkip(clean) then return text end

    -- Chave de cache
    local cacheKey = clean .. "|" .. targetLang
    if self._cache[cacheKey] then
        return self._cache[cacheKey]
    end

    -- Usa função customizada se definida
    local result
    if self._customReqFn then
        local ok, res = pcall(self._customReqFn, clean, targetLang, sourceLang)
        result = ok and res or nil
    else
        result = self:_doRequest(clean, targetLang, sourceLang)
    end

    if result and result ~= "" and result ~= clean then
        -- Evita encher o cache
        if self._cacheSize >= self._maxCache then
            self._cache    = {}
            self._cacheSize = 0
        end
        self._cache[cacheKey] = result
        self._cacheSize = self._cacheSize + 1
        return result
    end

    return text -- retorna original se tudo falhar
end

-- ============================================================
-- UTILITÁRIOS
-- ============================================================
function Translator:clearCache()
    self._cache     = {}
    self._cacheSize = 0
end

function Translator:getCacheSize()
    return self._cacheSize
end

function Translator:setApiUrl(url)
    self._apiUrl = url
end

function Translator:setRequestFunction(fn)
    if type(fn) == "function" then
        self._customReqFn = fn
    end
end

-- ============================================================
-- RETORNO PARA loadstring
-- ============================================================
return Translator
