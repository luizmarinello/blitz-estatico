// Tela 05 Painel principal — provisória: só confirma o login (UC01) e permite sair.
// O quadro, os widgets e o assistente entram nas próximas etapas (UC02, UC03, UC04).
import { useEffect, useState } from 'react'
import type { Session } from '@supabase/supabase-js'
import { supabase } from '../lib/supabase'

export function Painel({ sessao }: { sessao: Session }) {
  const [nome, setNome] = useState<string | null>(null)
  const [erro, setErro] = useState(false)

  useEffect(() => {
    supabase.from('usuario').select('nome').eq('id', sessao.user.id).single()
      .then(({ data, error }) => (error ? setErro(true) : setNome(data.nome)))
  }, [sessao.user.id])

  return (
    <main className="min-h-screen bg-bg px-4 py-8 text-text">
      <header className="mx-auto flex max-w-5xl items-center justify-between">
        <p className="font-titulo text-2xl font-bold text-primary">Blitz</p>
        <button onClick={() => supabase.auth.signOut()} className="rounded-md border border-border-interactive px-3 py-1">
          Sair
        </button>
      </header>
      <section className="mx-auto mt-8 max-w-5xl">
        <h1 className="font-titulo text-3xl font-bold">
          {erro ? 'Não foi possível carregar seu perfil.' : nome === null ? 'Carregando…' : `Olá, ${nome.split(' ')[0]}!`}
        </h1>
        <p className="mt-2 text-text-muted">O quadro de tarefas chega na próxima etapa.</p>
      </section>
    </main>
  )
}
