import type { AuthError } from '@supabase/supabase-js'

// RF04: mensagens de erro claras, em pt-BR (RNF07), que dizem o que fazer.
const porCodigo: Record<string, string> = {
  invalid_credentials: 'E-mail ou senha incorretos.',
  email_not_confirmed: 'Confirme seu e-mail antes de entrar. O link foi enviado no cadastro.',
  user_already_exists: 'Já existe uma conta com este e-mail. Tente entrar ou recuperar a senha.',
  weak_password: 'Senha fraca. Use pelo menos 8 caracteres, misturando letras e números.',
  same_password: 'A nova senha precisa ser diferente da atual.',
  over_email_send_rate_limit: 'Muitos e-mails enviados em pouco tempo. Aguarde alguns minutos e tente de novo.',
  over_request_rate_limit: 'Muitas tentativas. Aguarde alguns minutos e tente de novo.',
  validation_failed: 'Confira os dados informados.',
  // o gatilho do banco recusa cadastro sem aceite; o Supabase devolve isso como erro genérico
  unexpected_failure: 'Não foi possível criar a conta. Confira se aceitou os Termos e a Política de Privacidade.',
}

export function mensagemDeErro(erro: AuthError | Error | null): string {
  if (!erro) return ''
  const codigo = 'code' in erro ? erro.code : undefined
  if (codigo && porCodigo[codigo]) return porCodigo[codigo]
  if (/fetch|network/i.test(erro.message)) return 'Sem conexão com o servidor. Verifique sua internet e tente de novo.'
  return 'Não foi possível concluir. Tente novamente em instantes.'
}
