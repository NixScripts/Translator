# TranslateScript 🌐

Biblioteca Luau de tradução automática para executores Roblox. Traduz em tempo real todos os textos visíveis de qualquer jogo, sem modificar lógica ou stats.

## Funcionalidades

- **Tradução automática** de TextLabels, TextButtons e TextBoxes
- **APIs em cascata**: Google Translate → MyMemory (GET puro, sem POST)
- **`translateVerbose()`** — retorna resultado + motivo exato (api, cache, skip_word, api_failed...)
- **Debounce inteligente** — aguarda typewriter effect terminar antes de traduzir
- **Cache interno** — textos já traduzidos reutilizados instantaneamente (máx. 1000 entradas)
- **Loop prevention** — não entra em loop ao modificar `.Text`
- **Filtro de segurança** — não toca em labels que o jogo usa como dado (mutations, stats, valores numéricos)
- **Log de erros F4** — últimos 20 erros com horário, categoria e contexto
- **Stats detalhados F3** — breakdown exato: skip intencional / mesmo texto / falha de API
- **Proteção de dupla execução** — `getgenv()` com fallback para `_G`
- **Compatível com**: Xeno, Wave, Solara, Synapse X, KRNL e outros

---

## Como usar

### Loader (recomendado)
Cole o conteúdo de `loader.lua` no executor e execute.

### loadstring manual
```lua
local TranslatorLib = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/NixScripts/Translator/refs/heads/main/Translate.lua"
))()

local t = TranslatorLib.new()

-- retorna só o texto
print(t:translate("Hello World", "pt"))  -- "Olá Mundo"

-- retorna texto + motivo (para debug/stats)
local result, reason = t:translateVerbose("Hello World", "pt")
print(result, reason)  -- "Olá Mundo"   "api"
```

> **Atenção:** A URL deve sempre começar com `raw.githubusercontent.com`. A URL da página do repositório (`github.com`) retorna HTML e o loadstring vai falhar.

---

## Atalhos (loader.lua)

| Tecla | Ação |
|-------|------|
| `F1` | Liga / Desliga + Rescan completo |
| `F2` | Limpa cache + Re-traduz tudo |
| `F3` | Estatísticas: traduzidos, pulados, falhas, API hits, cache hits, uptime |
| `F4` | Log de erros com horário, categoria e contexto |

---

## API — Translate.lua

```lua
local t = TranslatorLib.new()

-- Tradução simples (retorna string)
t:translate(text, targetLang, sourceLang?)

-- Tradução com motivo (retorna result, reason)
t:translateVerbose(text, targetLang, sourceLang?)

-- Utilitários
t:clearCache()
t:getCacheSize()
t:setRequestFunction(fn)
```

### Razões de `translateVerbose()`

| Reason | Significado |
|--------|-------------|
| `"api"` | Traduzido via Google Translate |
| `"api_fb"` | Traduzido via MyMemory (fallback) |
| `"cache"` | Servido do cache, sem HTTP |
| `"custom"` | Traduzido via função customizada |
| `"skip_short"` | Menos de 2 caracteres |
| `"skip_num"` | Apenas números ou símbolos |
| `"skip_word"` | Na lista SKIP_WORDS |
| `"skip_noltr"` | Sem letras no texto |
| `"same"` | API retornou o mesmo texto |
| `"api_failed"` | Todas as APIs falharam |

---

## Configuração (loader.lua)

```lua
local TARGET_LANG   = "pt"    -- idioma alvo
local SOURCE_LANG   = "auto"  -- detecção automática
local DEBOUNCE_TIME = 0.8     -- segundos aguardando typewriter
local RATE_DELAY    = 0.2     -- intervalo entre requisições
local DEBUG_SKIP    = false   -- true = loga cada skip com motivo
```

---

## Estrutura

```
Translator/
├── Translate.lua          ← Módulo principal (hospedado no GitHub)
├── loader.lua             ← Cola no executor
├── README.md
├── docs/
│   └── index.html         ← Documentação completa
└── examples/
    ├── simple_test.lua    ← Teste com translateVerbose + motivos
    └── gui_translator.lua ← Overlay de debug visual
```

---

## Idiomas

| Código | Idioma | Código | Idioma |
|--------|--------|--------|--------|
| `pt` | Português | `ja` | Japonês |
| `en` | Inglês | `ko` | Coreano |
| `es` | Espanhol | `zh` | Chinês |
| `fr` | Francês | `ru` | Russo |
| `de` | Alemão | `ar` | Árabe |

---

## Filtro de Segurança

Labels com segmentos de nome em `UNSAFE_SEGMENTS` (mutation, value, data, score, stat, timer, etc.) ou com texto puramente numérico são ignorados completamente. Isso evita quebrar scripts do jogo que leem o `.Text` de labels como dado interno.

Se um jogo específico ainda causar erro, pressione **F4** para identificar o label problemático e adicione o segmento em `UNSAFE_SEGMENTS` no loader.

---

*TranslateScript Alpha — by NIX — github.com/NixScripts*
