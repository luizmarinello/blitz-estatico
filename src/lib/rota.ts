import { useEffect, useState } from 'react'

// Roteamento por caminho (history API). Não é por hash porque o link de recuperação do Supabase
// volta com ?code=... na URL, e isso conflita com rotas em #.
// BASE: '' em desenvolvimento, '/blitz-estatico' no GitHub Pages (vite.config.ts). As telas só conhecem '/login' etc.
const BASE = import.meta.env.BASE_URL.replace(/\/$/, '')

export const href = (caminho: string) => BASE + caminho
export const urlAbsoluta = (caminho: string) => location.origin + BASE + caminho   // links que voltam por e-mail

const caminhoAtual = () => location.pathname.slice(BASE.length) || '/'

export function navegar(caminho: string, substituir = false) {
  if (substituir) history.replaceState(null, '', href(caminho))
  else history.pushState(null, '', href(caminho))
  dispatchEvent(new PopStateEvent('popstate'))
}

export function useRota() {
  const [caminho, setCaminho] = useState(caminhoAtual)
  useEffect(() => {
    const atualizar = () => setCaminho(caminhoAtual())
    addEventListener('popstate', atualizar)
    return () => removeEventListener('popstate', atualizar)
  }, [])
  return caminho
}
