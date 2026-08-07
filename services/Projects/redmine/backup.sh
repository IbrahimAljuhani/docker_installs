# backup.sh (services/Projects/redmine) — DB-aware backup/restore hooks.
# Sourced on demand by services.sh's Backup/Restore menu options — never
# exec'd directly, so this file is function definitions only, no top-level
# code. See services/_template/backup.sh.template for why this is separate
# from deploy.sh.

backup_redmine() {
    local instance="$1" install_dir="$2"
    local dump_file="$install_dir/db.sql"

    local pg_user pg_db
    pg_user=$(grep -a '^POSTGRES_USER=' "$install_dir/.env" | cut -d= -f2)
    pg_db=$(grep -a '^POSTGRES_DB=' "$install_dir/.env" | cut -d= -f2)

    if docker exec redmine-db pg_dump -U "$pg_user" "$pg_db" > "$dump_file" 2>/dev/null; then
        print_info "Database dumped to $dump_file"
    else
        print_warn "pg_dump failed — falling back to a raw (less safe) volume copy for the db."
        rm -f "$dump_file"
    fi

    backup_service_generic "redmine" "$instance" "$install_dir"
}

restore_redmine() {
    local instance="$1" install_dir="$2" archive="$3"

    restore_service_generic "redmine" "$instance" "$install_dir" "$archive"

    if [[ -f "$install_dir/db.sql" ]]; then
        local pg_user pg_db
        pg_user=$(grep -a '^POSTGRES_USER=' "$install_dir/.env" | cut -d= -f2)
        pg_db=$(grep -a '^POSTGRES_DB=' "$install_dir/.env" | cut -d= -f2)
        (cd "$install_dir" && $(compose_cmd) up -d db) || true
        sleep 3
        docker exec -i redmine-db psql -U "$pg_user" -d "$pg_db" < "$install_dir/db.sql" \
            && print_info "Database restored from db.sql" \
            || print_warn "Failed to restore db.sql — restore the volume backup manually if needed."
        rm -f "$install_dir/db.sql"
    fi
}
