# TranslateScript 🌐

Script de tradução universal para executores Roblox. Traduz automaticamente todos os textos visíveis de qualquer jogo, em tempo real, para o idioma que você escolher.

## ✨ Funcionalidades

- **Tradução automática** de TextLabels, TextButtons e TextBoxes
- **APIs em cascata**: Google Translate → MyMemory (sem limite prático, GET puro)
- **Debounce inteligente** — aguarda typewriter effect terminar antes de traduzir
- **Cache embutido** — textos já traduzidos são reutilizados instantaneamente
- **Loop prevention** — não entra em loop ao modificar `.Text`
- **Rate limiting** — espaça requisições para não ser bloqueado
- **Palavras neutras** — Shift, Ctrl, HP, NPC etc. não são traduzidas
- **Sanitização de tags** — remove `<font color>` e outros RichText antes de traduzir
- **Proteção de dupla execução** — `getgenv()` (ou `_G` como fallback) evita conflitos ao rodar duas vezes
- **Compatível com executores**: Xeno, Wave, Solara, Synapse X, KRNL e outros

## 🚀 Como usar

### Opção 1: Loader completo (recomendado)

Cole o conteúdo de `loader.lua` no seu executor e execute. Ele baixa a biblioteca automaticamente e ativa a tradução no jogo.

### Opção 2: Via loadstring manual

```lua
local TranslatorLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/NixScripts/TranslateScript/refs/heads/main/Translate"))()
local t = TranslatorLib.new()
print(t:translate("Hello World", "pt"))  -- Olá Mundo
```

## ⌨️ Atalhos (loader.lua)

| Tecla | Ação |
|-------|------|
| `F1` | Liga / Desliga a tradução + Rescan completo |
| `F2` | Limpa cache + Re-traduz tudo do zero |
| `F3` | Exibe estatísticas no console |

## 📁 Estrutura do Repositório

```
TranslateScript/
├── Translate.lua          ← Módulo principal (biblioteca)
├── loader.lua             ← Script para colar no executor
├── README.md
└── examples/
    ├── simple_test.lua    ← Teste rápido de tradução
    └── gui_translator.lua ← Versão standalone com debug visual
```

## 🔧 API da Biblioteca

```lua
local TranslatorLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/NixScripts/TranslateScript/refs/heads/main/Translate"))()

-- Criar instância
local t = TranslatorLib.new()

-- Traduzir texto
local resultado = t:translate("Play Game", "pt")

-- Traduzir com idioma de origem explícito
local resultado = t:translate("Play Game", "pt", "en")

-- Limpar cache
t:clearCache()

-- Ver tamanho do cache
print(t:getCacheSize())

-- Usar função de requisição customizada
t:setRequestFunction(function(text, targetLang, sourceLang)
    -- sua lógica aqui
    return texto_traduzido
end)
```

## 🌍 Idiomas suportados

Qualquer idioma suportado pelo Google Translate. Exemplos:

| Código | Idioma    |
|--------|-----------|
| `pt`   | Português |
| `en`   | Inglês    |
| `es`   | Espanhol  |
| `fr`   | Francês   |
| `de`   | Alemão    |
| `ja`   | Japonês   |
| `zh`   | Chinês    |

## ⚙️ Como funciona internamente

1. `loader.lua` usa `loadstring(game:HttpGet(url))()` — padrão de executor — para baixar e executar `Translate.lua` do GitHub
2. `getgenv()` (com fallback para `_G`) guarda o estado global do executor, evitando conflito se executar duas vezes
3. Toda requisição HTTP usa `game:HttpGet()` (GET puro), sem depender de `HttpService`
4. Google Translate é consultado primeiro; se falhar, cai para MyMemory automaticamente

## ⚠️ Aviso

Este script é destinado a uso pessoal para compreensão de jogos. Use com responsabilidade.
