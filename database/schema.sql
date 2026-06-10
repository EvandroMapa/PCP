-- automatizacao
CREATE TABLE automatizacao (
    finalizacao_armacao_pedido jsonb,
    nao_mostrar_no_calendario jsonb,
    produzindo_cd_pedido jsonb,
    pronto_cd_pedido jsonb,
    aguardando_armacao_pedido jsonb,
    produzindo_armacao_pedido jsonb,
    criacao_pedido jsonb,
    produto_pedido_separado jsonb,
    pronto_armacao_pedido jsonb,
    remover_lista_prioridade jsonb,
    id text NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    PRIMARY KEY (id)
);

-- checklists
CREATE TABLE checklists (
    id text NOT NULL,
    checklist jsonb DEFAULT '[]'::jsonb,
    created_at timestamp with time zone DEFAULT now(),
    is_padrao boolean NOT NULL DEFAULT false,
    nome text NOT NULL,
    PRIMARY KEY (id)
);

-- clientes
CREATE TABLE clientes (
    telefone text,
    codigo integer DEFAULT nextval('clientes_codigo_seq'::regclass),
    created_at text,
    id text NOT NULL,
    nome text NOT NULL,
    cnpj text,
    email text,
    PRIMARY KEY (id)
);

-- configs
CREATE TABLE configs (
    id bigint NOT NULL,
    key text NOT NULL,
    updated_at timestamp with time zone DEFAULT now(),
    value jsonb NOT NULL,
    PRIMARY KEY (id)
);

-- elemento_arquivos
CREATE TABLE elemento_arquivos (
    tamanho bigint,
    elemento_id text,
    nome text NOT NULL,
    url text NOT NULL,
    tipo text,
    extensao text,
    criado_em timestamp with time zone DEFAULT now(),
    id uuid NOT NULL DEFAULT uuid_generate_v4(),
    PRIMARY KEY (id)
);

-- elemento_posicoes
CREATE TABLE elemento_posicoes (
    peso_kg numeric NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    status text NOT NULL DEFAULT 'aguardando'::text,
    qtde integer DEFAULT 0,
    id text NOT NULL DEFAULT (gen_random_uuid())::text,
    elemento_id text NOT NULL,
    nome text NOT NULL,
    numero_os text NOT NULL,
    produto_id text NOT NULL,
    PRIMARY KEY (id)
);

-- elementos
CREATE TABLE elementos (
    status text DEFAULT 'aguardando'::text,
    nome text NOT NULL,
    pedido_id text NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    qtde_pronto integer NOT NULL DEFAULT 0,
    qtde integer DEFAULT 1,
    id text NOT NULL DEFAULT (gen_random_uuid())::text,
    PRIMARY KEY (id)
);

-- fabricantes
CREATE TABLE fabricantes (
    id text NOT NULL,
    nome text NOT NULL,
    PRIMARY KEY (id)
);

-- materia_prima
CREATE TABLE materia_prima (
    anexos jsonb,
    id text NOT NULL,
    produto_raw jsonb,
    status integer DEFAULT 0,
    fabricante_model_raw jsonb,
    corrida_lote text,
    PRIMARY KEY (id)
);

-- notificacoes
CREATE TABLE notificacoes (
    user_id text,
    payload text,
    created_at timestamp with time zone DEFAULT now(),
    viewed boolean DEFAULT false,
    id text NOT NULL,
    title text NOT NULL,
    description text,
    PRIMARY KEY (id)
);

-- obras
CREATE TABLE obras (
    cep text,
    nome text NOT NULL,
    numero text,
    logradouro text,
    status integer DEFAULT 0,
    uf text,
    cidade text,
    id text NOT NULL,
    cliente_id text,
    bairro text,
    created_at text,
    PRIMARY KEY (id)
);

-- ordens
CREATE TABLE ordens (
    produto_raw jsonb,
    freezed jsonb,
    is_archived boolean DEFAULT false,
    belt_index integer,
    materia_prima_raw jsonb,
    history jsonb,
    created_at timestamp with time zone DEFAULT now(),
    id text NOT NULL,
    updated_at timestamp with time zone DEFAULT now(),
    end_at timestamp with time zone,
    id_pedidos_produtos jsonb,
    PRIMARY KEY (id)
);

-- pedido_arquivos
CREATE TABLE pedido_arquivos (
    is_processed boolean DEFAULT false,
    tamanho bigint,
    criado_em timestamp with time zone DEFAULT now(),
    pedido_id text,
    id text NOT NULL DEFAULT (gen_random_uuid())::text,
    nome text NOT NULL,
    url text NOT NULL,
    tipo text,
    extensao text,
    PRIMARY KEY (id)
);

-- pedido_checks
CREATE TABLE pedido_checks (
    checks_raw jsonb,
    pedido_id text NOT NULL,
    checklist_id text,
    id text NOT NULL DEFAULT (gen_random_uuid())::text,
    created_at timestamp with time zone DEFAULT now(),
    PRIMARY KEY (id)
);

-- pedido_comments
CREATE TABLE pedido_comments (
    usuario_id text,
    comentario text,
    pedido_id text NOT NULL,
    id text NOT NULL DEFAULT (gen_random_uuid())::text,
    created_at timestamp with time zone DEFAULT now(),
    PRIMARY KEY (id)
);

-- pedido_produtos
CREATE TABLE pedido_produtos (
    pedido_id text,
    produto_id text,
    status text,
    qtde_original numeric,
    obra_id text,
    qtde double precision NOT NULL,
    created_at text,
    quantidade double precision DEFAULT 0,
    produto_raw jsonb DEFAULT '{}'::jsonb,
    materia_prima_raw jsonb,
    statusess_raw jsonb DEFAULT '[]'::jsonb,
    unidade text,
    valor_unitario numeric DEFAULT 0,
    valor_total numeric DEFAULT 0,
    id text NOT NULL,
    cliente_id text,
    id_id text,
    PRIMARY KEY (id)
);

-- pedido_status_history
CREATE TABLE pedido_status_history (
    pedido_id text NOT NULL,
    status text NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    id text NOT NULL DEFAULT (gen_random_uuid())::text,
    PRIMARY KEY (id)
);

-- pedido_steps_history
CREATE TABLE pedido_steps_history (
    created_at timestamp with time zone DEFAULT now(),
    id text NOT NULL DEFAULT (gen_random_uuid())::text,
    pedido_id text NOT NULL,
    step_id text NOT NULL,
    PRIMARY KEY (id)
);

-- pedido_tags
CREATE TABLE pedido_tags (
    tag_id text NOT NULL,
    pedido_id text NOT NULL,
    PRIMARY KEY (pedido_id, tag_id)
);

-- pedidos
CREATE TABLE pedidos (
    instrucoes_financeiras text,
    user_ids jsonb DEFAULT '[]'::jsonb,
    comments jsonb DEFAULT '[]'::jsonb,
    pedidos_filhos jsonb DEFAULT '[]'::jsonb,
    archives jsonb DEFAULT '[]'::jsonb,
    checks jsonb DEFAULT '[]'::jsonb,
    valor_total numeric DEFAULT 0,
    valor_desconto numeric DEFAULT 0,
    is_filho boolean DEFAULT false,
    valor_taxas numeric DEFAULT 0,
    valor_subtotal numeric DEFAULT 0,
    index integer,
    armacao_resumo jsonb DEFAULT '{}'::jsonb,
    is_archived boolean DEFAULT false,
    step_id text,
    cliente_id text,
    obra_id text,
    planilhamento text,
    pedido_financeiro text,
    instrucoes_entrega text,
    delivery_at text,
    pedidos_vinculados jsonb DEFAULT '[]'::jsonb,
    romaneio text,
    pai_id text,
    checklist_id text,
    created_at text,
    id text NOT NULL,
    localizador text,
    descricao text,
    tipo text,
    status text,
    PRIMARY KEY (id)
);

-- perfis
CREATE TABLE perfis (
    permitir_editar_elementos boolean DEFAULT false,
    id uuid NOT NULL DEFAULT uuid_generate_v4(),
    is_armador boolean DEFAULT false,
    is_operador boolean DEFAULT false,
    permitir_elementos boolean DEFAULT false,
    nome text NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    PRIMARY KEY (id)
);

-- produtos
CREATE TABLE produtos (
    codigo_financeiro text,
    id text NOT NULL,
    nome text NOT NULL,
    descricao text,
    sort_index integer DEFAULT 999,
    massa_final double precision DEFAULT 0.0,
    PRIMARY KEY (id)
);

-- step_from_steps
CREATE TABLE step_from_steps (
    step_id text NOT NULL,
    from_step_id text NOT NULL,
    PRIMARY KEY (step_id, from_step_id)
);

-- step_roles
CREATE TABLE step_roles (
    step_id text NOT NULL,
    perfil_id text NOT NULL,
    PRIMARY KEY (step_id, perfil_id)
);

-- steps
CREATE TABLE steps (
    is_arquivado_disponivel boolean DEFAULT false,
    is_permite_producao boolean DEFAULT false,
    considerar_consumo_relatorio_pedidos boolean DEFAULT true,
    exibir_armacao boolean DEFAULT false,
    is_entrega boolean DEFAULT false,
    is_padrao boolean DEFAULT false,
    cor bigint,
    aceita_sem_elementos boolean NOT NULL DEFAULT false,
    exibir_grafico_cda boolean DEFAULT false,
    created_at text,
    nome text NOT NULL,
    id text NOT NULL,
    index integer NOT NULL DEFAULT 0,
    dados_entrega jsonb DEFAULT '{}'::jsonb,
    aceita_sem_data_entrega boolean NOT NULL DEFAULT false,
    PRIMARY KEY (id)
);

-- tags
CREATE TABLE tags (
    is_default_cd boolean DEFAULT false,
    color bigint,
    nome text NOT NULL,
    id text NOT NULL,
    is_default_cda boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()),
    descricao text,
    cor text,
    PRIMARY KEY (id)
);

-- usuarios
CREATE TABLE usuarios (
    id text NOT NULL,
    email text,
    role text,
    foto_url text,
    created_at text,
    senha text,
    perfil_id uuid,
    usuario_tipo_id uuid,
    deviceTokens jsonb DEFAULT '[]'::jsonb,
    steps jsonb DEFAULT '[]'::jsonb,
    permission jsonb DEFAULT '{}'::jsonb,
    nome text NOT NULL,
    PRIMARY KEY (id)
);
