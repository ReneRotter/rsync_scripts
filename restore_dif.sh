#!/bin/bash

SOURCE_USER="save"
SOURCE_HOST="srv-backup"
SOURCE_BASE="/home/save/vms"
DEST_BASE="/home/rrotter"
DEST_USER="rrotter"
DEST_HOST="localhost"
LOG_FILE="/home/rrotter/logs/restore_dif.log"

DIRECTORIES=("emails" "tickets" "site" "rh" "fichiers")

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

check_backup() {
    local dir=$1
    local SOURCE_DIR="${SOURCE_BASE}/${dir}"
    
    if ! ssh -i /home/rrotter/.ssh/id_rsa ${SOURCE_USER}@${SOURCE_HOST} "[ -d ${SOURCE_DIR} ]" >> "$LOG_FILE" 2>&1; then
        log "Aucune sauvegarde trouvee pour ${dir}"
        return 1
    fi
    
    return 0
}

restore_directory_differential() {
    local dir=$1
    local SOURCE_DIR="${SOURCE_BASE}/${dir}"
    local DEST_DIR="${DEST_BASE}/${dir}"

    log "Debut de la restauration differentielle du repertoire ${dir}"
    
    mkdir -p "${DEST_DIR}"
    
    if check_backup "$dir"; then
        if [ -f "${DEST_DIR}/.reprise_restore" ]; then
            log "Reprise de la restauration partielle pour ${dir}"
            RESUME_FLAG="--partial"
        else
            log "Demarrage d'une restauration non-partielle pour ${dir}"
            touch "${DEST_DIR}/.reprise_restore" >> "$LOG_FILE" 2>&1
        fi

        rsync -avvz --delete $RESUME_FLAG \
            -e "ssh -i /home/rrotter/.ssh/id_rsa" \
            "${SOURCE_USER}@${SOURCE_HOST}:${SOURCE_DIR}/" "${DEST_DIR}/" \
            >> "$LOG_FILE" 2>&1

        if [ $? -eq 0 ]; then
            log "Restauration differentielle de ${dir} terminee avec succes"
            rm -f "${DEST_DIR}/.reprise_restore" >> "$LOG_FILE" 2>&1
        else
            log "Erreur lors de la restauration differentielle de ${dir}"
            return 1
        fi
    fi
}

if [ $# -eq 1 ] && [[ " ${DIRECTORIES[@]} " =~ " $1 " ]]; then
    restore_directory_differential "$1" >> "$LOG_FILE" 2>&1
else
    for dir in "${DIRECTORIES[@]}"; do
        restore_directory_differential "$dir" >> "$LOG_FILE" 2>&1
    done
    log "Restauration differentielle de tous les repertoires terminee"
fi
