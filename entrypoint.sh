#!/bin/bash
# Entrypoint zgodny z konwencja wings / elytra.
#
# Panel podaje polecenie startowe w zmiennej STARTUP, z placeholderami
# {{ZMIENNA}}, ktore trzeba rozwinac ze zmiennych srodowiskowych eggu.
set -u

cd /home/container || exit 1

# Panel wypisuje to w konsoli — ulatwia diagnoze sieci kontenera.
INTERNAL_IP="$(ip route get 1 2>/dev/null | awk '{print $(NF-2); exit}')"
export INTERNAL_IP

# TeamSpeak 6 czyta port glosu ze zmiennej TSSERVER_DEFAULT_PORT, a panel
# przydziela port w SERVER_PORT. Ustawiamy jako zabezpieczenie na wypadek,
# gdyby ktos usunal flage --default-voice-port z polecenia startowego.
if [ -n "${SERVER_PORT:-}" ] && [ -z "${TSSERVER_DEFAULT_PORT:-}" ]; then
    export TSSERVER_DEFAULT_PORT="${SERVER_PORT}"
fi

# {{ZMIENNA}} -> ${ZMIENNA}, a eval ponizej podstawia wartosci z otoczenia.
MODIFIED_STARTUP="$(echo "${STARTUP:-}" | sed -e 's/{{/${/g' -e 's/}}/}/g')"
printf ':/home/container$ %s\n' "${MODIFIED_STARTUP}"

if [ -z "${MODIFIED_STARTUP//[[:space:]]/}" ]; then
    echo "BLAD: zmienna STARTUP jest pusta — panel nie przekazal polecenia startowego." >&2
    exit 1
fi

# exec sprawia, ze tsserver zostaje PID 1 i dostaje SIGINT/SIGTERM od panelu
# bezposrednio. Bez tego sygnal "Stop" trafialby do basha, a serwer nie
# zamykalby sie czysto (ryzyko uszkodzenia bazy SQLite).
eval "exec ${MODIFIED_STARTUP}"
