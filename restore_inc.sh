#!/bin/bash

SOURCE_USER="save"
SOURCE_HOST="srv-backup"
SOURCE_BASE="/home/save"
DEST_BASE="/home/rrotter"
LOG_FILE="/home/rrotter/logs/restore_inc.log"
FULL_BACKUP_MARKER="FULL_BACKUP_COMPLETED"

DIRECTORIES=("site" "rh" "tickets" "fichiers" "emails")

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

restore_latest() {
    local dir=$1
    log "Restauration de la derniere version de $dir"

    # Trouver la sauvegarde incrementale la plus recente
    local latest_backup=$(ssh -i /home/rrotter/.ssh/id_rsa ${SOURCE_USER}@${SOURCE_HOST} "ls -1td ${SOURCE_BASE}/${dir}/incremental/*/ 2>/dev/null | head -n1")

    if [ -n "$latest_backup" ]; then
        # S'assurer que le repertoire de destination existe
        mkdir -p "${DEST_BASE}/${dir}/incremental"

        rsync -avz -e "ssh -i /home/rrotter/.ssh/id_rsa" \
            "${SOURCE_USER}@${SOURCE_HOST}:${latest_backup}/" "${DEST_BASE}/${dir}/incremental/" >> "$LOG_FILE" 2>&1

        if [ $? -eq 0 ]; then
            log "Restauration de la derniere version de ${dir} terminee avec succes"
        else
            log "Erreur lors de la restauration de la derniere version de ${dir}"
        fi
    else
        log "Aucune sauvegarde incrementale trouvee pour ${dir}"
    fi
}

restore_previous() {
    local dir=$1
    log "Restauration de la sauvegarde complete et des sauvegardes incrementales de $dir"

    if ssh -i /home/rrotter/.ssh/id_rsa ${SOURCE_USER}@${SOURCE_HOST} "[ -f ${SOURCE_BASE}/${dir}/${FULL_BACKUP_MARKER} ]"; then
        # S'assurer que le repertoire de destination existe
        mkdir -p "${DEST_BASE}/${dir}"

        rsync -avz -e "ssh -i /home/rrotter/.ssh/id_rsa" \
            "${SOURCE_USER}@${SOURCE_HOST}:${SOURCE_BASE}/${dir}/full_backup/" "${DEST_BASE}/${dir}/" >> "$LOG_FILE" 2>&1

        if [ $? -eq 0 ]; then
            log "Restauration de la sauvegarde complete de ${dir} terminee avec succes"

            local incremental_backups=$(ssh -i /home/rrotter/.ssh/id_rsa ${SOURCE_USER}@${SOURCE_HOST} "ls -1td ${SOURCE_BASE}/${dir}/incremental/*")

            for backup in $incremental_backups; do
                log "Application de la sauvegarde incrementale : $backup"
                rsync -avz -e "ssh -i /home/rrotter/.ssh/id_rsa" \
                    "${SOURCE_USER}@${SOURCE_HOST}:${backup}/" "${DEST_BASE}/${dir}/" >> "$LOG_FILE" 2>&1

                if [ $? -ne 0 ]; then
                    log "Erreur lors de l'application de la sauvegarde incrementale : $backup"
                    return 1
                fi
            done

            log "Restauration complete et incrementale de $dir terminee avec succes"
        else
            log "Erreur lors de la restauration de la sauvegarde complete de ${dir}"
            return 1
        fi
    else
        log "Aucune sauvegarde complete trouvee pour $dir"
        return 1
    fi
}

restore_directory() {
    local dir=$1
    local version=$2
    case $version in
        latest)
            restore_latest $dir
            ;;
        previous)
            restore_previous $dir
            ;;
        *)
            log "Version non valide pour $dir: $version"
            ;;
    esac
}

if [ $# -eq 0 ]; then
    echo "Usage: $0 {directory} {latest|previous}"
    echo "       $0 all {latest|previous}"
    exit 1
fi

if [ "$1" = "all" ]; then
    if [ "$2" = "latest" ] || [ "$2" = "previous" ]; then
        for dir in "${DIRECTORIES[@]}"; do
            restore_directory $dir $2
        done
    else
        echo "Pour restaurer tous les repertoires, specifiez 'latest' ou 'previous'"
        exit 1
    fi
else
    if [[ " ${DIRECTORIES[@]} " =~ " $1 " ]]; then
        if [ "$2" = "latest" ] || [ "$2" = "previous" ]; then
            restore_directory $1 $2
        else
            echo "Specifiez 'latest' ou 'previous' pour la version a restaurer"
            exit 1
        fi
    else
        echo "Repertoire non valide. Choisissez parmi: ${DIRECTORIES[*]}"
        exit 1
    fi
fi

log "Processus de restauration termine"
