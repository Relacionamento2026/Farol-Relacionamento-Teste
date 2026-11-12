# Preparação da homologação TI — 12/11/2026

Base: `f39e94a413c1d5e7b9de7a5fd306db6db506f58c`, versão atual da branch main.

O usuário autorizou nesta data utilizar o projeto Farol - TESTE
(`tfqttlkvkwbvjynyrvfd`) e pausar o original (`pvorwgrpkcofoukbqtyg`).
Essa autorização substitui a antiga proibição de usar TESTE nos documentos históricos.

Esta branch conserva o layout e funcionalidades do código atual e configura
o cliente e adaptador de arquivos para o projeto TESTE. Usa apenas a chave pública
desse projeto; não contém senha da TI ou chave administrativa.

## Pendente antes de liberar

- Aguardar restauração do projeto e inspecionar schema, Auth, RLS, Storage e funções.
- Comparar schema com as funcionalidades atuais; não aplicar cegamente o fixture de testes.
- Verificar se existem dados reais no ambiente antigo antes de habilitar acesso da TI.
- Preparar dados fictícios e arquivos demonstrativos; nenhum dado de produção foi copiado.
- Verificar o endereço/frontend antigo de teste e separar a hospedagem da produção.
- Provisionar a conta pelo Auth oficial, confirmar autorização do e-mail corporativo
  e usar senha segura caso não seja comprovado isolamento completo de dados reais.
- Validar login, menus, permissões, operações administrativas e assistente de IA.
- Obter autorização de publicação. Não mesclar esta configuração na main de produção.

Esta preparação não é uma homologação funcional concluída nem um deploy.

## Verificação e aplicação em 12/11/2026

- TESTE confirmado ACTIVE_HEALTHY; original INACTIVE; Monitor Jurídico ativo.
- Contagens reais: 4 perfis demonstrativos, 2 administradoras demonstrativas,
  3 FAQs, 2 avisos, 1 avaliação, 1 celebração e 2 consultas; zero arquivos.
- Migration `ti_homologacao_schema` aplicada somente em TESTE: cria treinamentos
  UNIC e certificados, adiciona campos usados pelo frontend e fortalece Auth/RLS.
- Cadastro novo passa a user/pendente, sem confiar em role no user_metadata.
- Testes SQL de usuário, administrador e anônimo aprovados: dados privados
  protegidos, autoescalada bloqueada, escrita comum negada e escrita ADM permitida.
  Todas as escritas de teste foram revertidas por ROLLBACK.
- 29 testes locais do frontend/base passaram na preparação anterior.
- Alertas restantes: get_my_role é SECURITY DEFINER intencionalmente, limitado ao
  próprio auth.uid(), com search_path fixo; proteção de senha vazada desativada.
- Não há Edge Functions no TESTE; IA generativa ainda não foi implantada nem testada.
- A conta teste@canopus.com.br ainda não existe no TESTE. Provisionamento oficial
  depende de autenticação no painel; não inserir usuários diretamente em auth.users.
- Não houve deploy, push para main, cópia de dados do original ou nova senha aplicada.

## Conta única de avaliação

- Reutilizada conta Auth existente `teste.admin@canopus.com.br`, e-mail confirmado.
- Perfil ativo/admin preservado; nome atualizado para TI Canopus – Avaliação Técnica.
- Verificação SQL com identidade da conta confirmou admin e leitura de 4 perfis,
  3 FAQs e 2 administradoras. Isso não constitui teste de login por senha.
- Nenhuma senha alterada, usuário excluído ou publicação realizada.
- Busca de projetos Farol na conta Vercel conectada não retornou resultados.
  Endereço do frontend TESTE ainda precisa ser identificado.
