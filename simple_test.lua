--[[
    examples/simple_test.lua
    Teste rápido da biblioteca de tradução.
    Execute no executor para verificar se tudo funciona.
]]

local genv = (type(getgenv) == "function" and getgenv()) or _G
if genv.__TRANSLATESCRIPT_TEST_LOADED then
    print("[TESTE] ⚠ Teste já rodando!")
    return
end
genv.__TRANSLATESCRIPT_TEST_LOADED = true

local LIB_URL = "https://raw.githubusercontent.com/NixScripts/TranslateScript/refs/heads/main/Translate"

local ok, TranslatorLib = pcall(function()
    return loadstring(game:HttpGet(LIB_URL))()
end)

if not ok or not TranslatorLib then
    genv.__TRANSLATESCRIPT_TEST_LOADED = nil
    warn("[TESTE] ❌ Falha ao carregar biblioteca: " .. tostring(TranslatorLib))
    return
end

local t = TranslatorLib.new()

local tests = {
    { text = "Hello World"           },
    { text = "Start Game"            },
    { text = "Level Up!"             },
    { text = "You have 5 gold"       },
    { text = "Press Shift to sprint" },
    { text = "Welcome to the game"   },
    { text = "Shift"                 }, -- deve ser pulado (SKIP_WORDS)
    { text = "123"                   }, -- deve ser pulado (só números)
}

print("\n[TESTE] === Iniciando testes de tradução ===")
for i, test in ipairs(tests) do
    local result = t:translate(test.text, "pt")
    local status = (result ~= test.text) and "✅ traduzido" or "⏭  pulado"
    print(string.format("[TESTE] [%d] %s | '%s' → '%s'", i, status, test.text, result))
    task.wait(0.3) -- respeita rate limit
end

print(string.format("\n[TESTE] Cache: %d entradas", t:getCacheSize()))
print("[TESTE] === Fim dos testes ===")

genv.__TRANSLATESCRIPT_TEST_LOADED = nil
