# backup.sh (services/Storage/nextcloud) — DB-aware backup/restore hooks.
# Sourced on demand by services.sh's Backup/Restore menu options — never
# exec'd directly, so this file is function definitions only, no top-level
# code. See services/_template/backup.sh.template for why this is separate
# from deploy.sh.
#
# Note: this does NOT put Nextcloud in maintenance mode before dumping —
# for a truly consistent snapshot under heavy concurrent use, run
# `docker exec -u www-data nextcloud-app php occ maintenance:mode --on`
# yourself first, then turn it back off after backing up.

backup_nextcloud() {
    local instance="$1" install_dir="$2"
    local dump_file="$install_dir/db.sql"

    if docker exec nextcloud-db pg_dump -U nextcloud nextcloud > "$dump_file" 2>/dev/null; then
        print_info "Database dumped to $dump_file"
    else
        print_warn "pg_dump failed — falling back to a raw (less safe) volume copy for the db."
        rm -f "$dump_file"
    fi

    backup_service_generic "nextcloud" "$instance" "$install_dir"
}

restore_nextcloud() {
    local instance="$1" install_dir="$2" archive="$3"

    restore_service_generic "nextcloud" "$instance" "$install_dir" "$archive"

    if [[ -f "$install_dir/db.sql" ]]; then
        (cd "$install_dir" && $(compose_cmd) up -d db) || true
        sleep 3
        docker exec -i nextcloud-db psql -U nextcloud -d nextcloud < "$install_dir/db.sql" \
            && print_info "Database restored from db.sql" \
            || print_warn "Failed to restore db.sql — restore the volume backup manually if needed."
        rm -f "$install_dir/db.sql"
    fi
}
