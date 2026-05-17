FROM mcr.microsoft.com/dotnet/runtime:8.0-jammy

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="/opt/mssql-tools18/bin:${PATH}"

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl unzip gnupg ca-certificates apt-transport-https \
    && curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /usr/share/keyrings/microsoft-prod.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/microsoft-prod.gpg] https://packages.microsoft.com/ubuntu/22.04/prod jammy main" \
      > /etc/apt/sources.list.d/mssql-release.list \
    && apt-get update \
    && ACCEPT_EULA=Y apt-get install -y --no-install-recommends mssql-tools18 unixodbc \
    && curl -fsSL https://aka.ms/sqlpackage-linux -o /tmp/sqlpackage.zip \
    && mkdir -p /opt/sqlpackage \
    && unzip -q /tmp/sqlpackage.zip -d /opt/sqlpackage \
    && chmod +x /opt/sqlpackage/sqlpackage \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY init-image/init-db.sh /usr/local/bin/init-db.sh
COPY init-image/seed-service-login.sql /app/seed-service-login.sql
COPY init-image/seed-admin-users.sql /app/seed-admin-users.sql
COPY init-image/seed-demo-tenant.sql /app/seed-demo-tenant.sql
COPY init-image/seed-demo-objects.sql /app/seed-demo-objects.sql
COPY init-image/seed-demo-notes.sql /app/seed-demo-notes.sql
COPY init-image/seed-tenant-settings.sql /app/seed-tenant-settings.sql
COPY DbProjAtomicCrm.dacpac /app/DbProjAtomicCrm.dacpac

RUN sed -i 's/\r$//' /usr/local/bin/init-db.sh \
    && chmod +x /usr/local/bin/init-db.sh \
    && rm /tmp/sqlpackage.zip

ENTRYPOINT ["/usr/local/bin/init-db.sh"]
