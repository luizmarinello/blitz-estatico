import { useEffect, useState } from 'react'
import type { Session } from '@supabase/supabase-js'
import { supabase } from './lib/supabase'
import { navegar, useRota } from './lib/rota'
import { Cadastro, Login, Recuperar, Redefinir, Termos } from './telas/auth'
import { Painel } from './telas/Painel'

const PUBLICAS = ['/login', '/cadastro', '/recuperar']

export default function App() {
  const caminho = useRota()
  const [sessao, setSessao] = useState<Session | null | undefined>(undefined)   // undefined = ainda carregando

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => setSessao(data.session))
    const { data } = supabase.auth.onAuthStateChange((evento, s) => {
      setSessao(s)
      if (evento === 'PASSWORD_RECOVERY') navegar('/redefinir', true)   // RF03: veio do link do e-mail
    })
    return () => data.subscription.unsubscribe()
  }, [])

  // RN01: sem sessão, só as telas públicas; com sessão, login e cadastro levam ao painel.
  const destino = sessao === undefined ? null
    : !sessao && !PUBLICAS.includes(caminho) && caminho !== '/termos' ? '/login'
    : sessao && PUBLICAS.includes(caminho) ? '/'
    : null
  useEffect(() => { if (destino) navegar(destino, true) }, [destino])

  if (sessao === undefined || destino) return <Carregamento />
  if (caminho === '/termos') return <Termos />
  if (!sessao) {
    if (caminho === '/cadastro') return <Cadastro />
    if (caminho === '/recuperar') return <Recuperar />
    return <Login />
  }
  if (caminho === '/redefinir') return <Redefinir />
  return <Painel sessao={sessao} />
}

// Tela 01 Carregamento
function Carregamento() {
  return (
    <main className="min-h-screen grid place-items-center bg-bg" aria-busy="true">
      <p role="status" className="font-titulo text-2xl font-bold text-primary">Blitz<span className="sr-only"> — carregando…</span></p>
    </main>
  )
}
