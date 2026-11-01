#!/bin/bash
# Back up and restore Stardew Valley saves, with a reason for each backup.
#
#   stardew-save.sh backup "reason"      back up the farm
#   stardew-save.sh list                 list the farm's backups, newest first
#   stardew-save.sh restore [N|name]     restore backup N from the list (asks first)
#   stardew-save.sh farms                list the save folders
#
# Add -f <farm> before the command to pick a farm (folder name or prefix, e.g.
# -f lespatatesen); otherwise the most recently saved farm is used.
# STARDEW_DIR overrides ~/.config/StardewValley.
set -euo pipefail

ROOT="${STARDEW_DIR:-$HOME/.config/StardewValley}"
SAVES="$ROOT/Saves"
BACKUPS="$ROOT/SaveBackups"
SEASONS=(Spring Summer Fall Winter)

die() { echo "error: $*" >&2; exit 1; }

usage() { sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

# Picks the farm folder: -f prefix match, or the most recently saved one.
pick_farm() {
    local want="${1:-}" matches
    [ -d "$SAVES" ] || die "no Saves folder at $SAVES"
    if [ -n "$want" ]; then
        if [ -d "$SAVES/$want" ]; then echo "$want"; return; fi
        matches=$(cd "$SAVES" && /bin/ls -d "$want"*/ 2>/dev/null | sed 's#/$##' || true)
        [ -n "$matches" ] || die "no farm matching '$want' (try: $0 farms)"
        [ "$(echo "$matches" | wc -l | tr -d ' ')" = 1 ] || die "'$want' matches several farms: $(echo $matches)"
        echo "$matches"
    else
        (cd "$SAVES" && /bin/ls -td */ 2>/dev/null | head -1 | sed 's#/$##') || true
    fi
}

tag() { grep -o "<$1>[^<]*</$1>" "$2" 2>/dev/null | head -1 | sed -e "s#<$1>##" -e "s#</$1>##" || true; }

# "Fall 17, Year 3 · farmer boingboing · married to Abigail"
describe_save() {
    local info="$1/SaveGameInfo" s d y line spouse
    [ -f "$info" ] || { echo "(no SaveGameInfo)"; return; }
    s=$(tag seasonForSaveGame "$info"); d=$(tag dayOfMonthForSaveGame "$info"); y=$(tag yearForSaveGame "$info")
    line="${SEASONS[${s:-0}]:-?} $d, Year $y · farmer $(tag name "$info")"
    spouse=$(tag spouse "$info")
    [ -n "$spouse" ] && line="$line · married to $spouse"
    echo "$line"
}

game_running() { pgrep -f "steamapps/common/Stardew Valley" >/dev/null 2>&1 || pgrep -x "Stardew Valley" >/dev/null 2>&1; }

# Backups of a farm, newest first (folder names only).
backups_of() { [ -d "$BACKUPS/$1" ] && (cd "$BACKUPS/$1" && /bin/ls -r | grep -v '^\.' ) || true; }

do_backup() {
    local farm="$1" reason="$2" stamp slug dest
    [ -n "$reason" ] || die "give a reason, e.g.: $0 backup \"before proposing to Abigail\""
    stamp=$(date +%Y-%m-%d_%H%M%S)
    slug=$(echo "$reason" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-//;s/-$//' | cut -c1-50)
    dest="$BACKUPS/$farm/${stamp}__${slug:-backup}"
    mkdir -p "$BACKUPS/$farm"
    cp -Rp "$SAVES/$farm" "$dest"
    {
        echo "reason: $reason"
        echo "backed up: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "game: $(describe_save "$dest")"
        echo "save file written: $(date -r "$dest/$farm" '+%Y-%m-%d %H:%M:%S')"
    } > "$dest/backup-info.txt"
    echo "Backed up $farm ($(describe_save "$dest"))"
    echo "  reason: $reason"
    echo "  to:     $dest"
    if game_running; then
        echo "  note: the game is running; this is the last save (the morning of the day above)."
    fi
}

do_list() {
    local farm="$1" n=0 b
    echo "Backups of $farm  (current save: $(describe_save "$SAVES/$farm"))"
    for b in $(backups_of "$farm"); do
        n=$((n + 1))
        local dir="$BACKUPS/$farm/$b"
        local reason when
        reason=$(sed -n 's/^reason: //p' "$dir/backup-info.txt" 2>/dev/null)
        when=$(sed -n 's/^backed up: //p' "$dir/backup-info.txt" 2>/dev/null)
        printf "%3d) %s  %s\n     %s\n" "$n" "${when:-$b}" "${reason:-(no reason recorded)}" "$(describe_save "$dir")"
    done
    [ "$n" -gt 0 ] || echo "  (none yet)"
}

do_restore() {
    local farm="$1" which="${2:-}" list chosen answer
    list=$(backups_of "$farm")
    [ -n "$list" ] || die "no backups of $farm yet"
    if [ -z "$which" ]; then
        do_list "$farm"
        printf "Restore which number? "
        read -r which
    fi
    if [[ "$which" =~ ^[0-9]+$ ]]; then
        chosen=$(echo "$list" | sed -n "${which}p")
    else
        chosen=$(echo "$list" | grep -F -- "$which" | head -1 || true)
    fi
    [ -n "$chosen" ] || die "no backup '$which' (see: $0 list)"
    game_running && die "quit Stardew Valley first (it would overwrite the restored save when you sleep)"
    local src="$BACKUPS/$farm/$chosen"
    echo "Restore: $(sed -n 's/^reason: //p' "$src/backup-info.txt" 2>/dev/null) ($(describe_save "$src"))"
    echo "Current: $(describe_save "$SAVES/$farm")  (it will be backed up first)"
    printf "Go ahead? [y/N] "
    read -r answer
    [[ "$answer" =~ ^[Yy] ]] || { echo "Cancelled."; exit 0; }
    do_backup "$farm" "auto: before restoring '$(sed -n 's/^reason: //p' "$src/backup-info.txt" 2>/dev/null)'" >/dev/null
    local tmp="$SAVES/.$farm.restoring"
    rm -rf "$tmp"
    cp -Rp "$src" "$tmp"
    rm -f "$tmp/backup-info.txt"
    rm -rf "$SAVES/$farm"
    mv "$tmp" "$SAVES/$farm"
    echo "Restored. Your previous save was backed up as 'auto: before restoring …' (see: $0 list)."
}

farm_arg=""
if [ "${1:-}" = "-f" ]; then farm_arg="${2:-}"; shift 2 || usage 1; fi
cmd="${1:-}"; shift || true
case "$cmd" in
    backup|b)  farm=$(pick_farm "$farm_arg"); [ -n "$farm" ] || die "no saves found"; do_backup "$farm" "$*" ;;
    list|ls|l) farm=$(pick_farm "$farm_arg"); do_list "$farm" ;;
    restore|r) farm=$(pick_farm "$farm_arg"); do_restore "$farm" "${1:-}" ;;
    farms)     for f in $(cd "$SAVES" && /bin/ls -td */ | sed 's#/$##'); do printf "%-32s %s\n" "$f" "$(describe_save "$SAVES/$f")"; done ;;
    -h|--help|help|"") usage ;;
    *) die "unknown command '$cmd' (try: $0 help)" ;;
esac
