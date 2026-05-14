--[[
    examples/simple_test.lua
    Teste rápido da biblioteca de tradução.
    Execute no executor para verificar se tudo funciona.
]]

local LIB_URL = "https://raw.githubusercontent.com/NixScripts/TranslateScript/refs/heads/main/Translate.lua"

local ok, TranslatorLib = pcall(function()
    return loadstring(game:HttpGet(LIB_URL))()
end)

if not ok then
    warn("❌ Falha ao carregar biblioteca: " .. tostring(TranslatorLib))
    return
end

local t = TranslatorLib.new()

-- Frases de teste
local tests = {
    { text = "Hello World",            expected_lang = "pt" },
    { text = "Start Game",             expected_lang = "pt" },
    { text = "Level Up!",              expected_lang = "pt" },
    { text = "You have 5 gold",        expected_lang = "pt" },
    { text = "Press Shift to sprint",  expected_lang = "pt" },
    { text = "Welcome to the game",    expected_lang = "pt" },
}

print("\n[TESTE] === Iniciando testes de tradução ===")
for i, test in ipairs(tests) do
    local result = t:translate(test.text, test.expected_lang)
    local status = (result ~= test.text) and "✅" or "⚠"
    print(string.format("[TESTE] %s [%d] '%s' → '%s'", status, i, test.text, result))
    task.wait(0.3) -- respeita rate limit
end

print(string.format("\n[TESTE] Cache: %d entradas", t:getCacheSize()))
print("[TESTE] === Fim dos testes ===")
