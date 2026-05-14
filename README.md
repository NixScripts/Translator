# TranslateScript 🌐

Script de tradução universal para executores Roblox. Traduz automaticamente todos os textos visíveis de qualquer jogo, em tempo real, para o idioma que você escolher.

## ✨ Funcionalidades

- **Tradução automática** de TextLabels, TextButtons e TextBoxes
- **Cascade de APIs**: Google Translate → LibreTranslate → MyMemory (sem limite prático)
- **Debounce inteligente** — aguarda o typewriter effect terminar antes de traduzir
- **Cache embutido** — palavras já traduzidas são reutilizadas instantaneamente
- **Loop prevention** — não entra em loop ao modificar o texto
- **Rate limiting** — espaça as requisições para não ser bloqueado
- **Palavras neutras** — Shift, Ctrl, HP, NPC etc. não são enviadas para tradução
- **Sanitização de tags** — remove `<font color>` e outros RichText antes de traduzir
- **Compatível com executores**: Xeno, Synapse X, KRNL, Fluxus e outros

## 🚀 Como usar

### Opção 1: Loader completo (recomendado)

Cole o conteúdo de `loader.lua` no seu executor e execute. Ele baixa a biblioteca automaticamente e ativa a tradução no jogo.

### Opção 2: Via loadstring manual

```lua
local TranslatorLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/NixScripts/TranslateScript/refs/heads/main/Translate.lua"))()
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
    └── gui_translator.lua ← Integração com GUI + debug visual
```

## 🔧 API da Biblioteca

```lua
local TranslatorLib = loadstring(game:HttpGet("URL"))()

-- Criar instância
local t = TranslatorLib.new()

-- Traduzir texto
local resultado = t:translate("Play Game", "pt")

-- Limpar cache
t:clearCache()

-- Ver tamanho do cache
print(t:getCacheSize())

-- Trocar URL da API
t:setApiUrl("https://minha-api.com")

-- Função de requisição customizada
t:setRequestFunction(function(text, targetLang, sourceLang)
    -- sua lógica aqui
    return texto_traduzido
end)
```

## 🌍 Idiomas suportados

Qualquer idioma suportado pelo Google Translate. Exemplos:

| Código | Idioma     |
|--------|------------|
| `pt`   | Português  |
| `en`   | Inglês     |
| `es`   | Espanhol   |
| `fr`   | Francês    |
| `de`   | Alemão     |
| `ja`   | Japonês    |
| `zh`   | Chinês     |

## ⚠️ Aviso

Este script é destinado a uso pessoal para compreensão de jogos. Usar executores em jogos online pode violar os Termos de Serviço do Roblox. Use com responsabilidade.
