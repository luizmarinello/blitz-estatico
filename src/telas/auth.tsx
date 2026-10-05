// Telas 02 Login, 03 Cadastro (com aceite), 04 Recuperação de senha e Termos.
// UC01 (inclui Aceitar Termos e Política), RF01–RF04, RF-LGPD01, RF-LGPD02.
import { useState, type FormEvent } from 'react'
import { supabase } from '../lib/supabase'
import { mensagemDeErro } from '../lib/erros'
import { navegar } from '../lib/rota'
import { Aviso, Botao, Campo, CartaoAuth, Link } from '../ui/componentes'

export const VERSAO_POLITICA = '1.0'   // a versão gravada vem do banco; esta só é exibida e precisa acompanhar

function dadosDo(e: FormEvent<HTMLFormElement>) {
  e.preventDefault()
  return Object.fromEntries(new FormData(e.currentTarget)) as Record<string, string>
}

export function Login() {
  const [erro, setErro] = useState('')
  const [carregando, setCarregando] = useState(false)

  async function entrar(e: FormEvent<HTMLFormElement>) {
    const d = dadosDo(e)
    setCarregando(true)
    const { error } = await supabase.auth.signInWithPassword({ email: d.email.trim(), password: d.senha })
    setCarregando(false)
    if (error) setErro(mensagemDeErro(error))
    // sucesso: o App percebe a sessão nova e leva ao painel
  }

  return (
    <CartaoAuth titulo="Entrar" subtitulo="O aplicativo que decide com você o que fazer agora.">
      <form onSubmit={entrar} noValidate>
        <Aviso tipo="erro">{erro}</Aviso>
        <Campo rotulo="E-mail" name="email" type="email" autoComplete="email" required autoFocus />
        <Campo rotulo="Senha" name="senha" type="password" autoComplete="current-password" required />
        <Botao type="submit" carregando={carregando}>Entrar</Botao>
      </form>
      <p className="mt-4 text-center"><Link para="/recuperar">Esqueci minha senha</Link></p>
      <p className="mt-2 text-center text-text">Ainda não tem conta? <Link para="/cadastro">Criar conta</Link></p>
    </CartaoAuth>
  )
}

export function Cadastro() {
  const [erros, setErros] = useState<Record<string, string>>({})
  const [carregando, setCarregando] = useState(false)
  const [enviadoPara, setEnviadoPara] = useState('')

  async function cadastrar(e: FormEvent<HTMLFormElement>) {
    const d = dadosDo(e)
    const aceita = d.aceitaTermos === 'on'
    const novos: Record<string, string> = {}
    if (!d.nome.trim()) novos.nome = 'Informe seu nome.'
    if (!/^\S+@\S+\.\S+$/.test(d.email.trim())) novos.email = 'Informe um e-mail válido.'
    if (d.senha.length < 8) novos.senha = 'A senha precisa ter pelo menos 8 caracteres.'
    if (!aceita) novos.aceite = 'É preciso aceitar os Termos de Uso e a Política de Privacidade.'
    setErros(novos)
    if (Object.keys(novos).length) {
      // RA02: leva o foco ao primeiro campo com erro, para quem navega por teclado ou leitor de tela
      const form = e.currentTarget
      return requestAnimationFrame(() => form.querySelector<HTMLElement>('[aria-invalid="true"]')?.focus())
    }

    setCarregando(true)
    const { data, error } = await supabase.auth.signUp({
      email: d.email.trim(),
      password: d.senha,
      // aceita_termos é conferido de novo pelo gatilho do banco: sem ele, a conta não é criada
      options: { data: { nome: d.nome.trim(), aceita_termos: true }, emailRedirectTo: location.origin },
    })
    setCarregando(false)
    if (error) return setErros({ geral: mensagemDeErro(error) })
    // Com confirmação de e-mail ligada não há sessão ainda. Mesma mensagem para e-mail novo ou já cadastrado,
    // para não revelar quem tem conta.
    if (!data.session) setEnviadoPara(d.email.trim())
  }

  if (enviadoPara) {
    return (
      <CartaoAuth titulo="Confirme seu e-mail">
        <Aviso tipo="ok">Enviamos um link de confirmação para <strong>{enviadoPara}</strong>. Abra-o para ativar a conta.</Aviso>
        <p className="text-text-muted">Não chegou? Confira a caixa de spam.</p>
        <p className="mt-4 text-center"><Link para="/login">Ir para o login</Link></p>
      </CartaoAuth>
    )
  }

  return (
    <CartaoAuth titulo="Criar conta">
      <form onSubmit={cadastrar} noValidate>
        <Aviso tipo="erro">{erros.geral}</Aviso>
        <Campo rotulo="Nome" name="nome" autoComplete="name" required maxLength={180} erro={erros.nome} autoFocus />
        <Campo rotulo="E-mail" name="email" type="email" autoComplete="email" required erro={erros.email} />
        <Campo rotulo="Senha" dica="Mínimo de 8 caracteres." name="senha" type="password" autoComplete="new-password" required minLength={8} erro={erros.senha} />

        {/* RF-LGPD01: consentimento explícito, sem pré-marcação. */}
        <div className="mb-1 flex items-start gap-2">
          <input id="aceitaTermos" name="aceitaTermos" type="checkbox" className="mt-1 size-5 accent-primary"
                 aria-invalid={erros.aceite ? true : undefined} aria-describedby={erros.aceite ? 'aceite-erro' : undefined} />
          <label htmlFor="aceitaTermos" className="text-text">
            Li e aceito os <a href="/termos" target="_blank" className="text-primary underline">Termos de Uso e a Política de Privacidade<span className="sr-only"> (abre em nova aba)</span></a> (versão {VERSAO_POLITICA}).
            Registramos data, hora e versão deste aceite.
          </label>
        </div>
        {erros.aceite && <p id="aceite-erro" className="mb-3 text-sm text-danger">⚠ {erros.aceite}</p>}

        {/* RF-LGPD02: finalidade e base legal à vista antes do aceite. */}
        <details className="my-4 text-sm text-text-muted">
          <summary className="cursor-pointer text-text">Como usamos seus dados</summary>
          <p className="mt-2">
            <strong>Finalidade:</strong> prestar o serviço Blitz (tarefas, sessões de foco e assistente de IA).{' '}
            <strong>Base legal:</strong> execução de contrato e consentimento (art. 7º, I e V, LGPD).{' '}
            <strong>IA:</strong> enviamos ao provedor apenas título, prioridade, prazo e horas das tarefas; nunca seu nome, e-mail ou identificador.{' '}
            <strong>Seus direitos:</strong> acessar, corrigir, exportar e excluir seus dados em Privacidade e dados.
          </p>
        </details>

        <Botao type="submit" carregando={carregando}>Criar conta</Botao>
      </form>
      <p className="mt-4 text-center text-text">Já tem conta? <Link para="/login">Entrar</Link></p>
    </CartaoAuth>
  )
}

// RF03 passo 1: pedir o link. A resposta é a mesma exista ou não a conta.
export function Recuperar() {
  const [erro, setErro] = useState('')
  const [carregando, setCarregando] = useState(false)
  const [enviado, setEnviado] = useState(false)

  async function enviar(e: FormEvent<HTMLFormElement>) {
    const d = dadosDo(e)
    if (!/^\S+@\S+\.\S+$/.test(d.email.trim())) return setErro('Informe um e-mail válido.')
    setCarregando(true)
    const { error } = await supabase.auth.resetPasswordForEmail(d.email.trim(), { redirectTo: `${location.origin}/redefinir` })
    setCarregando(false)
    if (error) return setErro(mensagemDeErro(error))
    setEnviado(true)
  }

  if (enviado) {
    return (
      <CartaoAuth titulo="Verifique seu e-mail">
        <Aviso tipo="ok">Se houver uma conta com este e-mail, enviamos um link para criar uma nova senha.</Aviso>
        <p className="text-text-muted">Abra o link <strong>neste mesmo navegador</strong>. Não chegou? Confira o spam ou peça outro em alguns minutos.</p>
        <p className="mt-4 text-center"><Link para="/login">Voltar para o login</Link></p>
      </CartaoAuth>
    )
  }

  return (
    <CartaoAuth titulo="Recuperar senha" subtitulo="Informe o e-mail da conta para receber o link.">
      <form onSubmit={enviar} noValidate>
        <Aviso tipo="erro">{erro}</Aviso>
        <Campo rotulo="E-mail" name="email" type="email" autoComplete="email" required autoFocus />
        <Botao type="submit" carregando={carregando}>Enviar link</Botao>
      </form>
      <p className="mt-4 text-center"><Link para="/login">Voltar para o login</Link></p>
    </CartaoAuth>
  )
}

// RF03 passo 2: chegou pelo link do e-mail; o Supabase já abriu uma sessão temporária de recuperação.
export function Redefinir() {
  const [erro, setErro] = useState('')
  const [carregando, setCarregando] = useState(false)

  async function salvar(e: FormEvent<HTMLFormElement>) {
    const d = dadosDo(e)
    if (d.novaSenha.length < 8) return setErro('A senha precisa ter pelo menos 8 caracteres.')
    setCarregando(true)
    const { error } = await supabase.auth.updateUser({ password: d.novaSenha })
    setCarregando(false)
    if (error) return setErro(mensagemDeErro(error))
    navegar('/', true)
  }

  return (
    <CartaoAuth titulo="Nova senha">
      <form onSubmit={salvar} noValidate>
        <Aviso tipo="erro">{erro}</Aviso>
        <Campo rotulo="Nova senha" dica="Mínimo de 8 caracteres." name="novaSenha" type="password" autoComplete="new-password" required minLength={8} autoFocus />
        <Botao type="submit" carregando={carregando}>Salvar nova senha</Botao>
      </form>
    </CartaoAuth>
  )
}

export function Termos() {
  return (
    <main className="min-h-screen bg-bg px-4 py-8">
      <article className="mx-auto max-w-3xl space-y-4 text-text">
        <h1 className="font-titulo text-3xl font-bold">Termos de Uso e Política de Privacidade</h1>
        <p className="text-sm text-text-muted">Versão {VERSAO_POLITICA}. Minuta elaborada pela equipe T03N para o protótipo acadêmico Blitz; não substitui revisão jurídica.</p>
        <h2 className="font-titulo text-xl font-bold">1. O que é o Blitz</h2>
        <p>Ferramenta de organização de tarefas e sustentação do foco, com assistente de IA que ajuda a decidir a ordem de execução. Protótipo de Trabalho de Conclusão de Curso, sem garantia de disponibilidade contínua.</p>
        <h2 className="font-titulo text-xl font-bold">2. Dados tratados e finalidade</h2>
        <p>Nome e e-mail (identificação e acesso à conta); tarefas, listas e sessões de foco (prestação do serviço e métricas pessoais); mensagens ao assistente (geração de respostas); preferências de acessibilidade (adaptação da interface).</p>
        <h2 className="font-titulo text-xl font-bold">3. Base legal</h2>
        <p>Execução de contrato (art. 7º, V) e consentimento (art. 7º, I) da Lei 13.709/2018. O aceite é registrado com data, hora e versão desta política.</p>
        <h2 className="font-titulo text-xl font-bold">4. Assistente de IA</h2>
        <p>As mensagens são processadas por um provedor externo (Google Gemini) por meio do servidor do Blitz. Enviamos somente título, prioridade, prazo, horas estimadas e status das tarefas. Nunca enviamos nome, e-mail ou identificador da conta. Há um limite diário de uso por pessoa.</p>
        <h2 className="font-titulo text-xl font-bold">5. Seus direitos (art. 18)</h2>
        <p>Você pode acessar, corrigir, exportar (JSON e CSV) e excluir seus dados na tela Privacidade e dados. A exclusão anonimiza a conta e apaga tarefas, listas e conversas; o tempo de foco permanece de forma desvinculada, apenas para métricas.</p>
        <h2 className="font-titulo text-xl font-bold">6. Segurança</h2>
        <p>Senhas são armazenadas com hash. Os dados trafegam por HTTPS.</p>
        <p className="pt-4"><Link para="/">Voltar ao Blitz</Link></p>
      </article>
    </main>
  )
}
