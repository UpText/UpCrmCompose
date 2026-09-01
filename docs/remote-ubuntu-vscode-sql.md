# Remote Ubuntu VS Code And SQL Server Setup

Use this guide when a new remote Ubuntu server is available and you want to work with `UpCrmCompose` from VS Code over SSH, run the stack with Docker, then connect VS Code to the SQL Server running on that server.

Replace these placeholders as needed:

- `ubuntu-user`: the Linux user on the Ubuntu server
- `server.example.com`: the server DNS name or public IP address
- `~/UpCrmCompose`: the target directory on the remote server

## 1. Set Up SSH

On your local machine, create an SSH key if you do not already have one:

```bash
ssh-keygen -t ed25519 -C "your-email@example.com"
```

Copy the public key to the Ubuntu server:

```bash
ssh-copy-id ubuntu-user@server.example.com
```

If `ssh-copy-id` is not available, print your public key locally:

```bash
cat ~/.ssh/id_ed25519.pub
```

Then add that value to this file on the Ubuntu server:

```bash
~/.ssh/authorized_keys
```

Test the connection:

```bash
ssh ubuntu-user@server.example.com
```

Optional but recommended: add a named host to your local SSH config:

```sshconfig
Host upcrm-ubuntu
  HostName server.example.com
  User ubuntu-user
  IdentityFile ~/.ssh/id_ed25519
```

After that, test with:

```bash
ssh upcrm-ubuntu
```

## 2. Connect VS Code To The Server

Install the VS Code extension:

```text
Remote - SSH
```

In VS Code:

1. Open the Command Palette.
2. Run `Remote-SSH: Connect to Host...`.
3. Select `upcrm-ubuntu`, or enter `ubuntu-user@server.example.com`.
4. Wait until the bottom-left corner shows `SSH: upcrm-ubuntu` or the server name.

Open a remote terminal in VS Code:

```text
Terminal: Create New Terminal
```

Commands in that terminal now run on the Ubuntu server.

## 3. Install Docker

In the VS Code remote terminal, install Docker Engine on the Ubuntu server:

```bash
sudo apt update
sudo apt install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
```

Add the Docker apt repository:

```bash
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF
```

Install Docker and the Compose plugin:

```bash
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

Allow your Linux user to run Docker without `sudo`:

```bash
sudo usermod -aG docker "$USER"
```

Sign out of the SSH session and reconnect so the new group membership is active:

```bash
exit
ssh upcrm-ubuntu
```

If you did not create the `upcrm-ubuntu` SSH alias, reconnect with:

```bash
ssh ubuntu-user@server.example.com
```

Verify Docker:

```bash
docker --version
docker compose version
docker run hello-world
```

## 4. Download UpCrmCompose With Git

In the VS Code remote terminal, install Git if needed:

```bash
sudo apt update
sudo apt install -y git
```

Clone the repository:

```bash
git clone git@github.com:UpText/UpCrmCompose.git ~/UpCrmCompose
```

If the remote server does not have GitHub SSH access configured, use HTTPS instead:

```bash
git clone https://github.com/UpText/UpCrmCompose.git ~/UpCrmCompose
```

Open the cloned folder in VS Code:

```text
File: Open Folder...
```

Choose:

```text
~/UpCrmCompose
```

Create the environment file:

```bash
cd ~/UpCrmCompose
cp .env.example .env
```

Edit `.env` and set at least:

```env
MSSQL_SA_PASSWORD=YourStrongSqlPassword123!
ADMIN_TENANT_PASSWORD=YourAdminTenantPassword123!
UPAPI_SQL_PASSWORD=YourServiceSqlPassword123!
JWT_SECRET=YourLongRandomJwtSecretHere
```

Start the stack when Docker is available on the server:

```bash
docker compose up --build -d
docker compose ps
```

SQL Server should be reachable on the Ubuntu host at:

```text
localhost,1433
```

If `.env` uses a custom `SQL_PORT`, use that port instead.

## 5. Add The Remote SQL Server Plugin To VS Code

While connected to the Ubuntu server with Remote SSH, open the Extensions view in VS Code.

Install this extension:

```text
SQL Server (mssql)
```

Make sure it is installed on the remote side. VS Code should show an action like:

```text
Install in SSH: upcrm-ubuntu
```

If it only says `Install Locally`, you are probably not in the Remote SSH window. Reconnect to the server first.

## 6. Connect VS Code To The Running SQL Server

In VS Code, open the Command Palette and run:

```text
MS SQL: Connect
```

or:

```text
SQL Server: Add Connection
```

Use these values for the default `UpCrmCompose` SQL Server container:

```text
Server name: localhost,1433
Authentication type: SQL Login
User name: sa
Password: value of MSSQL_SA_PASSWORD from .env
Database name: UpCrm
Trust server certificate: true
Encrypt: optional/true
```

Why `localhost` works here: the `mssql` extension is installed in the Remote SSH environment, so it runs on the Ubuntu server. From that extension, `localhost,1433` means the Ubuntu server's SQL Server port, not your local laptop.

To test with a query, create a new SQL file in VS Code and run:

```sql
SELECT name
FROM sys.databases
ORDER BY name;
```

You should see `UpCrm` in the result list after the Compose stack has initialized the database.

## Troubleshooting

Check that the containers are running:

```bash
cd ~/UpCrmCompose
docker compose ps
```

Check SQL Server logs:

```bash
docker compose logs --tail 100 sqlserver
```

If the VS Code connection fails with login errors, confirm that the password matches `MSSQL_SA_PASSWORD` in `.env`.

If the SQL Server container is not listening on host port `1433`, check `SQL_PORT` in `.env` and connect to:

```text
localhost,<SQL_PORT>
```

For example:

```text
localhost,1434
```
