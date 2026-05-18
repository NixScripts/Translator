--[[
    Universal Luau Translator Library
    Alpha — by NixScripts

    Uso (executor):
        local Translator = loadstring(game:HttpGet("https://raw.githubusercontent.com/NixScripts/Translator/refs/heads/main/Translate.lua"))()
        local t = Translator.new()
        print(t:translate("Hello World", "pt"))

    Métodos públicos:
        Translator.new()
        translator:translate(text, targetLang, sourceLang?)   → string
        translator:translateVerbose(text, targetLang, sourceLang?) → result, reason
        translator:clearCache()
        translator:getCacheSize()
        translator:setRequestFunction(fn)

    Razões retornadas por translateVerbose():
        "cache"      → servido do cache (sem requisição HTTP)
        "api"        → traduzido via Google Translate
        "api_fb"     → traduzido via MyMemory (fallback)
        "custom"     → traduzido via função customizada
        "skip_short" → texto muito curto (<2 chars)
        "skip_num"   → apenas números/símbolos
        "skip_word"  → palavra na lista SKIP_WORDS
        "skip_noltr" → sem letras
        "api_failed" → todas as APIs falharam, retornou original
        "same"       → API retornou mesmo texto (já no idioma alvo)
]]

local Translator = {}
Translator.__index = Translator

-- ============================================================
-- PALAVRAS QUE NÃO PRECISAM DE TRADUÇÃO
-- ============================================================
local SKIP_WORDS = {
    -- Teclas
    ["shift"]=true, ["ctrl"]=true, ["alt"]=true, ["tab"]=true,
    ["esc"]=true, ["enter"]=true, ["delete"]=true, ["backspace"]=true,
    ["space"]=true, ["capslock"]=true, ["numlock"]=true,
    -- Atalhos de jogo (letras únicas)
    ["e"]=true, ["q"]=true, ["w"]=true, ["r"]=true,
    ["f"]=true, ["g"]=true, ["v"]=true, ["c"]=true,
    -- Termos de jogo iguais em qualquer idioma
    ["ui"]=true, ["npc"]=true, ["hp"]=true, ["mp"]=true,
    ["xp"]=true, ["pvp"]=true, ["pve"]=true, ["id"]=true,
    ["fps"]=true, ["dps"]=true, ["aoe"]=true, ["dot"]=true,
    ["buff"]=true, ["debuff"]=true, ["boss"]=true, ["mob"]=true,
    ["skill"]=true, ["level"]=true, ["loot"]=true, ["grind"]=true,
    ["spawn"]=true, ["map"]=true, ["slot"]=true, ["cd"]=true,
    -- Siglas técnicas
    ["api"]=true, ["url"]=true, ["html"]=true, ["json"]=true,
    ["ok"]=true, ["status"]=true, ["error"]=true, ["debug"]=true,
}

-- ============================================================
-- HTTP GET — game:HttpGet é o padrão em executores
-- ============================================================
local function httpGet(url)
    local ok, result = pcall(function()
        return game:HttpGet(url)
    end)
    return ok and result or nil
end

-- ============================================================
-- URL ENCODE manual
-- ============================================================
local function urlEncode(str)
    return str:gsub("([^%w%-%.%_%~])", function(c)
        return string.format("%%%02X", string.byte(c))
    end)
end

-- ============================================================
-- SANITIZAÇÃO — remove RichText, Color3 tags e entidades HTML
-- ============================================================
local function sanitize(text)
    if not text or text == "" then return "" end
    local s = text
    s = s:gsub("<[^>]+>", "")
    s = s:gsub("%[color=[^%]]+%]", "")
    s = s:gsub("%[/color%]", "")
    s = s:gsub("&nbsp;",  " ")
    s = s:gsub("&quot;",  '"')
    s = s:gsub("&#39;",   "'")
    s = s:gsub("&amp;",   "&")
    s = s:gsub("&lt;",    "<")
    s = s:gsub("&gt;",    ">")
    s = s:match("^%s*(.-)%s*$") or ""
    return s
end

-- ============================================================
-- SKIP — retorna motivo do skip ou nil (não pula)
-- ============================================================
local function skipReason(text)
    if not text or #text < 2 then return "skip_short" end
    if text:match("^[%d%s%p]+$") then return "skip_num" end
    if not text:match("%a") then return "skip_noltr" end
    if SKIP_WORDS[text:lower()] then return "skip_word" end
    return nil
end

-- ============================================================
-- DECODE unicode escape (\uXXXX) seguro
-- ============================================================
local function decodeUnicode(str)
    return str:gsub("\\u(%x%x%x%x)", function(h)
        local n = tonumber(h, 16)
        if n and utf8 and utf8.char then
            local ok, ch = pcall(utf8.char, n)
            return ok and ch or ("\\u"..h)
        end
        return "\\u"..h
    end)
end

-- ============================================================
-- CONSTRUTOR
-- ============================================================
function Translator.new()
    return setmetatable({
        _cache       = {},
        _cacheSize   = 0,
        _maxCache    = 1000,
        _customReqFn = nil,
    }, Translator)
end

-- ============================================================
-- REQUISIÇÃO: Google Translate → MyMemory (fallback)
-- Retorna: result, source ("api" | "api_fb" | nil)
-- ============================================================
function Translator:_doRequest(text, targetLang, sourceLang)
    local encoded = urlEncode(text)

    -- API 1: Google Translate
    local googleUrl = string.format(
        "https://translate.googleapis.com/translate_a/single?client=gtx&sl=%s&tl=%s&dt=t&q=%s",
        sourceLang, targetLang, encoded
    )
    local resp = httpGet(googleUrl)
    if resp then
        local translated = resp:match('%[%[%["(.-)"')
        if translated and translated ~= "" then
            return decodeUnicode(translated), "api"
        end
    end

    -- API 2: MyMemory (fallback)
    local mmUrl = string.format(
        "https://api.mymemory.translated.net/get?q=%s&langpair=%s|%s",
        encoded,
        sourceLang == "auto" and "en" or sourceLang,
        targetLang
    )
    local resp2 = httpGet(mmUrl)
    if resp2 then
        local tr = resp2:match('"translatedText":"(.-)"')
        if tr and tr ~= "" then return tr, "api_fb" end
    end

    return nil, nil
end

-- ============================================================
-- MÉTODO VERBOSE — retorna (result, reason)
-- Use este no loader para stats precisos
-- ============================================================
function Translator:translateVerbose(text, targetLang, sourceLang)
    targetLang = targetLang or "pt"
    sourceLang = sourceLang or "auto"

    local clean = sanitize(text)

    -- Verifica skip
    local reason = skipReason(clean)
    if reason then
        return text, reason
    end

    -- Verifica cache
    local cacheKey = clean .. "|" .. targetLang
    if self._cache[cacheKey] then
        return self._cache[cacheKey], "cache"
    end

    -- Função customizada
    if self._customReqFn then
        local ok, res = pcall(self._customReqFn, clean, targetLang, sourceLang)
        if ok and res and res ~= "" and res ~= clean then
            self:_storeCache(cacheKey, res)
            return res, "custom"
        end
        return text, "api_failed"
    end

    -- Requisição às APIs
    local result, source = self:_doRequest(clean, targetLang, sourceLang)

    if result and result ~= "" and result ~= clean then
        self:_storeCache(cacheKey, result)
        return result, source
    elseif result and result == clean then
        return text, "same"
    end

    return text, "api_failed"
end

-- ============================================================
-- MÉTODO PRINCIPAL (compatibilidade — chama translateVerbose)
-- ============================================================
-- ============================================================
-- MÉTODO PRINCIPAL — wrapper simples sobre translateVerbose
-- Retorna apenas o texto (sem reason) para uso direto
-- ============================================================
function Translator:translate(text, targetLang, sourceLang)
    local result, _ = self:translateVerbose(text, targetLang, sourceLang)
    return result
end

-- ============================================================
-- HELPER INTERNO — salva no cache com auto-limpeza
-- ============================================================
function Translator:_storeCache(key, value)
    if self._cacheSize >= self._maxCache then
        self._cache     = {}
        self._cacheSize = 0
    end
    self._cache[key] = value
    self._cacheSize  = self._cacheSize + 1
end

-- ============================================================
-- UTILITÁRIOS PÚBLICOS
-- ============================================================
function Translator:clearCache()
    self._cache     = {}
    self._cacheSize = 0
end

function Translator:getCacheSize()
    return self._cacheSize
end

function Translator:setRequestFunction(fn)
    if type(fn) == "function" then
        self._customReqFn = fn
    end
end

return Translator
