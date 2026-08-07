# backup.sh (services/Photos/photoprism)
# DB-aware backup/restore override — see services/_template/backup.sh.template
# for why this exists. Adapted (not copied verbatim) because PhotoPrism uses
# MariaDB (mariadb-dump/mariadb clients) with its own PHOTOPRISM_DATABASE_*
# variable names, and its db compose service key is 'mariadb', not 'db'.
#
# Note this backs up the DATABASE (the index: albums, faces, labels, ratings,
# metadata). Your actual photo files live in the ORIGINALS_PATH folder you
# chose at deploy time, which is outside ~/docker/photoprism/ and therefore
# outside this backup — back that folder up separately, it's the
# irreplaceable half. See README.md.
#
# This file must contain ONLY function definitions — services.sh sources it
# on demand, it is never exec'd as its own process.

backup_photoprism() {
    local instance="$1" install_dir="$2"
    local dump_file="$install_dir/db.sql"

    local db_password
    db_password=$(grep -a '^PHOTOPRISM_DATABASE_PASSWORD=' "$install_dir/.env" | cut -d= -f2)

    # User/database names are fixed in docker-compose.yml (both "photoprism")
    # rather than being configurable, so they're not read from .env here.
    if docker exec photoprism-db mariadb-dump -uphotoprism -p"$db_password" photoprism > "$dump_file" 2>/dev/null; then
        print_info "Database dumped to $dump_file"
    else
        print_warn "mariadb-dump failed — falling back to a raw (less safe) volume copy for the db."
        rm -f "$dump_file"
    fi

    # Still capture compose files/.env and the storage volume (cache,
    # thumbnails, sidecars) the normal way — this only replaces how the db
    # volume itself gets backed up.
    backup_service_generic "photoprism" "$instance" "$install_dir"
}

restore_photoprism() {
    local instance="$1" install_dir="$2" archive="$3"

    restore_service_generic "photoprism" "$instance" "$install_dir" "$archive"

    if [[ -f "$install_dir/db.sql" ]]; then
        local db_password
        db_password=$(grep -a '^PHOTOPRISM_DATABASE_PASSWORD=' "$install_dir/.env" | cut -d= -f2)
        # db container needs to be up (but the app itself doesn't) for this —
        # services.sh's restore_menu already ran `compose down` before
        # calling this, so bring just the mariadb service back up first.
        (cd "$install_dir" && $(compose_cmd) up -d mariadb) || true
        sleep 8
        docker exec -i photoprism-db mariadb -uphotoprism -p"$db_password" photoprism < "$install_dir/db.sql" \
            && print_info "Database restored from db.sql" \
            || print_warn "Failed to restore db.sql — restore the volume backup manually if needed."
        rm -f "$install_dir/db.sql"
    fi
}
