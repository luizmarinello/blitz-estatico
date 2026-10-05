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
