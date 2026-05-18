# Contribuindo para TranslateScript 🌐

Obrigado por considerar contribuir para o TranslateScript! Este documento fornece orientações e instruções para contribuir com o projeto.

## 📋 Código de Conduta

Este projeto adere ao [Código de Conduta](CODE_OF_CONDUCT.md). Ao participar, você se compromete a respeitar este código.

## 🚀 Como Contribuir

### Reportando Bugs

Antes de criar um relatório de bug, faça uma checklist:

- **Procure na seção de issues** — a falha pode ter sido relatada
- **Tente reproduzir** em uma versão limpa do script
- **Verifique a versão do executor** — alguns bugs são específicos de executor (Xeno, Wave, Solara)
- **Ative DEBUG_MODE ou F4** para capturar logs de erro

Ao criar um bug report, inclua:
- Qual executor você está usando (Xeno, Wave, Solara, Synapse X, etc.)
- Qual jogo testou
- Passos exatos para reproduzir
- Comportamento esperado vs. o que realmente aconteceu
- Saída do console (F4 para log de erros)
- Screenshots ou vídeo se possível

### Sugerindo Melhorias

Sugestões são sempre bem-vindas! Ao sugerir, descreva:
- **O caso de uso** — por que isso seria útil?
- **Exemplo de uso** — como funcionaria?
- **Alternativas consideradas** — você pensou em outras abordagens?

### Pull Requests

1. **Faça um fork** do repositório
2. **Crie uma branch** para sua feature/fix: `git checkout -b feature/minha-feature`
3. **Siga o estilo de código** do projeto:
   - Use `camelCase` para variáveis e funções
   - Comente seções complexas com `-- Descrição clara`
   - Use nomes descritivos (`isEnabled` ao invés de `e`)
4. **Teste seu código** antes de fazer commit:
   - Use `simple_test.lua` para testar a biblioteca
   - Use `gui_translator.lua` para testar o loader em um jogo
   - Ative `DEBUG_SKIP = true` para verificar comportamento do filtro
5. **Commit com mensagens claras**:
   ```
   feat: adiciona suporte para idiomas RTL (direita-esquerda)
   fix: corrige loop infinito ao traduzir textos vazios
   docs: atualiza README com novos exemplos
   ```
6. **Push para sua branch** e **abra um Pull Request**

#### Checklist de PR

- [ ] Testado em pelo menos 2 executores diferentes
- [ ] Testado em 2+ jogos diferentes
- [ ] Sem breaking changes (ou documentado se houver)
- [ ] Código segue o estilo do projeto
- [ ] Atualizei a documentação (README, docs/index.html)
- [ ] Adicionei teste em `examples/` se for feature
- [ ] Sem erros no console (F4 limpo)

## 📁 Estrutura do Projeto

```
Translator/
├── Translate.lua          ← Módulo principal (não modifique levianamente)
├── loader.lua             ← Loader principal
├── README.md              ← Documentação principal
├── docs/
│   └── index.html         ← Documentação completa e interativa
└── examples/
    ├── simple_test.lua    ← Teste unitário
    └── gui_translator.lua ← Exemplo com overlay visual
```

### Diretrizes por arquivo

**Translate.lua**
- Mudanças aqui afetam todos os usuários
- Sempre mantenha compatibilidade com versões antigas
- Documente todas as mudanças no cabeçalho
- Teste com `simple_test.lua`

**loader.lua**
- Adicione novas configurações no topo
- Mantenha a proteção de dupla execução
- Não quebre os atalhos (F1, F2, F3, F4)
- Teste com `gui_translator.lua`

**docs/index.html**
- Atualize simultaneamente com mudanças na funcionalidade
- Mantenha a seção "Descobertas" e "Tentativa & Erro" como histórico
- Use o mesmo estilo CSS existente

## 🔍 Processo de Review

1. Qualquer maintainer pode revisar PRs
2. Pelo menos 1 aprovação antes de merge
3. Todos os checks do CI devem passar
4. Sem comentários não resolvidos

## 📝 Estilo de Código

### Lua/Luau

```lua
-- ✅ BOM
local function isSafeToTranslate(obj)
    local name = obj.Name:lower()
    for segment in name:gmatch("[a-z]+") do
        if UNSAFE_SEGMENTS[segment] then return false end
    end
    return true
end

-- ❌ RUIM
local function issafe(o)
    local n=o.Name:lower()
    for s in n:gmatch("[a-z]+") do
        if UNSAFE_SEGMENTS[s]then return false end
    end
    return true
end
```

### Comentários

```lua
-- ============================================================
-- SEÇÃO PRINCIPAL
-- ============================================================
-- Descrição clara da próxima seção de código

-- Explicação de um comportamento não óbvio
local function needsExplanation()
    -- Por que fazemos isso assim e não de outra forma?
    return value -- importante
end
```

## 🧪 Testando

### Teste Local

```lua
-- 1. Copie o conteúdo de loader.lua ou simple_test.lua
-- 2. Cole no executor
-- 3. Execute e monitore:
--    F3 = stats
--    F4 = erros
```

### Teste em Múltiplos Jogos

Recomendamos testar em:
- **Deepwoken** — complexo, muitos labels, typewriter effect
- **Blox Fruits** — muitos números e valores (testa filtro de segurança)
- **Brookhaven RP** — textos dinâmicos e player-generated

## 🐛 Rastreamento de Bugs

Use labels no GitHub:

- `bug` — comportamento inesperado
- `enhancement` — nova feature
- `documentation` — melhorias de docs
- `help-wanted` — precisa de ajuda
- `good-first-issue` — bom para iniciantes
- `lua` — específico de Lua/Luau
- `html` — específico de HTML/docs
- `executor-specific` — bug em executor específico (ex: Xeno)

## ❓ Dúvidas?

- Abra uma **Discussion** para dúvidas gerais
- Abra uma **Issue** para bugs confirmados
- Abra um **PR** com sua solução!

---

**Obrigado por contribuir! 🎉**

*TranslateScript — by NIX*
