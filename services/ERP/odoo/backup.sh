# backup.sh (services/ERP/odoo) — DB-aware backup/restore hooks.
# Sourced on demand by services.sh's Backup/Restore menu options — never
# exec'd directly, so this file is function definitions only, no top-level
# code. See services/_template/backup.sh.template for why this is separate
# from deploy.sh.
#
# Odoo is multi-instance, so $1 (instance) is always non-empty here — the
# db container is odoo-<instance>-db (see docker-compose.yml). Uses
# pg_dumpall (not pg_dump of a single database) because the actual business
# database name is chosen by the user later, inside Odoo's own
# /web/database/manager, not at deploy time — ODOO_DB_NAME in .env is only
# informational for deployments made after this was added; older
# deployments won't have it, so pg_dumpall (dumps every DB + roles in the
# cluster) is the one approach that works unconditionally.

backup_odoo() {
    local instance="$1" install_dir="$2"
    local dump_file="$install_dir/db.sql"
    local db_container="odoo-${instance}-db"

    local pg_user
    pg_user=$(grep -a '^POSTGRES_USER=' "$install_dir/.env" | cut -d= -f2)

    if docker exec "$db_container" pg_dumpall -U "$pg_user" > "$dump_file" 2>/dev/null; then
        print_info "Database cluster dumped to $dump_file"
    else
        print_warn "pg_dumpall failed — falling back to a raw (less safe) volume copy for the db."
        rm -f "$dump_file"
    fi

    backup_service_generic "odoo" "$instance" "$install_dir"
}

restore_odoo() {
    local instance="$1" install_dir="$2" archive="$3"
    local db_container="odoo-${instance}-db"

    restore_service_generic "odoo" "$instance" "$install_dir" "$archive"

    if [[ -f "$install_dir/db.sql" ]]; then
        local pg_user
        pg_user=$(grep -a '^POSTGRES_USER=' "$install_dir/.env" | cut -d= -f2)
        (cd "$install_dir" && $(compose_cmd) up -d db) || true
        sleep 3
        docker exec -i "$db_container" psql -U "$pg_user" -d postgres < "$install_dir/db.sql" \
            && print_info "Database cluster restored from db.sql" \
            || print_warn "Failed to restore db.sql — restore the volume backup manually if needed."
        rm -f "$install_dir/db.sql"
    fi
}
