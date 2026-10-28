# Ambiente Docker Compose: PEC e-SUS + PostgreSQL

Ambiente local com o **PEC e-SUS APS** e um **PostgreSQL 12**, rodando via Docker Compose no WSL2.

## Serviços

| Serviço | Imagem | Porta no host | Observação |
|---------|--------|---------------|------------|
| `db`    | `postgres:12` | não exposta (só `5432` interna) | Banco `esus`, usuário `postgres`, senha `esus123` |
| `pec`   | build local (`dockercomposepecesus-pec`) | `443` -> `8443` do container (HTTPS) | Sobe o `pec-bundle.jar` via `/entrypoint.sh` |

> Ajuste as credenciais acima se você alterou o `docker-compose.yml`.
> Em qualquer ambiente fora do seu computador, troque a senha `esus123`.

## Requisitos

- Windows 10/11 com **WSL2** e uma distro Linux (Ubuntu, por exemplo)
- **Docker Desktop** com integração com o WSL2 ativada (ou Docker Engine dentro do WSL)
- **OpenSSL** (já vem no Ubuntu; confira com `openssl version`)
- Pelo menos **8 GB de RAM** livres para o WSL (o PEC usa ~3 GB, podendo chegar a 4 GB de heap)
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

## Estrutura esperada do projeto

```
DockerComposePecEsus/
├── docker-compose.yml
├── Dockerfile            # imagem do PEC
├── entrypoint.sh         # script de entrada do PEC
├── certs/                # certificado HTTPS (gerado no passo abaixo)
│   ├── pec.crt
│   ├── pec.key
│   └── pec.p12
└── README.md
```

> A estrutura pode variar. Os nomes acima são a convenção usada neste README.

## 1. Gerar o certificado HTTPS

O PEC responde em HTTPS (porta 8443 no container). Há duas formas de gerar o certificado.

### Opção A: autoassinado com OpenSSL (simples)

O navegador vai exibir um aviso de segurança na primeira visita, que pode ser ignorado em ambiente local.

```bash
mkdir -p certs && cd certs

# Chave privada + certificado (válido por ~2 anos) para localhost
openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout pec.key -out pec.crt \
  -days 730 \
  -subj "/CN=localhost" \
  -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"

# Keystore PKCS12 (formato aceito por aplicações Java)
openssl pkcs12 -export \
  -in pec.crt -inkey pec.key \
  -out pec.p12 -name pec \
  -passout pass:changeit

cd ..
```

Resultado: `pec.crt`, `pec.key` e `pec.p12` (senha do keystore: `changeit`).

### Opção B: com `mkcert` (sem aviso no navegador)

O `mkcert` cria uma autoridade certificadora local e confiável no seu sistema.

No **Windows** (PowerShell, uma vez):

```powershell
winget install FiloSottile.mkcert
mkcert -install
```

Depois, gere o certificado (no Windows, na pasta do projeto, para o navegador do Windows confiar):

```powershell
mkdir certs
cd certs
mkcert -cert-file pec.crt -key-file pec.key localhost 127.0.0.1 ::1
```

Converta para PKCS12 (no WSL, dentro da pasta `certs`):

```bash
openssl pkcs12 -export -in pec.crt -inkey pec.key -out pec.p12 -name pec -passout pass:changeit
```

## 2. Disponibilizar o certificado ao container

Monte a pasta `certs` no serviço `pec` do `docker-compose.yml`:

```yaml
services:
  pec:
    # ...
    ports:
      - "443:8443"
    volumes:
      - ./certs:/certs:ro
```

E aponte a configuração SSL do PEC para o keystore `/certs/pec.p12` (senha `changeit`, alias `pec`).
O local dessa configuração depende da versão do PEC e do seu `Dockerfile`/`entrypoint.sh`
(normalmente um arquivo de propriedades do `pec-bundle.jar` ou variáveis de ambiente lidas pelo entrypoint).
Confira onde o seu entrypoint lê o keystore e ajuste o caminho e a senha conforme necessário.

## 3. Subir o ambiente

Na pasta do projeto, dentro do WSL:

```bash
docker compose up -d --build
```

Para acompanhar:

```bash
docker compose ps
docker compose logs -f pec
```

> O `pec` imprime o banner do e-SUS e fica **bem silencioso** no log. Isso é normal.

### Verificar se já subiu

O **primeiro boot é lento (5 a 15 minutos)**: o PEC carrega o servidor de aplicação e executa as migrações do banco.
Teste a porta:

```bash
curl -k -s -o /dev/null -w "%{http_code}\n" https://localhost
```

- `000`: ainda subindo
- `200`, `302`, `404` ou qualquer código HTTP: está no ar

Para repetir a cada 30 segundos:

```bash
watch -n 30 'curl -k -s -o /dev/null -w "%{http_code}\n" https://localhost'
```

Confirme também que o processo Java está vivo:

```bash
docker compose exec pec ps aux | grep java
```

## 4. Acessar o PEC

Abra no navegador:

```
https://localhost
```

- Com certificado autoassinado (Opção A): clique em **Avançado -> Continuar para localhost**.
- Com `mkcert` (Opção B): abre sem aviso.

Se `localhost` não funcionar no Windows, pegue o IP do WSL com `hostname -I` e acesse `https://<IP>`.

## 5. Acessar o PostgreSQL

O PostgreSQL **não tem interface web** e, por padrão, **não está exposto ao host**.

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
docker compose down               # parar e remover containers (mantém dados)
docker compose down -v            # CUIDADO: remove também os volumes (apaga o banco)
docker compose up -d --build      # recriar a imagem do PEC após mudar o Dockerfile
```

## Solução de problemas

| Sintoma | Causa provável | O que fazer |
|---------|----------------|-------------|
| `https://localhost` não responde logo após o `up` | Boot do PEC ainda em andamento | Aguarde e use o `curl` da seção 3 |
| Aviso "conexão não é particular" | Certificado autoassinado | Avançar no navegador ou usar `mkcert` |
| Erro de porta 443 ocupada | Outro programa usa a 443 no Windows | Mude para `"8443:8443"` e acesse `https://localhost:8443` |
| PEC cai ou o WSL fica lento | Falta de memória | Aumente `memory` no `.wslconfig` |
| `syntax error near unexpected token 'newline'` | `<usuario>`/`<banco>` copiados literalmente | Troque pelos valores reais (`postgres` e `esus`) |
| Banner do e-SUS aparece duas vezes no log | Wrapper chamando o launcher | Normal, não é loop. Confira com `docker compose ps` |
| Erro de certificado/keystore no log | Caminho ou senha do `.p12` incorretos | Revise o volume `./certs:/certs` e a senha `changeit` |

### Ver os logs internos do PEC

O PEC grava logs em arquivo, não no stdout:

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