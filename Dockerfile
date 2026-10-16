# TeamSpeak 6 Server — obraz pod egg panelu Pterodactyl / Pyrodactyl
#
# Binarki bierzemy wprost z oficjalnego obrazu TeamSpeak Systems (etap `upstream`),
# wiec nie polegamy na zadnych adresach do pobierania, ktore w becie i tak sie zmieniaja.
# Nie dziedziczymy jednak po nim calego obrazu, bo deklaruje on VOLUME /var/tsserver/ —
# przy kazdym starcie kontenera Docker tworzylby anonimowy wolumen, ktory tylko
# zasmieca hosta. Dane serwera i tak trzymamy w /home/container, czyli tam, gdzie
# panel montuje katalog serwera i gdzie widzi je menedzer plikow.
#
# Wersje przypinamy swiadomie — podniesienie serwera to zmiana TS_VERSION.
# Kazda beta ma wbudowana licencje na ok. 3 miesiace: po jej koncu serwer konczy start
# bledem "The default license has expired" (beta12.1 — 10.2026). 6.0.0-beta13.1 jest
# wazna do 2026-12-01, wiec przed ta data trzeba podniesc wersje ponownie.

ARG TS_VERSION=6.0.0-beta13.1
FROM teamspeaksystems/teamspeak6-server:${TS_VERSION} AS upstream

FROM debian:bookworm-slim

ARG TS_VERSION
LABEL org.opencontainers.image.title="TeamSpeak 6 Server (Pterodactyl egg)" \
      org.opencontainers.image.description="TeamSpeak 6 Server w obrazie zgodnym z konwencja wings/elytra" \
      org.opencontainers.image.source="https://github.com/Guardly-Enterprise/teamspeak6-server-egg" \
      org.opencontainers.image.version="${TS_VERSION}" \
      org.opencontainers.image.vendor="Guardly"

# iproute2 -> entrypoint ustala INTERNAL_IP przez `ip route`
# curl      -> uzywane przez skrypty startowe eggow
# tzdata    -> serwer potrafi logowac w czasie lokalnym (--log-timezone local)
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      iproute2 \
      tzdata \
 && rm -rf /var/lib/apt/lists/*

# Binarka + biblioteki + katalogi SQL i dokumentacja query (54 MB)
COPY --from=upstream /opt/tsserver /opt/tsserver

# Sciezki, ktore w oryginalnym obrazie sa ustawione przez ENV. Domyslne wartosci
# serwera sa RELATYWNE (`sql`, `create_sqlite`), wiec bez tego serwer szukalby
# plikow SQL w /home/container i nie wystartowalby.
ENV TSSERVER_DATABASE_SQL_PATH=/opt/tsserver/sql/ \
    TSSERVER_DATABASE_SQL_CREATE_PATH=/opt/tsserver/sql/create_sqlite/ \
    TSSERVER_QUERY_DOCUMENTATION_PATH=/opt/tsserver/serverquerydocs

RUN useradd -m -d /home/container -s /bin/bash container
ENV USER=container \
    HOME=/home/container

WORKDIR /home/container
COPY entrypoint.sh /entrypoint.sh
RUN chmod 755 /entrypoint.sh

USER container
CMD [ "/bin/bash", "/entrypoint.sh" ]
