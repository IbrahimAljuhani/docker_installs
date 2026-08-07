# backup.sh (services/Web/ghost)
# DB-aware backup/restore override — see services/_template/backup.sh.template
# for why this exists. The generic volume copy handles Ghost's content volume
# (themes, images, uploaded media) correctly, but would raw-copy live MySQL
# data files, which can produce a subtly corrupt, unrestorable dump.
#
# Note this is MySQL, not MariaDB — Ghost supports MySQL 8 only, so the
# binaries here are mysqldump/mysql and there is no mariadb-* fallback to
# try (unlike this repo's Dolibarr and ERPNext backups).
#
# This file must contain ONLY function definitions — services.sh sources it
# on demand, it is never exec'd as its own process.

backup_ghost() {
    local instance="$1" install_dir="$2"
    local dump_file="$install_dir/db.sql"

    local db_name db_password
    db_name=$(read_env_value "GHOST_DB_NAME" "$install_dir/.env")
    db_password=$(read_env_value "GHOST_DB_ROOT_PASSWORD" "$install_dir/.env")

    # --single-transaction snapshots consistently without locking the server.
    # Ghost keeps writing (scheduled posts, member events) during a backup.
    if docker exec ghost-db mysqldump -uroot -p"$db_password" \
        --single-transaction --routines --events "$db_name" > "$dump_file" 2>/dev/null; then
        print_info "Database '$db_name' dumped to $dump_file"
    else
        print_warn "mysqldump failed — falling back to a raw (less safe) volume copy for the db."
        rm -f "$dump_file"
    fi

    # Still capture compose files, .env and the ghost-content volume (themes,
    # images, media, routes.yaml) the normal way.
    backup_service_generic "ghost" "$instance" "$install_dir"
}

restore_ghost() {
    local instance="$1" install_dir="$2" archive="$3"

    restore_service_generic "ghost" "$instance" "$install_dir" "$archive"

    if [[ -f "$install_dir/db.sql" ]]; then
        local db_name db_password
        db_name=$(read_env_value "GHOST_DB_NAME" "$install_dir/.env")
        db_password=$(read_env_value "GHOST_DB_ROOT_PASSWORD" "$install_dir/.env")
        # The db container needs to be up (the app doesn't) — services.sh's
        # restore_menu ran `compose down` first, so bring just the db back
        # and wait for it to accept connections.
        (cd "$install_dir" && $(compose_cmd) up -d ghost-db) || true
        local waited=0
        while (( waited < 60 )); do
            docker exec ghost-db mysql -uroot -p"$db_password" -e 'SELECT 1' >/dev/null 2>&1 && break
            sleep 3
            waited=$(( waited + 3 ))
        done

        if docker exec -i ghost-db mysql -uroot -p"$db_password" "$db_name" < "$install_dir/db.sql"; then
            print_info "Database restored from db.sql"
            rm -f "$install_dir/db.sql"
        else
            print_warn "Failed to restore db.sql — the file has been left at $install_dir/db.sql so you can retry by hand."
        fi
    fi

    print_warn "Check that GHOST_URL in .env matches the site you just restored — Ghost stores absolute URLs, and a mismatch shows up as broken links and an admin panel that redirects away."
}
