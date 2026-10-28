# Ambiente Docker Compose: PEC e-SUS + PostgreSQL

Ambiente local com o **PEC e-SUS APS** e um **PostgreSQL 12**, rodando via Docker Compose no WSL2.
A versão do PEC é escolhida pela variável `PEC_VERSION` no arquivo `.env`.

## Início rápido

Na pasta do projeto, dentro do WSL:

1. **Escolha a versão do PEC** criando o `.env`:

   ```bash
   cp .env.example .env      # edite PEC_VERSION se quiser outra versão
   ```

2. **Coloque o instalador do PEC** em `pec/`, com o nome exato `eSUS-AB-PEC-<PEC_VERSION>-Linux64.jar`.
   Por exemplo: `pec/eSUS-AB-PEC-5.5.28-Linux64.jar`.
   Baixe em <https://sisaps.saude.gov.br/esus/>. O `.jar` não é versionado no git.

3. **Gere o certificado HTTPS** em `certs/localhost.p12` (senha `changeit`):

   ```bash
   mkdir -p certs
   openssl req -x509 -newkey rsa:2048 -nodes \
     -keyout certs/localhost.key -out certs/localhost.crt \
     -days 730 -subj "/CN=localhost" \
     -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"
   openssl pkcs12 -export \
     -in certs/localhost.crt -inkey certs/localhost.key \
     -out certs/localhost.p12 -name localhost -passout pass:changeit
   ```

4. **Suba o ambiente:**

   ```bash
   docker compose up -d --build
   docker compose logs -f pec
   ```

5. Aguarde o primeiro boot (**5 a 15 minutos**) e acesse **<https://localhost>**.

Os detalhes de cada passo estão nas seções abaixo.

## Serviços

| Serviço | Imagem | Porta no host | Observação |
|---------|--------|---------------|------------|
| `db`    | `postgres:12` | não exposta (só `5432` interna) | Banco `esus`, usuário `postgres`, senha `esus123` |
| `pec`   | build local (`pec-esus:<PEC_VERSION>`) | `443` -> `8443` do container (HTTPS) | Instala o `.jar` na 1ª subida e roda o `standalone.sh` |

> Em qualquer ambiente fora do seu computador, troque a senha `esus123`.

## Requisitos

- Windows 10/11 com **WSL2** e uma distro Linux (Ubuntu, por exemplo)
- **Docker Desktop** com integração com o WSL2 ativada (ou Docker Engine dentro do WSL)
- **OpenSSL** (já vem no Ubuntu; confira com `openssl version`)
- Pelo menos **6 GB de RAM** livres para o WSL (o compose limita o PEC a 3 GB, com heap `-Xmx2g`, e o banco a 1 GB)
- Porta **443** livre no Windows (IIS, Skype, VPNs e outros serviços podem ocupá-la)

### Configurar memória do WSL

Crie ou edite `C:\Users\<seu_usuario>\.wslconfig`:

```ini
[wsl2]
memory=8GB
processors=4
```

Depois, no PowerShell:

```powershell
wsl --shutdown
```

## Estrutura do projeto

```
dockercomposepecesus/
├── docker-compose.yml
├── .env.example                          # modelo do .env (versionado)
├── .env                                  # você cria: PEC_VERSION (não versionado)
├── pec/
│   ├── Dockerfile
│   ├── entrypoint.sh                     # instala o PEC e configura o HTTPS
│   └── eSUS-AB-PEC-<versão>-Linux64.jar  # você coloca (não versionado)
└── certs/
    └── localhost.p12                     # você gera (não versionado)
```

## Escolher ou trocar a versão do PEC

A versão vem de `PEC_VERSION` no `.env`. O build copia `pec/eSUS-AB-PEC-${PEC_VERSION}-Linux64.jar`,
e a imagem recebe a tag `pec-esus:<versão>`.

Para usar uma versão diferente só uma vez, sem editar o `.env`:

```bash
PEC_VERSION=5.5.30 docker compose up -d --build            # bash/WSL
```

```powershell
$env:PEC_VERSION="5.5.30"; docker compose up -d --build    # PowerShell
```

### Trocar a versão de uma instalação existente

O PEC é instalado **só na primeira subida**, e a instalação fica guardada no volume `pec_data`.
Se você pedir uma versão diferente da que está instalada, o container para com erro de propósito.
Para reinstalar:

```bash
# 1. coloque o novo .jar em pec/ e ajuste PEC_VERSION no .env
docker compose down
docker volume rm dockercomposepecesus_pec_data   # remove só a instalação do PEC; o banco (db_data) é mantido
docker compose up -d --build
```

> Confira o nome do volume com `docker volume ls`. O prefixo é o nome da pasta do projeto.
> Confira também se a nova versão do PEC é compatível com o PostgreSQL usado no `docker-compose.yml`.

## Certificado HTTPS

O PEC responde em HTTPS (porta 8443 no container). O `docker-compose.yml` já monta `./certs` em `/certs`,
e o `entrypoint.sh` já configura o PEC para usar `/certs/localhost.p12` com a senha `changeit`.
**Basta gerar o arquivo com esse nome.**

### Opção A: autoassinado com OpenSSL (simples)

É o comando do [Início rápido](#início-rápido). O navegador exibe um aviso de segurança na primeira visita,
que pode ser ignorado em ambiente local.

### Opção B: com `mkcert` (sem aviso no navegador)

O `mkcert` cria uma autoridade certificadora local, confiável no seu sistema.

No **Windows** (PowerShell, uma vez só):

```powershell
winget install FiloSottile.mkcert
mkcert -install
```

Gere o certificado no Windows, na pasta do projeto, para que o navegador do Windows confie nele:

```powershell
mkdir certs
mkcert -cert-file certs/localhost.crt -key-file certs/localhost.key localhost 127.0.0.1 ::1
```

Converta para PKCS12 no WSL, na pasta do projeto:

```bash
openssl pkcs12 -export -in certs/localhost.crt -inkey certs/localhost.key \
  -out certs/localhost.p12 -name localhost -passout pass:changeit
```

## Subir e verificar

```bash
docker compose up -d --build
docker compose ps
docker compose logs -f pec
```

> O `pec` imprime o banner do e-SUS e fica **bem silencioso** no log. Isso é normal.

O **primeiro boot é lento (5 a 15 minutos)**: o PEC instala, carrega o servidor de aplicação e executa as migrações do banco.
Para testar a porta:

```bash
curl -k -s -o /dev/null -w "%{http_code}\n" https://localhost
```

- `000`: ainda subindo
- `200`, `302`, `404` ou qualquer outro código HTTP: está no ar

Para repetir a cada 30 segundos:

```bash
watch -n 30 'curl -k -s -o /dev/null -w "%{http_code}\n" https://localhost'
```

Para confirmar que o processo Java está vivo:

```bash
docker compose exec pec ps aux | grep java
```

## Acessar o PEC

Abra no navegador:

```
https://localhost
```

- Com certificado autoassinado (Opção A): clique em **Avançado -> Continuar para localhost**.
- Com `mkcert` (Opção B): abre sem aviso.

Se `localhost` não funcionar no Windows, pegue o IP do WSL com `hostname -I` e acesse `https://<IP>`.

## Acessar o PostgreSQL

O PostgreSQL **não tem interface web** e, por padrão, **não fica exposto ao host**.

### Pelo terminal (sem alterar nada)

```bash
docker compose exec db psql -U postgres -d esus
```

Comandos úteis dentro do `psql`: `\dt` (listar tabelas), `\l` (bancos), `\q` (sair).

Para conferir as variáveis do banco:

```bash
docker compose exec db env | grep POSTGRES
```

### Por cliente gráfico (DBeaver, pgAdmin, DataGrip)

Exponha a porta no serviço `db` do `docker-compose.yml`:

```yaml
  db:
    image: postgres:12
    ports:
      - "5433:5432"   # 5433 no host para não conflitar com um Postgres local
```

Aplique com `docker compose up -d` e conecte em:

| Campo | Valor |
|-------|-------|
| Host | `localhost` |
| Porta | `5433` |
| Banco | `esus` |
| Usuário | `postgres` |
| Senha | `esus123` |

### Pelo navegador (Adminer)

Adicione ao `docker-compose.yml`:

```yaml
  adminer:
    image: adminer
    ports:
      - "8081:8080"
    depends_on:
      - db
```

Acesse `http://localhost:8081` e preencha:

- Sistema: **PostgreSQL**
- Servidor: **db** (nome do serviço na rede do compose)
- Usuário: `postgres` | Senha: `esus123` | Base: `esus`

## Comandos do dia a dia

```bash
docker compose up -d              # subir em segundo plano
docker compose ps                 # status e portas
docker compose logs -f pec        # log do PEC
docker compose logs -f db         # log do banco
docker compose restart pec        # reiniciar só o PEC
docker compose stop               # parar sem remover
docker compose down               # parar e remover os containers (mantém os dados)
docker compose down -v            # CUIDADO: remove também os volumes (apaga o banco e a instalação do PEC)
docker compose up -d --build      # recriar a imagem do PEC após mudar o Dockerfile ou a versão
```

## Solução de problemas

| Sintoma | Causa provável | O que fazer |
|---------|----------------|-------------|
| `required variable PEC_VERSION is missing a value` | `.env` não existe | `cp .env.example .env` |
| Build falha no `COPY eSUS-AB-PEC-...-Linux64.jar` | `.jar` ausente ou com nome diferente em `pec/` | Confira se o nome bate exatamente com `PEC_VERSION` |
| `ERRO: o volume pec_data tem o PEC X instalado...` | Versão no `.env` diferente da instalada | Volte a versão ou reinstale (veja [Trocar a versão](#trocar-a-versão-de-uma-instalação-existente)) |
| Erro de certificado/keystore no log | Arquivo não está em `certs/localhost.p12` ou a senha não é `changeit` | Gere de novo com o comando do Início rápido |
| `https://localhost` não responde logo após o `up` | Boot do PEC ainda em andamento | Aguarde e use o `curl` da seção "Subir e verificar" |
| Aviso "conexão não é particular" | Certificado autoassinado | Avance no navegador ou use o `mkcert` |
| Erro de porta 443 ocupada | Outro programa usa a 443 no Windows | Mude para `"8443:8443"` e acesse `https://localhost:8443` |
| PEC cai ou o WSL fica lento | Falta de memória | Aumente `memory` no `.wslconfig` |
| Banner do e-SUS aparece duas vezes no log | Wrapper chamando o launcher | É normal, não é loop. Confira com `docker compose ps` |

### Ver os logs internos do PEC

O PEC grava os logs em arquivo, não no stdout:

```bash
docker compose exec pec find /opt/e-SUS -name "*.log"
docker compose exec pec bash -c 'tail -n 50 /opt/e-SUS/webserver/logs/*.log'
```

## Backup e restauração do banco

```bash
# Backup
docker compose exec -T db pg_dump -U postgres esus > backup_esus.sql

# Restauração
docker compose exec -T db psql -U postgres -d esus < backup_esus.sql
```
