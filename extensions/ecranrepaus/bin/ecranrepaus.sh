#!/bin/sh
# Ecran de repaus: turns off the Special Offers ads and puts the Meteo Alarm Kindle image on
# the lock screen of a jailbroken Kindle Paperwhite 1 (FW 5.6.x), started from KUAL.
#
# Usage: ecranrepaus.sh verifica | reclame | ecran | automat | pornire | anuleaza
#   verifica  write a report (raport.txt) of the ad settings, screensaver files and free space
#   reclame   back up appreg.db, set adunit.viewable=false, empty the downloaded ads
#   ecran     back up the stock screensavers once, then replace each with screensaver.png
#   automat   install an upstart job that runs `pornire` at every boot, and run it now
#   pornire   (boot) ads off, block ad downloads, fix the clock's time zone for DST, and swap
#             the lock screen from the ads module (ad_screensaver) to the normal screensaver
#   anuleaza  undo all of the above
# Every action appends to raport.txt; a reboot applies the change.

export PATH=/usr/sbin:/usr/bin:/sbin:/bin:/mnt/us/libkh/bin

DIR=$(cd "$(dirname "$0")/.." && pwd)
LOG=$DIR/raport.txt
BAK=$DIR/copie
IMG=$DIR/screensaver.png
DB=/var/local/appreg.db
SS_DIR=/usr/share/blanket/screensaver
ADS=/var/local/adunits
TZ_FILE=/var/local/system/tz
JOB=/etc/upstart/ecranrepaus.conf
# Runs before the framework starts, so the interface reads the corrected time zone.
JOB_EARLY=/etc/upstart/ecranrepaus-ora.conf
# The interface (Java) keeps its own offset as text ("GMT+03:00") in these files.
JAVA_TZ_FILES="/var/local/system/tzVar /var/local/java/prefs/com.amazon.ebook.framework/prefs"
# Romania's rule, to pick the fixed-offset zone file the Kindle needs today (EET or EEST).
TZ_RO="EET-2EEST,M3.5.0/3,M10.5.0/4"

say() { echo "$*" >>"$LOG"; }

# have CMD: true when CMD is on PATH (`command -v` misreports under the Kindle's BusyBox ash).
have() { which "$1" >/dev/null 2>&1; }

# show TEXT: a line near the bottom of the screen, so the result is visible without USB.
show() {
	if have fbink; then
		fbink -q -m -y -4 -- "$1" >/dev/null 2>&1
	else
		eips 1 37 "$1" >/dev/null 2>&1
	fi
}

ads_value() { sqlite3 "$DB" "select value from properties where name='adunit.viewable';" 2>&1 | head -1; }

verifica() {
	say "--- verifica $(date '+%Y-%m-%d %H:%M')"
	say "firmware: $(cat /etc/prettyversion.txt 2>/dev/null | head -1)"
	say "utilizator: $(id)"
	say "sqlite3: $(which sqlite3 || echo LIPSESTE)"
	say "fbink: $(which fbink || echo lipseste)"
	say "adunit:"
	sqlite3 "$DB" "select handlerId, name, value from properties where name like 'adunit%';" >>"$LOG" 2>&1
	say "/var/local/adunits: $(ls /var/local/adunits 2>/dev/null | wc -l) fisiere"
	say "/var/local/merchant: $(ls /var/local/merchant 2>/dev/null | wc -l) fisiere"
	say "$SS_DIR:"
	ls -la "$SS_DIR" >>"$LOG" 2>&1
	say "dcc (toate):"
	sqlite3 "$DB" "select handlerId, name, value from properties where handlerId='dcc' or name like '%ad%' or name like '%offer%' or name like '%screensaver%';" >>"$LOG" 2>&1
	say "fisiere reclame:"
	ls -la /var/local/adunits /var/local/merchant >>"$LOG" 2>&1
	say "/usr/share/blanket:"
	ls -laR /usr/share/blanket >>"$LOG" 2>&1
	say "procese blanket/ad:"
	ps | grep -i -e blanket -e adunit -e merchant | grep -v grep >>"$LOG" 2>&1
	say "lipc blanket:"
	lipc-probe -v com.lab126.blanket >>"$LOG" 2>&1
	say "ora: local=$(date '+%Y-%m-%d %H:%M:%S %Z') utc=$(date -u '+%H:%M:%S') TZ=[$TZ]"
	ls -la /etc/localtime /var/local/system >>"$LOG" 2>&1
	tail -c 80 /etc/localtime 2>/dev/null | tr -c '[:print:]' '.' >>"$LOG"; echo >>"$LOG"
	grep -rl -e TZ -e timezone /etc/profile /etc/upstart/*.conf 2>/dev/null >>"$LOG"
	say "upstart:"
	ls /etc/upstart >>"$LOG" 2>&1
	say "spatiu liber (KB):"
	df -k / /var/local >>"$LOG" 2>&1
	show "Verificare gata. Vezi raport.txt"
}

reclame() {
	say "--- reclame $(date '+%Y-%m-%d %H:%M')"
	if ! have sqlite3; then
		say "EROARE: sqlite3 lipseste, nu am schimbat nimic"
		show "Eroare: sqlite3 lipseste. Vezi raport.txt"
		return 1
	fi
	mkdir -p "$BAK"
	[ -f "$BAK/appreg.db" ] || cp "$DB" "$BAK/appreg.db"
	say "inainte: adunit.viewable=$(ads_value)"
	sqlite3 "$DB" "update properties set value='false' where name='adunit.viewable';" >>"$LOG" 2>&1
	rm -rf /var/local/adunits/* /var/local/merchant/* 2>>"$LOG"
	sync
	say "dupa: adunit.viewable=$(ads_value)"
	show "Reclame oprite. Reporneste Kindle-ul."
}

ecran() {
	say "--- ecran $(date '+%Y-%m-%d %H:%M')"
	if [ ! -d "$SS_DIR" ] || [ ! -f "$IMG" ]; then
		say "EROARE: lipseste $SS_DIR sau $IMG"
		show "Eroare. Vezi raport.txt"
		return 1
	fi
	mkdir -p "$BAK/screensaver"
	[ -n "$(ls "$BAK/screensaver" 2>/dev/null)" ] || cp "$SS_DIR"/*.png "$BAK/screensaver/"
	if [ "$(ls "$SS_DIR"/*.png | wc -l)" != "$(ls "$BAK/screensaver"/*.png | wc -l)" ]; then
		say "EROARE: copia de siguranta e incompleta, nu am schimbat nimic"
		show "Eroare la copie. Vezi raport.txt"
		return 1
	fi
	# Each stock file is replaced by one of the same name, so the new total is
	# count * size(IMG); refuse when that would not fit with 1 MB to spare.
	need=$(( $(ls "$SS_DIR"/*.png | wc -l) * $(wc -c <"$IMG") / 1024 ))
	room=$(( $(du -sk "$SS_DIR" | cut -f1) + $(df -k / | awk 'NR==2 {print $4}') ))
	if [ "$need" -gt $(( room - 1024 )) ]; then
		say "EROARE: nu e loc pe sistem (trebuie ${need} KB, sunt ${room} KB)"
		show "Eroare: nu e loc. Vezi raport.txt"
		return 1
	fi
	mntroot rw >>"$LOG" 2>&1
	for f in "$SS_DIR"/*.png; do
		cp "$IMG" "$f" 2>>"$LOG" || say "EROARE la $f"
	done
	sync
	mntroot ro >>"$LOG" 2>&1
	say "inlocuite: $(ls "$SS_DIR"/*.png | wc -l) imagini"
	show "Ecran de repaus pus. Reporneste Kindle-ul."
}

# fix_tz: the Kindle keeps a fixed UTC offset in $TZ_FILE and never moves it for summer
# time; put in the one that matches today in Romania (takes effect after a reboot).
fix_tz() {
	want=eet
	[ "$(TZ="$TZ_RO" date +%z)" = "+0300" ] && want=eest
	if ! cmp -s "$DIR/tz-$want" "$TZ_FILE"; then
		mkdir -p "$BAK"
		[ -f "$BAK/tz" ] || cp "$TZ_FILE" "$BAK/tz"
		cp "$DIR/tz-$want" "$TZ_FILE" && say "ora: fus schimbat in $want"
	fi
}

# block_ads: the ads live in $ADS; an empty file in its place stops new downloads.
block_ads() {
	sqlite3 "$DB" "update properties set value='false' where name='adunit.viewable';" >>"$LOG" 2>&1
	if [ -d "$ADS" ]; then
		rm -rf "$ADS" && touch "$ADS" && say "reclame: $ADS blocat"
	fi
}

# swap_blanket: blanket draws the lock screen with whichever module is loaded; once
# the framework has loaded ad_screensaver, replace it with the plain screensaver
# (up to 3 minutes after boot).
swap_blanket() {
	i=0
	while [ $i -lt 90 ]; do
		mods=$(lipc-get-prop com.lab126.blanket load 2>/dev/null)
		case " $mods " in
			*" ad_screensaver "*)
				lipc-set-prop com.lab126.blanket unload ad_screensaver
				lipc-set-prop com.lab126.blanket load screensaver
				say "blanket: ad_screensaver -> screensaver ($(lipc-get-prop com.lab126.blanket load 2>/dev/null))"
				return 0 ;;
			*" screensaver "*)
				say "blanket: screensaver deja incarcat"
				return 0 ;;
		esac
		sleep 2
		i=$((i + 1))
	done
	say "blanket: nu am gasit modulul ($mods)"
}

# fix_java_tz: put today's Romanian offset into the interface's own time zone files
# (KINDLE_TZ=GMT+02:00 in tzVar, device.tz.lasttz=GMT+02\:00 in the framework prefs).
fix_java_tz() {
	want="GMT+02"
	[ "$(TZ="$TZ_RO" date +%z)" = "+0300" ] && want="GMT+03"
	for f in $JAVA_TZ_FILES; do
		[ -f "$f" ] || continue
		sed -e '/^#/b' -e 's/GMT+0[0-9]\([\]*\):[0-9][0-9]/'"$want"'\1:00/g' "$f" >"$f.new"
		if cmp -s "$f" "$f.new"; then
			rm -f "$f.new"
			continue
		fi
		mkdir -p "$BAK"
		b="$BAK/$(basename "$f").orig"
		[ -f "$b" ] || cp "$f" "$b"
		cat "$f.new" >"$f" && rm -f "$f.new" && say "ora: $f -> $want:00"
	done
}

# ora: the early boot job (before the framework starts).
ora() {
	say "--- ora $(date '+%Y-%m-%d %H:%M')"
	fix_tz
	fix_java_tz
}

# install_early_job: added in v1.2; installed from the boot run if missing.
install_early_job() {
	[ -f "$JOB_EARLY" ] && return 0
	mntroot rw >>"$LOG" 2>&1
	cat >"$JOB_EARLY" <<-EOT
		# Ecran de repaus (Meteo Alarm Kindle): Romanian summer/winter time, before the interface starts.
		start on starting framework
		task
		script
		    S=/mnt/us/extensions/ecranrepaus/bin/ecranrepaus.sh
		    [ -f \$S ] && sh \$S ora || true
		end script
	EOT
	sync
	mntroot ro >>"$LOG" 2>&1
	say "job: $JOB_EARLY instalat"
}

# tz_report: where the framework (Java) keeps its own time zone; it ignores $TZ_FILE.
tz_report() {
	say "tz java: utc=$(date -u '+%H:%M') local=$(date '+%H:%M %Z')"
	for pid in $(pidof cvm java 2>/dev/null); do
		tr '\0' ' ' <"/proc/$pid/cmdline" | grep -o -e '-Duser.timezone=[^ ]*' -e '-Duser.region=[^ ]*' >>"$LOG"
	done
	for f in $JAVA_TZ_FILES; do
		say "$f: $(grep -i -e GMT -e zone -e tz "$f" 2>/dev/null | head -5 | tr '\n' ' ')"
	done
	say "kual:"
	find /var/local /var/tmp /mnt/us/extensions /mnt/us/developer -iname '*kual*' 2>/dev/null | head -10 >>"$LOG"
}

pornire() {
	say "--- pornire $(date '+%Y-%m-%d %H:%M')"
	block_ads
	fix_tz
	swap_blanket
	fix_java_tz
	install_early_job
	tz_report
}

automat() {
	say "--- automat $(date '+%Y-%m-%d %H:%M')"
	mntroot rw >>"$LOG" 2>&1
	cat >"$JOB" <<-EOT
		# Ecran de repaus (Meteo Alarm Kindle): ads off and our lock screen at every boot.
		start on started framework
		task
		script
		    S=/mnt/us/extensions/ecranrepaus/bin/ecranrepaus.sh
		    [ -f \$S ] && sh \$S pornire || true
		end script
	EOT
	sync
	mntroot ro >>"$LOG" 2>&1
	say "job: $(cat "$JOB" | grep -c .) randuri in $JOB"
	pornire
	show "Gata. Reporneste Kindle-ul."
}

anuleaza() {
	say "--- anuleaza $(date '+%Y-%m-%d %H:%M')"
	if [ -f "$JOB" ]; then
		mntroot rw >>"$LOG" 2>&1
		rm -f "$JOB"
		sync
		mntroot ro >>"$LOG" 2>&1
		say "job sters"
	fi
	if [ -f "$ADS" ]; then
		rm -f "$ADS" && mkdir "$ADS"; chown framework:javauser "$ADS"; chmod 2775 "$ADS"
		say "$ADS refacut"
	fi
	[ -f "$BAK/tz" ] && cp "$BAK/tz" "$TZ_FILE" && say "fus orar original pus inapoi"
	if [ -f "$JOB_EARLY" ]; then
		mntroot rw >>"$LOG" 2>&1
		rm -f "$JOB_EARLY"
		sync
		mntroot ro >>"$LOG" 2>&1
	fi
	for f in $JAVA_TZ_FILES; do
		b="$BAK/$(basename "$f").orig"
		[ -f "$b" ] && cp "$b" "$f"
	done
	sqlite3 "$DB" "update properties set value='true' where name='adunit.viewable';" >>"$LOG" 2>&1
	say "adunit.viewable=$(ads_value)"
	if [ -n "$(ls "$BAK/screensaver" 2>/dev/null)" ]; then
		mntroot rw >>"$LOG" 2>&1
		cp "$BAK/screensaver"/*.png "$SS_DIR/" 2>>"$LOG"
		sync
		mntroot ro >>"$LOG" 2>&1
		say "screensaver original pus inapoi"
	fi
	show "Anulat. Reporneste Kindle-ul."
}

case "$1" in
	verifica|reclame|ecran|automat|pornire|ora|anuleaza) "$1" ;;
	*) echo "Usage: $0 verifica | reclame | ecran | automat | pornire | anuleaza" ;;
esac
