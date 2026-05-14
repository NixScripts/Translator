--[[
    Universal Luau Translator Library
    v1.1.0 — by NixScripts

    Uso via loadstring (executor):
        local Translator = loadstring(game:HttpGet("https://raw.githubusercontent.com/NixScripts/TranslateScript/refs/heads/main/Translate"))()
        local t = Translator.new()
        print(t:translate("Hello World", "pt"))

    Métodos:
        Translator.new()                        → Cria nova instância
        translator:translate(text, targetLang)  → Traduz texto
        translator:clearCache()                 → Limpa o cache
        translator:getCacheSize()               → Retorna entradas no cache
        translator:setRequestFunction(fn)       → Define função HTTP customizada
]]

local Translator = {}
Translator.__index = Translator

-- ============================================================
-- PALAVRAS QUE NÃO PRECISAM SER TRADUZIDAS
-- ============================================================
local SKIP_WORDS = {
    ["shift"] = true, ["ctrl"] = true, ["alt"] = true, ["tab"] = true,
    ["esc"] = true, ["enter"] = true, ["delete"] = true, ["backspace"] = true,
    ["space"] = true, ["capslock"] = true, ["numlock"] = true,
    ["e"] = true, ["q"] = true, ["w"] = true, ["r"] = true,
    ["f"] = true, ["g"] = true, ["v"] = true, ["c"] = true,
    ["ui"] = true, ["npc"] = true, ["hp"] = true, ["mp"] = true,
    ["xp"] = true, ["pvp"] = true, ["pve"] = true, ["id"] = true,
    ["fps"] = true, ["dps"] = true, ["aoe"] = true, ["dot"] = true,
    ["buff"] = true, ["debuff"] = true, ["boss"] = true, ["mob"] = true,
    ["skill"] = true, ["level"] = true, ["loot"] = true, ["grind"] = true,
    ["spawn"] = true, ["map"] = true, ["slot"] = true, ["cd"] = true,
    ["api"] = true, ["url"] = true, ["html"] = true, ["json"] = true,
    ["ok"] = true, ["status"] = true, ["error"] = true, ["debug"] = true,
}

-- ============================================================
-- HTTP — game:HttpGet para GET (padrão de executor)
-- request/http_request para POST se disponível
-- Sem fallback de HttpService — ambiente executor apenas
-- ============================================================
local function httpGet(url)
    local ok, result = pcall(function()
        return game:HttpGet(url, true)
    end)
    return ok and result or nil
end

local function httpPost(url, body)
    local postFn = rawget(_G, "request")
                or rawget(_G, "http_request")
                or (rawget(_G, "syn") and rawget(_G, "syn").request)
                or (rawget(_G, "http") and rawget(_G, "http").request)

    if not postFn then return nil end

    local ok, response = pcall(postFn, {
        Url     = url,
        Method  = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body    = body,
    })

    return ok and response and (response.Body or response.body) or nil
end

-- ============================================================
-- URL ENCODE manual (sem depender de HttpService)
-- ============================================================
local function urlEncode(str)
    return str:gsub("([^%w%-%.%_%~])", function(c)
        return string.format("%%%02X", string.byte(c))
    end)
end

-- ============================================================
-- SANITIZAÇÃO — remove RichText/Color3 tags e entidades HTML
-- ============================================================
local function sanitize(text)
    if not text or text == "" then return "" end
    local s = text
    s = s:gsub("<[^>]+>", "")
    s = s:gsub("%[color=[^%]]+%]", "")
    s = s:gsub("%[/color%]", "")
    s = s:gsub("&nbsp;", " ")
    s = s:gsub("&quot;", '"')
    s = s:gsub("&#39;",  "'")
    s = s:gsub("&amp;",  "&")
    s = s:gsub("&lt;",   "<")
    s = s:gsub("&gt;",   ">")
    s = s:match("^%s*(.-)%s*$")
    return s
end

-- ============================================================
-- SKIP — decide se o texto precisa de tradução
-- ============================================================
local function shouldSkip(text)
    if not text or #text < 2 then return true end
    if text:match("^[%d%s%p]+$") then return true end
    if not text:match("%a") then return true end
    if SKIP_WORDS[text:lower()] then return true end
    return false
end

-- ============================================================
-- DECODE unicode escape (\uXXXX)
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
-- ============================================================
function Translator:_doRequest(text, targetLang, sourceLang)
    local encoded = urlEncode(text)

    -- API 1: Google Translate (não oficial, sem limite prático)
    local googleUrl = string.format(
        "https://translate.googleapis.com/translate_a/single?client=gtx&sl=%s&tl=%s&dt=t&q=%s",
        sourceLang, targetLang, encoded
    )
    local resp = httpGet(googleUrl)
    if resp then
        local translated = resp:match('%[%[%["(.-)"')
        if translated and translated ~= "" then
            return decodeUnicode(translated)
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
        if tr and tr ~= "" then return tr end
    end

    return nil
end

-- ============================================================
-- MÉTODO PRINCIPAL
-- ============================================================
function Translator:translate(text, targetLang, sourceLang)
    targetLang = targetLang or "pt"
    sourceLang = sourceLang or "auto"

    local clean = sanitize(text)
    if shouldSkip(clean) then return text end

    local cacheKey = clean .. "|" .. targetLang
    if self._cache[cacheKey] then
        return self._cache[cacheKey]
    end

    local result
    if self._customReqFn then
        local ok, res = pcall(self._customReqFn, clean, targetLang, sourceLang)
        result = ok and res or nil
    else
        result = self:_doRequest(clean, targetLang, sourceLang)
    end

    if result and result ~= "" and result ~= clean then
        if self._cacheSize >= self._maxCache then
            self._cache    = {}
            self._cacheSize = 0
        end
        self._cache[cacheKey] = result
        self._cacheSize = self._cacheSize + 1
        return result
    end

    return text
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

function Translator:setRequestFunction(fn)
    if type(fn) == "function" then
        self._customReqFn = fn
    end
end

return Translator
