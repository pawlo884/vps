# Wyjaśnienie opcji wdrożenia - Opcja 1 vs Opcja 2

## 🔍 Różnice między opcjami

### Opcja 1: Nowy kontener (ZALECANE)

**Na czym polega:**
- Tworzy całkowicie **nowy kontener od zera** używając `docker-compose`
- Nie wymaga istniejącego kontenera
- **Najlepsza opcja, jeśli:**
  - Nie masz jeszcze kontenera `nc-postgres-test`
  - Chcesz czysty start z nową konfiguracją
  - Nie masz ważnych danych do zachowania

**Co się dzieje:**
1. Docker Compose tworzy nowy kontener z nową konfiguracją
2. Tworzy nowy volume `nc_postgres_test_data` (jeśli nie istnieje)
3. Inicjalizuje pustą bazę danych PostgreSQL
4. Uruchamia kontener z wszystkimi optymalizacjami

**Kiedy użyć:**
- ✅ Nie masz jeszcze kontenera testowego
- ✅ Możesz rozpocząć z pustą bazą
- ✅ Chcesz najprostsze rozwiązanie

**Komendy:**
```bash
cd ~/vps/stacks/test-postgres
# Edytuj hasło w docker-compose.yml (linia 9)
docker compose up -d
```

---

### Opcja 2: Migracja istniejącego kontenera

**Na czym polega:**
- **Zachowuje dane** z istniejącego kontenera `nc-postgres-test`
- Migruje stary kontener do nowej konfiguracji z docker-compose
- **Najlepsza opcja, jeśli:**
  - Masz już działający kontener z danymi
  - Chcesz zachować istniejące bazy danych
  - Nie chcesz tracić danych testowych

**Co się dzieje:**
1. Skrypt sprawdza czy istnieje kontener `nc-postgres-test`
2. Zatrzymuje istniejący kontener (zachowuje volume z danymi)
3. Usuwa stary kontener (opcjonalnie, po potwierdzeniu)
4. Docker Compose tworzy **nowy kontener** używając **tego samego volume**
5. Wszystkie dane są zachowane!

**Kiedy użyć:**
- ✅ Masz już kontener z danymi testowymi
- ✅ Chcesz zachować istniejące bazy
- ✅ Nie możesz stracić danych

**Komendy:**
```bash
~/vps/scripts/migrate-test-postgres.sh
cd ~/vps/stacks/test-postgres
docker compose up -d
```

---

## 📊 Porównanie wizualne

```
┌─────────────────────────────────────────────────────────┐
│                    OPCJA 1: NOWY                        │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  BRAK KONTENERA → docker compose up → NOWY KONTENER    │
│                                                         │
│  ┌─────────────┐         ┌──────────────┐             │
│  │   PUSTY     │   →→→   │   NOWY       │             │
│  │  (lub brak) │         │  KONTENER    │             │
│  └─────────────┘         └──────────────┘             │
│                                                         │
│  Dane: BRAK / PUSTA BAZA                                │
│  Volume: Tworzony nowy lub użyty pusty                  │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│              OPCJA 2: MIGRACJA                          │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  STARY KONTENER → migracja → NOWY KONTENER (z danymi)  │
│                                                         │
│  ┌─────────────┐         ┌──────────────┐             │
│  │   STARY     │   →→→   │   NOWY       │             │
│  │  KONTENER   │         │  KONTENER    │             │
│  └─────────────┘         └──────────────┘             │
│       │                          │                     │
│       └──────────┬───────────────┘                     │
│                  │                                     │
│            ┌─────▼─────┐                              │
│            │  VOLUME   │  ← DANE ZACHOWANE!           │
│            │  z danymi │                              │
│            └───────────┘                              │
│                                                         │
│  Dane: ZACHOWANE                                       │
│  Volume: Ten sam, z istniejącymi danymi                │
└─────────────────────────────────────────────────────────┘
```

---

## ❓ Którą opcję wybrać?

### Wybierz **Opcję 1**, jeśli:

- ❓ Nie wiesz czy masz kontener testowy
- ✅ Nie masz ważnych danych testowych
- ✅ Chcesz najprostsze rozwiązanie
- ✅ To pierwsza konfiguracja

**Sprawdź czy masz kontener:**
```bash
docker ps -a | grep nc-postgres-test
```

Jeśli **nie ma wyniku** → użyj Opcji 1

---

### Wybierz **Opcję 2**, jeśli:

- ✅ Masz działający kontener `nc-postgres-test`
- ✅ Masz ważne dane testowe w bazie
- ✅ Nie możesz stracić danych
- ✅ Chcesz zachować istniejące bazy

**Sprawdź czy masz kontener z danymi:**
```bash
docker ps -a | grep nc-postgres-test
docker volume ls | grep nc_postgres_test_data
```

Jeśli **są oba** → użyj Opcji 2

---

## 🔧 Co się dzieje z danymi?

### Opcja 1:
```
Volume: Tworzony nowy (lub pusty)
Baza: Pusta (nowa inicjalizacja)
Dane: BRAK
```

### Opcja 2:
```
Volume: TEN SAM (zachowane dane)
Baza: ZACHOWANA (wszystkie tabele i dane)
Dane: ZACHOWANE ✅
```

---

## ⚠️ Ważne uwagi

### Opcja 1:
- ⚠️ Jeśli istnieje volume z danymi, zostanie użyty (dane mogą być)
- ⚠️ Jeśli chcesz całkowicie nową bazę, usuń volume:
  ```bash
  docker volume rm nc_postgres_test_data
  ```

### Opcja 2:
- ✅ Dane są zachowane, ale zawsze rób backup przed migracją!
- ✅ Volume pozostaje ten sam, więc dane są bezpieczne
- ⚠️ Sprawdź czy hasło w docker-compose.yml jest takie samo jak w starym kontenerze

---

## 📝 Przykładowe scenariusze

### Scenariusz 1: "Nie mam kontenera testowego"
→ **Opcja 1** (Nowy kontener)

### Scenariusz 2: "Mam kontener, ale mogę zacząć od zera"
→ **Opcja 1** (Nowy kontener)

### Scenariusz 3: "Mam kontener z ważnymi danymi testowymi"
→ **Opcja 2** (Migracja)

### Scenariusz 4: "Nie jestem pewien, co mam"
→ Sprawdź:
```bash
docker ps -a | grep nc-postgres-test
```
Jeśli nie ma → Opcja 1  
Jeśli jest → Opcja 2

---

## 🚀 Szybka decyzja

**Uruchom to, aby sprawdzić:**
```bash
if docker ps -a | grep -q nc-postgres-test; then
    echo "✅ Masz kontener → Opcja 2 (Migracja)"
else
    echo "❌ Brak kontenera → Opcja 1 (Nowy)"
fi
```

**Lub po prostu:**
- Nie jesteś pewien? → **Opcja 1** (najbezpieczniejsza)
- Masz dane? → **Opcja 2** (zachowuje dane)

