import { createClient } from '@supabase/supabase-js'

// Só a URL e a chave publicável (sb_publishable_...) vão para o navegador; quem protege os dados é a RLS do banco.
// A chave do Gemini e a service_role nunca entram aqui (regra de arquitetura, CLAUDE.md seção 2).
const url = import.meta.env.VITE_SUPABASE_URL
const chave = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY
if (!url || !chave) throw new Error('Configure VITE_SUPABASE_URL e VITE_SUPABASE_PUBLISHABLE_KEY no .env.local (veja .env.example).')

export const supabase = createClient(url, chave)
