# 🛡️ Manual de Backups - AçoPlus (Supabase)

Este guia descreve os procedimentos para garantir a segurança e a integridade da estrutura do banco de dados do projeto PCP.

---

## 1. Recuperação em Tempo Real (PITR)
**Uso:** Casos de desastre, erro humano ou exclusão acidental de dados.

O plano **Pro** permite restaurar o banco para qualquer segundo específico nos últimos 7 dias.

### Como usar:
1. Acesse o **Dashboard do Supabase**.
2. Vá em **Settings** -> **Database**.
3. Role até a seção **Backups**.
4. Clique em **Restore** e selecione o ponto exato no tempo (Data e Hora) para o qual deseja retornar.

> [!IMPORTANT]
> A restauração criará uma nova instância do banco. Verifique se o PITR está **Ativo** no painel para ter essa segurança.

---

## 2. Backup Local da Estrutura (Git)
**Uso:** Versionamento da "planta baixa" do banco e reconstrução manual do sistema.

Sempre que houver mudanças na estrutura (novas tabelas, colunas ou regras), atualize o arquivo local.

### Como atualizar o backup:
1. No Supabase, vá em **SQL Editor**.
2. Execute o comando de exportação de schema (o script guardado em `database/backup_schema.ps1` possui a referência, mas como o Docker não está instalado, use o comando SQL manual).
3. **Comando SQL de Extração:**
   ```sql
   SELECT 
       '-- ' || table_name || chr(10) ||
       'CREATE TABLE ' || table_name || ' (' || chr(10) ||
       string_agg(
           '    ' || column_name || ' ' || data_type || 
           CASE WHEN is_nullable = 'NO' THEN ' NOT NULL' ELSE '' END ||
           CASE WHEN column_default IS NOT NULL THEN ' DEFAULT ' || column_default ELSE '' END,
           ',' || chr(10)
       ) || 
       CASE 
           WHEN (SELECT string_agg('    PRIMARY KEY (' || column_name || ')', '') 
                 FROM information_schema.key_column_usage 
                 WHERE table_name = t.table_name AND constraint_name LIKE '%_pkey') IS NOT NULL 
           THEN ',' || chr(10) || (SELECT string_agg('    PRIMARY KEY (' || column_name || ')', '') 
                                   FROM information_schema.key_column_usage 
                                   WHERE table_name = t.table_name AND constraint_name LIKE '%_pkey')
           ELSE ''
       END ||
       chr(10) || ');' || chr(10)
   FROM 
       information_schema.columns t
   WHERE 
       table_schema = 'public'
   GROUP BY 
       table_name;
   ```
4. Clique em **Export** -> **CSV** ou copie os resultados.
5. Cole no arquivo: `database/schema.sql`.
6. Faça o **Commit** no Git.

---

## 3. Contatos e Emergência
- **Plataforma:** [supabase.com](https://supabase.com)
- **Projeto:** PCP (aumfedyfrxuwgkdhwrel)
- **Arquivos Locais:** Pasta `/database`

---
*Gerado em 21 de Abril de 2026*
