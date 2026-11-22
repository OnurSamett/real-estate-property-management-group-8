# Real Estate Property Management System — CMPE341 Group 8

A Python Flask web application on a PostgreSQL 16 database for managing properties,
owners, agents, tenants, lease/sale agreements and payments. The whole system runs with
Docker Compose.

## Run It (single command)

Requirements: Docker with Docker Compose.

```bash
git clone https://github.com/OnurSamett/real-estate-property-management-group-8.git
cd real-estate-property-management-group-8
docker compose up
```

Then open **http://localhost:8080**.

`docker compose up` builds the web app, starts PostgreSQL, creates all tables and loads the
sample data from `init.sql`, and starts the web app once the database is ready.

> `init.sql` runs only when the database volume is first created. To reset the database to
> the sample data: `docker compose down -v && docker compose up`

## Test Accounts and Roles

| Role | Username | Password | Permissions |
| :--- | :--- | :--- | :--- |
| Admin | `admin` | `admin123` | View, insert, update and **delete** properties |
| Agent (standard user) | `agent1` | `agent123` | View, insert and update properties (no delete) |
| Agent (standard user) | `agent2` | `agent123` | View, insert and update properties (no delete) |

Passwords are stored as bcrypt hashes in the `Users` table; plain-text passwords are never stored.

## Features

- **Authentication:** username/password login with bcrypt-hashed passwords.
- **Authorization:** two roles. Only `admin` can delete; the delete button is hidden for agents
  and the server also rejects the request.
- **Insert / Update / Delete** on the `Property` relation. Owners and agents are chosen from
  existing rows, so foreign keys are always valid.
- Database constraint errors (CHECK, `ON DELETE RESTRICT`) are shown as messages instead of
  crashing the app.

## Database

`init.sql` contains the schema, sample data and the three report queries (report Chapter 5):
`Owner`, `Agent`, `Tenant`, `Property`, `Lease_agreement`, `Payment`, `Owner_contact`,
`Agent_contact`, `Tenant_contact`, plus the `Users` table for application logins.

PostgreSQL is published only on `127.0.0.1:5432` (user `postgres`, database `realestate_db`),
so it can be opened with DBeaver on the same machine but is not reachable from the internet.

## Deployment (Linux cloud server)

On an Ubuntu virtual machine with a public IP:

```bash
git clone https://github.com/OnurSamett/real-estate-property-management-group-8.git && cd real-estate-property-management-group-8
sudo bash deploy/setup-server.sh
```

The script installs Docker, opens port 80 in the server firewall and starts the app with
`APP_PORT=80`, so it opens at `http://<SERVER_IP>`. Port 80 (HTTP) must also be allowed in the
cloud provider's network rules (security group / network security group).

### With a domain and HTTPS

1. Add a DNS `A` record that points the domain (e.g. `cmpe341.example.com`) to the server IP.
2. Allow ports 80 and 443 in the cloud provider's network rules.
3. Run the script with the domain:

```bash
sudo DOMAIN=cmpe341.example.com bash deploy/setup-server.sh
```

A Caddy reverse proxy (`docker-compose.https.yml`, `deploy/Caddyfile`) then serves
`https://<DOMAIN>` with a free Let's Encrypt certificate, and `http://<SERVER_IP>` keeps working.

Optional environment variables (put them in a `.env` file next to `docker-compose.yml`):

| Variable | Default | Purpose |
| :--- | :--- | :--- |
| `APP_PORT` | `8080` | Host port of the web app (`80` on the server) |
| `DB_PASSWORD` | `adminpassword123` | PostgreSQL password |
| `SECRET_KEY` | development value | Flask session signing key — set a random value on the server |

## Project Structure

```
app.py               Flask routes (login, list, insert, update, delete)
templates/           HTML pages (Bootstrap 5)
init.sql             Schema, constraints, sample data and report queries
Dockerfile           Web app image
docker-compose.yml   Database + web app
docker-compose.https.yml  Optional Caddy HTTPS proxy for a domain
deploy/              Server setup script and Caddyfile
```
