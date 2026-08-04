# backup.sh (services/Projects/plane) — DB-aware backup/restore hooks.
# Sourced on demand by services.sh's Backup/Restore menu options — never
# exec'd directly, so this file is function definitions only, no top-level
# code. See services/_template/backup.sh.template for why this is separate
# from deploy.sh.
#
# Note: Plane also has MinIO (object storage for uploads) and RabbitMQ as
# named volumes — those are still covered by the generic volume backup this
# calls into; only the Postgres database gets the pg_dump treatment here.

backup_plane() {
    local instance="$1" install_dir="$2"
    local dump_file="$install_dir/db.sql"

    if docker exec plane-db pg_dump -U plane plane > "$dump_file" 2>/dev/null; then
        print_info "Database dumped to $dump_file"
    else
        print_warn "pg_dump failed — falling back to a raw (less safe) volume copy for the db."
        rm -f "$dump_file"
    fi

    backup_service_generic "plane" "$instance" "$install_dir"
}

restore_plane() {
    local instance="$1" install_dir="$2" archive="$3"

    restore_service_generic "plane" "$instance" "$install_dir" "$archive"

    if [[ -f "$install_dir/db.sql" ]]; then
        (cd "$install_dir" && $(compose_cmd) up -d plane-db) || true
        sleep 3
        docker exec -i plane-db psql -U plane -d plane < "$install_dir/db.sql" \
            && print_info "Database restored from db.sql" \
            || print_warn "Failed to restore db.sql — restore the volume backup manually if needed."
        rm -f "$install_dir/db.sql"
    fi
}
