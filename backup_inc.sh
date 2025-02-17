#!/bin/bash
# Definition des variables

SOURCE_USER="rrotter"
SOURCE_HOST="localhost"
SOURCE_BASE="/home/rrotter"
DEST_USER="save"
DEST_HOST="srv-backup"
DEST_BASE="/home/save"
LOG_FILE="/home/rrotter/logs/backup_inc.log"
DATE=$(date +%Y-%m-%d_%H:%M:%S)
FULL_BACKUP_MARKER="FULL_BACKUP_COMPLETED"
RETENTION_DAYS=30

DIRECTORIES=("site" "rh" "tickets" "fichiers" "emails")

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

incremental_backup() {
    local dir=$1
    local SOURCE_DIR="${SOURCE_BASE}/${dir}"
    local DEST_DIR="${DEST_BASE}/${dir}"
    local FULL_BACKUP_DIR="${DEST_DIR}/full_backup"
    local INCREMENTAL_DIR="${DEST_DIR}/incremental/${DATE}"

    log "Debut de la sauvegarde incrementielle pour ${dir}"

    # Creation des repertoires necessaires
    ssh -i /home/rrotter/.ssh/id_rsa ${DEST_USER}@${DEST_HOST} "mkdir -p ${FULL_BACKUP_DIR} ${INCREMENTAL_DIR}"

    if ssh -i /home/rrotter/.ssh/id_rsa ${DEST_USER}@${DEST_HOST} "[ ! -f ${DEST_DIR}/${FULL_BACKUP_MARKER} ]"; then
        log "Execution de la sauvegarde complete initiale pour ${dir}"
        rsync -avz --delete \
            -e "ssh -i /home/rrotter/.ssh/id_rsa" \
            "${SOURCE_DIR}/" "${DEST_USER}@${DEST_HOST}:${FULL_BACKUP_DIR}/" \
            >> "$LOG_FILE" 2>&1
        
        if [ $? -eq 0 ]; then
            ssh -i /home/rrotter/.ssh/id_rsa ${DEST_USER}@${DEST_HOST} "touch ${DEST_DIR}/${FULL_BACKUP_MARKER}"
            log "Sauvegarde complete initiale terminee avec succes pour ${dir}"
        else
            log "Erreur lors de la sauvegarde complete initiale pour ${dir}"
            return 1
        fi
    else
        log "Execution de la sauvegarde incrementielle pour ${dir}"
        rsync -avz --delete --backup --backup-dir="${INCREMENTAL_DIR}" \
            -e "ssh -i /home/rrotter/.ssh/id_rsa" \
            "${SOURCE_DIR}/" "${DEST_USER}@${DEST_HOST}:${FULL_BACKUP_DIR}/" \
            >> "$LOG_FILE" 2>&1
        
        if [ $? -eq 0 ]; then
            log "Sauvegarde incrementielle terminee avec succes pour ${dir}"
        else
            log "Erreur lors de la sauvegarde incrementielle pour ${dir}"
            return 1
        fi
    fi

    # Suppression des anciennes sauvegardes
    log "Suppression des sauvegardes incrementielles de plus de ${RETENTION_DAYS} jours pour ${dir}"
    ssh -i /home/rrotter/.ssh/id_rsa ${DEST_USER}@${DEST_HOST} \
        "find ${DEST_DIR}/incremental -type d -mtime +${RETENTION_DAYS} -exec rm -rf {} +" \
        >> "$LOG_FILE" 2>&1
    
    if [ $? -eq 0 ]; then
        log "Suppression des anciennes sauvegardes reussie pour ${dir}"
    else
        log "Erreur lors de la suppression des anciennes sauvegardes pour ${dir}"
    fi
}

for dir in "${DIRECTORIES[@]}"; do
    incremental_backup "$dir"
    if [ $? -ne 0 ]; then
        log "Erreur lors de la sauvegarde de ${dir}"
    fi
done

log "Processus de sauvegarde termine pour tous les repertoires"
