#!/bin/bash
# Definition des variables
SOURCE_BASE="/home/rrotter/"
DEST_USER="save"
DEST_HOST="srv-backup"
DEST_BASE="/home/save/vms/"
LOG_FILE="/home/rrotter/logs/backup_dif.log"
DATE=$(date +%Y-%m-%d)
TIME=$(date +%H:%M:%S)
RESUME_FILE="/home/rrotter/logs/reprise_backup.txt"

# Fonction de journalisation
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Fonction pour sauvegarde differentielle
differential_backup() {
    local dir=$1
    local SOURCE_DIR="${SOURCE_BASE}${dir}"
    local DEST_DIR="${DEST_BASE}${dir}"
    local RESUME_FLAG=""

    log "Debut de la sauvegarde differentielle pour ${dir}"

    # Creation du repertoire de destination si pas existant
    ssh -i /home/rrotter/.ssh/id_rsa "$DEST_USER@$DEST_HOST" "mkdir -p ${DEST_DIR}"

    # Verification si une sauvegarde partielle existe
    if ssh -i /home/rrotter/.ssh/id_rsa "$DEST_USER@$DEST_HOST" "[ -f ${DEST_DIR}/.partial_backup ]"; then
        log "Reprise de la sauvegarde partielle pour ${dir}"
        RESUME_FLAG="--partial"
    else
        log "Demarrage d'une nouvelle sauvegarde pour ${dir}"
        ssh -i /home/rrotter/.ssh/id_rsa "$DEST_USER@$DEST_HOST" "touch ${DEST_DIR}/.partial_backup"
    fi

    # Creation du repertoire de destination si pas existant
    ssh -i /home/rrotter/.ssh/id_rsa "$DEST_USER@$DEST_HOST" "mkdir -p ${DEST_DIR}"

    rsync -avvz --stop-at=04:00 --delete --bwlimit=20M $RESUME_FLAG \
        -e "ssh -i /home/rrotter/.ssh/id_rsa" \
        "${SOURCE_DIR}/" "${DEST_USER}@${DEST_HOST}:${DEST_DIR}/" \
        >> "$LOG_FILE" 2>&1

    if [ $? -eq 0 ]; then
        log "Sauvegarde differentielle de ${dir} terminee avec succes"
        ssh -i /home/rrotter/.ssh/id_rsa "$DEST_USER@$DEST_HOST" "rm -f ${DEST_DIR}/.partial_backup"
    else
        log "Erreur lors de la sauvegarde differentielle de ${dir}"
        echo "${dir}" >> "$RESUME_FILE"
        return 1
    fi
}

# Liste des repertoires a sauvegarder
directories=("emails" "fichiers" "site" "rh" "tickets")

# Verification de l'heure pour la sauvegarde
if [ "$TIME" \> "00:01:00" ] && [ "$TIME" \< "23:59:00" ]; then
    log "Debut du processus de sauvegarde - dans la plage horaire 01:00-04:00"

    # Verification des sauvegardes partielles a  reprendre
    if [ -f "$RESUME_FILE" ]; then
        while read -r dir; do
            if [[ " ${directories[@]} " =~ " ${dir} " ]]; then
                differential_backup "$dir"
            fi
        done < "$RESUME_FILE"
        rm -f "$RESUME_FILE"
    fi

    # Sauvegarde differentielle pour chaque repertoire
    for dir in "${directories[@]}"; do
        differential_backup "$dir"
    done

    log "Fin du processus de sauvegarde"
else
    log "Hors plage horaire de sauvegarde (01:00-04:00). Aucune sauvegarde effectuee."
fi
