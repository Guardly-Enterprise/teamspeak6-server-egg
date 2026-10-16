# TeamSpeak 6 Server — obraz Docker + egg dla panelu

Serwer [TeamSpeak 6](https://github.com/teamspeak/teamspeak6-server) (beta) opakowany
w obraz zgodny z konwencją **wings / elytra**, wraz z gotowym eggiem do importu
w panelu Pterodactyl / Pyrodactyl.

## Jak to jest zbudowane

Binarki serwera **nie są pobierane w trakcie instalacji** — pochodzą wprost
z oficjalnego obrazu `teamspeaksystems/teamspeak6-server`, skopiowane w builddzie
wieloetapowym. Dzięki temu:

* nie zależymy od adresów do pobierania, które w becie i tak się zmieniają,
* wersja jest przypięta jawnie (`ARG TS_VERSION` w `Dockerfile`),
* instalacja serwera w panelu trwa sekundę, bo nie ma czego ściągać.

Nie dziedziczymy jednak po oficjalnym obrazie, bo deklaruje on
`VOLUME /var/tsserver/` — przy każdym starcie kontenera Docker tworzyłby
anonimowy wolumen, który tylko zaśmieca hosta. Dane serwera trzymamy
w `/home/container`, czyli tam, gdzie panel montuje katalog serwera: widać je
w menedżerze plików i obejmują je backupy panelu.

## Czego wymaga w panelu

| Zasób | Wartość | Uwagi |
|---|---|---|
| alokacja podstawowa | port **UDP** | głos; panel podaje go w `SERVER_PORT` |
| alokacja dodatkowa | port **TCP** (domyślnie 30033) | transfer plików, zmienna `TS_FILETRANSFER_PORT` |
| alokacja dodatkowa | port **TCP** (domyślnie 10080) | tylko jeśli włączasz ServerQuery HTTP |
| RAM | ~200 MB | serwer startuje na ~50 MB |

> Port głosu to **UDP**. Alokacja w panelu musi mieć otwarty ruch UDP, inaczej
> klient połączy się i zaraz wypadnie.

## Import eggu

1. Panel → **Admin → Nests → Import Egg**, wskaż `egg-teamspeak6-server.json`.
2. Utwórz serwer na tym eggu, przypisz alokację UDP jako podstawową.
3. Ustaw `TS_FILETRANSFER_PORT` na drugi przydzielony port TCP.

## Pierwsze uruchomienie

Serwer wypisuje w konsoli **jednorazowo** dane, których nie da się odzyskać później:

```
Server Query Admin Account created
loginname= "serveradmin", password= "..."
apikey= "..."
...
ServerAdmin privilege key created
```

Skopiuj je od razu. Klucz uprawnień wklejasz w kliencie:
**Uprawnienia → Użyj klucza uprawnień**.

Jeśli wolisz z góry znane hasło do ServerQuery, ustaw zmienną
`TSSERVER_QUERY_ADMIN_PASSWORD` przed pierwszym startem.

## Licencja serwera

Bez pliku `licensekey.dat` serwer działa w trybie bezpłatnym: **1 serwer wirtualny
i 32 sloty**, z licencją odnawianą przez TeamSpeaka co dwa miesiące. Własny plik
licencyjny wgraj do katalogu głównego serwera (`/home/container/licensekey.dat`)
i zrestartuj.

**Licencje TeamSpeak 3 nie działają z serwerem 6** — to osobny produkt.

## Zmienne eggu

| Zmienna | Domyślnie | Znaczenie |
|---|---|---|
| `TSSERVER_LICENSE_ACCEPTED` | `accept` | wymagane, inaczej serwer nie wystartuje |
| `TS_FILETRANSFER_PORT` | `30033` | port TCP transferu plików |
| `TSSERVER_QUERY_HTTP_ENABLED` | `0` | ServerQuery po HTTP |
| `TSSERVER_QUERY_HTTP_PORT` | `10080` | port ServerQuery HTTP |
| `TSSERVER_QUERY_ADMIN_PASSWORD` | pusta | nadpisuje hasło konta `serveradmin` |
| `TSSERVER_APPEND_LOGS` | `1` | jeden ciągły plik logu zamiast nowego przy każdym starcie |

Serwer czyta **każdą** opcję z `CONFIG.md` upstreamu przez zmienne `TSSERVER_*`,
więc dowolną z nich możesz dodać w panelu bez zmiany eggu — np.
`TSSERVER_QUERY_SSH_ENABLED`, `TSSERVER_DATABASE_PLUGIN` (MariaDB zamiast SQLite)
czy `TSSERVER_LOG_TIMEZONE`.

## Podniesienie wersji serwera

Zmień `ARG TS_VERSION` w `Dockerfile` na nowy tag z
[Docker Huba](https://hub.docker.com/r/teamspeaksystems/teamspeak6-server/tags),
zacommituj — CI zbuduje i wypchnie `ghcr.io/guardly-enterprise/teamspeak6-server:latest`.
Restart serwera w panelu pobierze nowy obraz.

Baza SQLite jest migrowana przez serwer automatycznie przy starcie
(`updated permissions to version N`). **Zrób backup przed skokiem wersji** — beta
nie gwarantuje kompatybilności wstecz.

## Test poza panelem

```bash
mkdir -p ./dane && sudo chown 996:995 ./dane
docker compose -f docker-compose.test.yml up --build
```

`996:995` to UID/GID, z jakim elytra uruchamia kontenery na naszym node
(`grep -A3 'user:' /etc/elytra/config.yml`).

## Co zostało sprawdzone

Obraz przetestowany na Debianie 12, Docker 29.7.2, w warunkach odtwarzających panel:

* serwer **6.0.0-beta13.1** startuje jako UID 996 i zapisuje dane do `/home/container`
  (licencja bety ważna do 2026-12-01; beta12.1 od 10.2026 kończy start błędem
  `The default license has expired`),
* `tsserver` jest **PID 1**, więc `SIGINT` z przycisku *Stop* zamyka go czysto
  (kod wyjścia 0, `Received signal SIGINT, shutting down` → `stopped`) — bez tego
  ryzykowałbyś uszkodzenie bazy SQLite,
* nasłuch potwierdzony na `0.0.0.0:9987/udp` i `0.0.0.0:30033/tcp`,
* **nie powstaje żaden anonimowy wolumen** przy starcie kontenera.

## Znane ograniczenia

* TeamSpeak 6 Server jest w **becie** — upstream sam ostrzega, że wydania służą
  do testów.
* Wykrywanie startu w eggu opiera się na napisie `listening on 0.0.0.0:`. Jeśli
  ustawisz `TSSERVER_VOICE_IP` na konkretny adres, panel nie rozpozna momentu
  uruchomienia i serwer zostanie w stanie *starting* — wtedy podmień `done`
  w konfiguracji eggu.
* Obraz waży ~226 MB (oficjalny 212 MB); różnica to `iproute2`, `curl` i `tzdata`,
  których wymaga entrypoint panelu.
