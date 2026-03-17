# Szybki start - Testowy PostgreSQL

## ✅ Co zostało przygotowane

1. **Kompletna konfiguracja Docker Compose** z optymalizacjami
2. **Plik postgresql.conf** z ustawieniami TCP keepalive
3. **Skrypty pomocnicze** do migracji i szybkiej poprawki
4. **Pełna dokumentacja** wdrożenia

## 🚀 Szybkie uruchomienie

```bash
cd ~/vps/stacks/test-postgres
docker compose up -d
```

## 📋 Opcje wdrożenia

### Opcja 1: Nowy kontener (ZALECANE)
```bash
cd ~/vps/stacks/test-postgres
docker compose up -d
```

### Opcja 2: Migracja istniejącego kontenera
```bash
~/vps/scripts/migrate-test-postgres.sh
cd ~/vps/stacks/test-postgres
docker compose up -d
```

### Opcja 3: Szybka poprawka (tylko TCP keepalive)
```bash
~/vps/scripts/fix-test-postgres-quick.sh
```

## 🔍 Weryfikacja

```bash
# Status
docker compose ps

# Logi
docker compose logs -f postgres-test

# Test połączenia
docker exec nc-postgres-test psql -U testuser -d testdb -c "SELECT version();"
```

## 📚 Dokumentacja

- **DEPLOYMENT.md** - Szczegółowy przewodnik wdrożenia
- **README.md** - Opis konfiguracji i testów
- **POSTGRES_TEST_OPTIMIZATION.md** - Pełna analiza problemu i rozwiązania

## 🎯 Rozwiązane problemy

✅ Healthcheck - kontener jest gotowy przed akceptacją połączeń  
✅ TCP Keepalive - brak lagu przy pierwszym połączeniu  
✅ Limity logowania - kontrola rozmiaru logów  
✅ Optymalizacje PostgreSQL - lepsza wydajność  
✅ Limity zasobów - stabilność systemu  

## ⚠️ Uwaga

Przed uruchomieniem sprawdź i ustaw hasło w `docker-compose.yml` (linia 9).




