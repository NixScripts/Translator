--[[
    examples/simple_test.lua
    Teste rápido da biblioteca — v1.4.1
    Mostra resultado E motivo de cada tradução.
]]

local genv = (type(getgenv) == "function" and getgenv()) or _G
if genv.__TRANSLATESCRIPT_TEST_LOADED then
    print("[TESTE] ⚠ Teste já rodando!")
    return
end
genv.__TRANSLATESCRIPT_TEST_LOADED = true

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
            warn("[TESTE] ⚠ Compile error: " .. tostring(err))
        end
    end
end

if not TranslatorLib then
    genv.__TRANSLATESCRIPT_TEST_LOADED = nil
    warn("[TESTE] ❌ Falha ao carregar biblioteca.")
    return
end

local t = TranslatorLib.new()

local tests = {
    "Hello World",
    "Start Game",
    "Level Up!",
    "You have 5 gold coins",
    "Press Shift to sprint",
    "Welcome to the game",
    "Shift",          -- skip_word
    "HP",             -- skip_word
    "123",            -- skip_num
    "!@#",            -- skip_num
    "e",              -- skip_short
}

print("\n[TESTE] === Testes de tradução (v1.4.1) ===")
for i, text in ipairs(tests) do
    local result, reason = t:translateVerbose(text, "pt")
    local icon = (result ~= text) and "✅" or "⏭"
    print(string.format("[TESTE] %s [%d] (%s)\n        '%s' → '%s'",
        icon, i, reason, text, result))
    task.wait(0.3)
end

print(string.format("\n[TESTE] Cache: %d entradas", t:getCacheSize()))
print("[TESTE] === Fim dos testes ===")
genv.__TRANSLATESCRIPT_TEST_LOADED = nil
