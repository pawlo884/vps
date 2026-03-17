# Rozwiązywanie problemu wolnego ładowania strony /nginx/proxy w NPM

## Objawy

- Strona `http://localhost:81/nginx/proxy` ładuje się bardzo długo
- W logach NPM pojawia się: `proxy_hosts:list undefined Permission Denied`
- Strona HTML ładuje się szybko (curl pokazuje HTTP 200), ale frontend nie może załadować danych

## Przyczyna

Problem wynika z **błędu autoryzacji**:
- Frontend JavaScript próbuje załadować listę proxy hosts przez API
- API zwraca błąd "Permission Denied" 
- JavaScript czeka na timeout przed wyświetleniem błędu
- To powoduje długie ładowanie strony

## Rozwiązanie

### 1. Wyloguj się i zaloguj ponownie

**Najprostsze rozwiązanie:**
- Wyloguj się z NPM (logout)
- Wyczyść cache/cookies przeglądarki dla `localhost:81`
- Zaloguj się ponownie

### 2. Sprawdź czy jesteś zalogowany

W konsoli przeglądarki (F12 → Console) sprawdź czy pojawiają się błędy:
```javascript
// Otwórz Developer Tools (F12)
// Sprawdź zakładkę Network
// Odśwież stronę /nginx/proxy
// Sprawdź czy requesty do /api/... zwracają 401/403
```

### 3. Wyczyść sesję w przeglądarce

Jeśli problem nadal występuje:
```bash
# W przeglądarce:
# 1. Otwórz Developer Tools (F12)
# 2. Application → Storage → Clear site data
# 3. Lub użyj trybu incognito
```

### 4. Sprawdź logi NPM

```bash
docker logs nginx-proxy-manager --tail 50 | grep -i "error\|permission"
```

### 5. Jeśli to nie pomaga - sprawdź bazę danych

Problem może wynikać z przywróconej bazy danych, gdzie sesje/tokeny są nieważne:

```bash
# Sprawdź czy baza istnieje i ma poprawne uprawnienia
docker exec nginx-proxy-manager ls -lah /data/database.sqlite

# Sprawdź status bazy
docker logs nginx-proxy-manager | grep -i "database version"
```

### 6. Ostateczne rozwiązanie - pełny reset sesji

Jeśli problem nadal występuje:

1. **Wyczyść wszystkie cookies i storage w przeglądarce**
2. **Zrestartuj kontener NPM:**
   ```bash
   docker restart nginx-proxy-manager
   ```
3. **Zaloguj się ponownie**

## Dlaczego to się dzieje?

Po przywróceniu backupu bazy danych:
- Stare sesje użytkowników są nieważne
- Tokeny autoryzacyjne nie pasują do nowej sesji
- Frontend próbuje użyć starego tokena, który jest odrzucany
- API zwraca "Permission Denied", ale frontend czeka na timeout

## Zapobieganie

- Po przywróceniu backupu zawsze wyloguj się i zaloguj ponownie
- Rozważ używanie trybu incognito/private podczas testowania po zmianach w bazie
- Regularnie sprawdzaj logi NPM pod kątem błędów autoryzacji

## Status bazy danych

Jeśli widzisz `Current database version: none` w logach:
- To **NIE** jest błąd - to tylko informacja podczas startu
- NPM automatycznie migruje bazę jeśli potrzebne
- Jeśli nie widzisz błędów migracji w logach, baza jest OK
