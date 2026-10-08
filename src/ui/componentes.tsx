import { useId, type ButtonHTMLAttributes, type InputHTMLAttributes, type MouseEvent, type ReactNode } from 'react'
import { href, navegar } from '../lib/rota'

// Componentes base. Todos com foco visível (regra global :focus-visible em index.css, RA02)
// e bordas de controle com --color-border-interactive, nunca a subtle (1.4.11).

type CampoProps = InputHTMLAttributes<HTMLInputElement> & { rotulo: string; dica?: string; erro?: string }

export function Campo({ rotulo, dica, erro, ...input }: CampoProps) {
  const id = useId()
  const descricao = [dica && `${id}-dica`, erro && `${id}-erro`].filter(Boolean).join(' ') || undefined
  return (
    <div className="mb-4">
      <label htmlFor={id} className="block mb-1 font-medium text-text">{rotulo}</label>
      {dica && <p id={`${id}-dica`} className="mb-1 text-sm text-text-muted">{dica}</p>}
      <input
        id={id}
        aria-invalid={erro ? true : undefined}
        aria-describedby={descricao}
        className={`w-full rounded-md border bg-bg px-3 py-2 text-body text-text ${erro ? 'border-danger border-2' : 'border-border-interactive'}`}
        {...input}
      />
      {/* RA07: o erro tem texto e ícone, não só a borda vermelha */}
      {erro && <p id={`${id}-erro`} className="mt-1 text-sm text-danger">⚠ {erro}</p>}
    </div>
  )
}

export function Botao({ carregando, children, ...props }: ButtonHTMLAttributes<HTMLButtonElement> & { carregando?: boolean }) {
  return (
    <button
      {...props}
      disabled={props.disabled || carregando}
      aria-busy={carregando || undefined}
      className={`w-full rounded-md bg-primary px-4 py-2 font-medium text-on-primary hover:bg-primary-hover hover:underline disabled:opacity-60 ${props.className ?? ''}`}
    >
      {carregando ? 'Aguarde…' : children}
    </button>
  )
}

export function Link({ para, children }: { para: string; children: ReactNode }) {
  const ir = (e: MouseEvent) => {
    if (e.ctrlKey || e.metaKey || e.shiftKey) return   // deixa abrir em nova aba
    e.preventDefault()
    navegar(para)
  }
  return <a href={href(para)} onClick={ir} className="text-primary underline">{children}</a>
}

// RA07: o tipo do aviso aparece escrito ("Erro:", "Pronto:"), não só pela cor.
export function Aviso({ tipo, children }: { tipo: 'erro' | 'ok'; children: ReactNode }) {
  if (!children) return null
  const erro = tipo === 'erro'
  return (
    <div role={erro ? 'alert' : 'status'} className={`mb-4 rounded-md border-2 p-3 ${erro ? 'border-danger text-danger' : 'border-success text-success'}`}>
      <strong>{erro ? 'Erro:' : 'Pronto:'}</strong> {children}
    </div>
  )
}

export function CartaoAuth({ titulo, subtitulo, children }: { titulo: string; subtitulo?: string; children: ReactNode }) {
  return (
    <main className="min-h-screen grid place-items-center bg-bg px-4 py-8">
      <section className="w-full max-w-md rounded-lg bg-surface p-6 sm:p-8">
        <p className="mb-6 text-center font-titulo text-2xl font-bold text-primary">Blitz</p>
        <h1 className="mb-2 text-center font-titulo text-3xl font-bold text-text">{titulo}</h1>
        {subtitulo && <p className="mb-6 text-center text-text-muted">{subtitulo}</p>}
        {children}
      </section>
    </main>
  )
}
