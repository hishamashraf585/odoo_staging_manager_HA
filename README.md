# Odoo Staging Manager (Version 1.0)

This repository provides a Bash script to create automated, isolated staging environments for Odoo ERP systems. The script clones a live PostgreSQL database and deploys a standalone Odoo + PostgreSQL stack using Docker Compose. Each staging instance runs on a separate port with its own configuration, database, filestore, and logs.

---

## Table of Contents

- [Features](#features)
- [Requirements](#requirements)
- [Folder Structure](#folder-structure)
- [Usage](#usage)
- [Generated Files](#generated-files)
- [Management Commands](#management-commands)
- [Security](#security)
- [Improvements and Extensions](#improvements-and-extensions)
- [License](#license)

---

## Features

- Clone a live PostgreSQL database to a staging database
- Automatically generate `odoo.conf` and `docker-compose.yml` files
- Deploy a fully isolated Odoo and PostgreSQL stack
- Allow assignment of a custom XML-RPC port per instance
- Restore database using `pg_restore` after container initialization
- Structured directory per instance for better manageability
- Embedded management script for start/stop/restart/remove

---

## Requirements

- Unix-based OS (Ubuntu, Debian, etc.)
- Bash shell
- Docker (v20+ recommended)
- Docker Compose (v2 or v3)
- PostgreSQL client utilities installed (`pg_dump`, `pg_restore`)
- Access to the live PostgreSQL database from the host machine

---

## Folder Structure

Each created staging environment has its own subdirectory under a base path. The structure looks like this:

/odoo/staging/stg-20250419124530/ ├── addons/ # Optional extra addons (can be mounted) ├── config/ # Contains the odoo.conf file ├── data/postgres/ # PostgreSQL data volume ├── filestore/ # Odoo filestore (if used) ├── logs/ # Odoo log files ├── db.dump # Temporary PostgreSQL dump (auto-deleted) ├── docker-compose.yml # Service definition for this instance ├── manage.sh # Helper script to manage the instance


---

## Usage

### Run the script

```bash
./create_staging.sh --live-db LIVE_DB_NAME --stg-db STAGING_DB_NAME --port PORT

Arguments

    --live-db: Required. The name of the source live PostgreSQL database.

    --stg-db: Required. The name of the new staging database to be created.

    --port: Required. The XML-RPC port Odoo will use (e.g., 8075).

Example

./create_staging.sh --live-db odoo_prod --stg-db test_april --port 8075

Generated Files
docker-compose.yml

    Launches two services:

        odoo:<version> for the Odoo application

        postgres:14 for the staging database

    Sets up a private Docker bridge network

    Mounts volumes for persistence

odoo.conf

Includes basic Odoo configuration:

    Database connection details

    Port number

    Addons path

    Proxy mode

manage.sh

Helper script to manage the created instance:

./manage.sh start      # Start containers
./manage.sh stop       # Stop containers
./manage.sh restart    # Restart containers
./manage.sh remove     # Stop and delete instance + data

Security

    Credentials (database user/password) are unique per instance.

    Dump files are deleted after restoration to prevent leakage.

    PostgreSQL runs in a private Docker network.

    Odoo admin password is auto-generated and stored in the config.

Improvements and Extensions (Suggestions)

    Support for --odoo-version flag to customize the image version

    Optional expiration/auto-deletion of old environments

    Backup to external storage (Amazon S3, Google Drive)

    Add authentication or VPN restriction to staging endpoints

    Slack/email notifications after environment creation

License

This script is open for customization and internal use. It is distributed without any warranty. Use at your own risk.
Hisham

Developed and maintained by Hisham Ashraf
