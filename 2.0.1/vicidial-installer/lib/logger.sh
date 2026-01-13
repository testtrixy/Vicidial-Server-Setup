LOGFILE="/var/log/vicidial-installer.log"

log() {
  echo -e "[`date '+%F %T'`] $1" | tee -a "$LOGFILE"
}
