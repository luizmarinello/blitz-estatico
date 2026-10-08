# Blitz

Sistema de foco e produtividade (TCC, equipe T03N). Contexto completo, requisitos e decisões em [CLAUDE.md](CLAUDE.md).

Stack: React 18 + TypeScript + Tailwind + Framer Motion, Supabase (PostgreSQL + Auth + Edge Functions), Gemini via Edge Function.

## Rodar

```bash
npm install
npm run dev
```

Antes, copie `.env.example` para `.env.local` e preencha com os dados do projeto Supabase.

## Banco

O schema fica em `supabase/migrations/`. Para aplicar num projeto Supabase novo: abra o SQL Editor do painel, cole o arquivo da migração e execute.

Checagem automática do schema e da RLS (precisa de Docker):

```bash
sh scripts/testar-schema.sh
```

## Publicação (GitHub Pages)

Cada push na `main` do repositório `luizmarinello/blitz-estatico` publica o app em https://luizmarinello.github.io/blitz-estatico/ pelo workflow
`.github/workflows/pages.yml`. O build lê a URL do Supabase e a chave publicável de `.env.production`
(valores públicos por natureza; a proteção dos dados é a RLS). No Supabase, em Authentication > URL Configuration,
`https://luizmarinello.github.io/blitz-estatico/**` precisa estar em Redirect URLs para os links de e-mail voltarem ao app.
