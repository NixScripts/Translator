# TranslateScript 🌐

Biblioteca Luau de tradução automática para executores Roblox. Traduz em tempo real todos os textos visíveis de qualquer jogo, para o idioma que você escolher.

## ✨ Funcionalidades

- **Tradução automática** de TextLabels, TextButtons e TextBoxes
- **APIs em cascata**: Google Translate → MyMemory (GET puro, sem POST)
- **`translateVerbose()`** — retorna o resultado e o motivo exato (api, cache, skip_word, api_failed, etc.)
- **Debounce inteligente** — aguarda typewriter effect terminar antes de traduzir
- **Cache interno** — textos já traduzidos reutilizados instantaneamente (máx. 1000 entradas)
- **Loop prevention** — não entra em loop ao modificar `.Text`
- **Log de erros** (F4) — últimos 20 erros com horário, categoria e contexto
- **Stats detalhados** (F3) — breakdown de skip intencional vs falha de API vs já traduzido
- **Proteção de dupla execução** — `getgenv()` com fallback para `_G`
- **Compatível com**: Xeno, Wave, Solara, Synapse X, KRNL e outros

## 🚀 Como usar

### Loader completo (recomendado)
Cole o conteúdo de `loader.lua` no executor e execute.

### loadstring manual
```lua
local TranslatorLib = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/NixScripts/Translator/refs/heads/main/Translate.lua"
))()

local t = TranslatorLib.new()

-- Tradução simples
print(t:translate("Hello World", "pt"))  -- "Olá Mundo"

-- Tradução com motivo (para debug/stats)
local result, reason = t:translateVerbose("Hello World", "pt")
print(result, reason)  -- "Olá Mundo"   "api"
```

## ⌨️ Atalhos (loader.lua)

| Tecla | Ação |
|-------|------|
| `F1` | Liga / Desliga + Rescan completo |
| `F2` | Limpa cache + Re-traduz tudo |
| `F3` | Estatísticas detalhadas (breakdown de skip) |
| `F4` | Log de erros com horário e contexto |

## 🔧 API — Translate.lua

```lua
-- Criar instância
local t = TranslatorLib.new()

-- Traduzir (retorna string)
t:translate(text, targetLang, sourceLang?)

-- Traduzir com motivo (retorna result, reason)
t:translateVerbose(text, targetLang, sourceLang?)

-- Utilitários
t:clearCache()
t:getCacheSize()
t:setRequestFunction(fn)  -- substituir lógica HTTP por função customizada
```

### Razões retornadas por `translateVerbose()`

| Reason | Significado |
|--------|-------------|
| `"api"` | Traduzido via Google Translate |
| `"api_fb"` | Traduzido via MyMemory (fallback) |
| `"cache"` | Servido do cache, sem requisição HTTP |
| `"custom"` | Traduzido via função customizada |
| `"skip_short"` | Texto muito curto (< 2 chars) |
| `"skip_num"` | Apenas números ou símbolos |
| `"skip_word"` | Palavra na lista SKIP_WORDS |
| `"skip_noltr"` | Sem letras no texto |
| `"same"` | API retornou o mesmo texto (já no idioma alvo) |
| `"api_failed"` | Todas as APIs falharam |

## 📁 Estrutura

```
Translator/
├── Translate.lua          ← Módulo principal
├── loader.lua             ← Cola no executor
├── README.md
└── examples/
    ├── simple_test.lua    ← Testa translateVerbose com motivos
    └── gui_translator.lua ← Overlay de debug visual
```

## 🌍 Idiomas

| Código | Idioma | Código | Idioma |
|--------|--------|--------|--------|
| `pt` | Português | `ja` | Japonês |
| `en` | Inglês | `ko` | Coreano |
| `es` | Espanhol | `zh` | Chinês |
| `fr` | Francês | `ru` | Russo |
| `de` | Alemão | `ar` | Árabe |

## ⚙️ Configuração (loader.lua)

```lua
local TARGET_LANG   = "pt"    -- idioma alvo
local SOURCE_LANG   = "auto"  -- detecção automática
local DEBOUNCE_TIME = 0.8     -- segundos aguardando typewriter
local RATE_DELAY    = 0.2     -- intervalo entre requisições
local DEBUG_SKIP    = false   -- true = loga cada skip com motivo no console
```

## Changelog

### v1.4.0
- Adicionado `translateVerbose()` — retorna `result, reason` com motivo exato
- `_doRequest()` agora retorna `result, source` ("api" ou "api_fb")
- Loader usa `translateVerbose` para stats 100% precisos (sem heurísticas de cache)
- Stats F3 com breakdown real: skip intencional / same / api_failed
- F4 adicionado — log de erros com horário, categoria e contexto (máx. 20)
- `DEBUG_SKIP = false` no loader — ative para ver cada skip com motivo no console
- `_storeCache()` extraído como helper interno
- Validação de objeto destruído em `translateObject` antes de processar

### v1.3.0
- Fix: `pcall` em `watchObject` capturando resultado do `IsA` corretamente
- Fix: `sanitize()` com `or ""` no match
- Fix: `WaitForChild` substituído por `FindFirstChild` + fallback async

### v1.2.0
- Proteção de dupla execução via `getgenv()` com fallback `_G`
- Carregamento separado em download → compilação → execução
- Removido `httpPost` e `HttpService` — GET puro apenas

### v1.1.0
- Fix: globals de executor via `rawget(_G, ...)`
- `scanGui` migrado para `GetDescendants()`

### v1.0.0
- Lançamento inicial
