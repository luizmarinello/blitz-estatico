import { useEffect, useState } from 'react'

// Roteamento por caminho (history API). Não é por hash porque o link de recuperação do Supabase
// volta com ?code=... na URL, e isso conflita com rotas em #.
export function navegar(caminho: string, substituir = false) {
  if (substituir) history.replaceState(null, '', caminho)
  else history.pushState(null, '', caminho)
  dispatchEvent(new PopStateEvent('popstate'))
}

export function useRota() {
  const [caminho, setCaminho] = useState(location.pathname)
  useEffect(() => {
    const atualizar = () => setCaminho(location.pathname)
    addEventListener('popstate', atualizar)
    return () => removeEventListener('popstate', atualizar)
  }, [])
  return caminho
}
