# backup.sh (services/Photos/immich)
# DB-aware backup/restore override — see services/_template/backup.sh.template
# for why this exists. Adapted (not copied verbatim) because Immich's own
# .env uses DB_USERNAME/DB_DATABASE_NAME (not this repo's usual
# POSTGRES_USER/POSTGRES_DB names) and its db compose service key is
# 'database', not 'db'.
#
# This file must contain ONLY function definitions — services.sh sources it
# on demand, it is never exec'd as its own process.

backup_immich() {
    local instance="$1" install_dir="$2"
    local dump_file="$install_dir/db.sql"

    local pg_user pg_db
    pg_user=$(grep -a '^DB_USERNAME=' "$install_dir/.env" | cut -d= -f2)
    pg_db=$(grep -a '^DB_DATABASE_NAME=' "$install_dir/.env" | cut -d= -f2)

    if docker exec immich-db pg_dump -U "$pg_user" "$pg_db" > "$dump_file" 2>/dev/null; then
        print_info "Database dumped to $dump_file"
    else
        print_warn "pg_dump failed — falling back to a raw (less safe) volume copy for the db."
        rm -f "$dump_file"
    fi

    # Still capture compose files/.env, the photo library, and the
    # machine-learning model cache the normal way — this only replaces how
    # the db data itself gets backed up.
    backup_service_generic "immich" "$instance" "$install_dir"
}

restore_immich() {
    local instance="$1" install_dir="$2" archive="$3"

    restore_service_generic "immich" "$instance" "$install_dir" "$archive"

    if [[ -f "$install_dir/db.sql" ]]; then
        local pg_user pg_db
        pg_user=$(grep -a '^DB_USERNAME=' "$install_dir/.env" | cut -d= -f2)
        pg_db=$(grep -a '^DB_DATABASE_NAME=' "$install_dir/.env" | cut -d= -f2)
        # db container needs to be up (but the app itself doesn't) for this —
        # services.sh's restore_menu already ran `compose down` before
        # calling this, so bring just the database service back up first.
        (cd "$install_dir" && $(compose_cmd) up -d database) || true
        sleep 3
        docker exec -i immich-db psql -U "$pg_user" -d "$pg_db" < "$install_dir/db.sql" \
            && print_info "Database restored from db.sql" \
            || print_warn "Failed to restore db.sql — restore the volume backup manually if needed."
        rm -f "$install_dir/db.sql"
    fi
}
