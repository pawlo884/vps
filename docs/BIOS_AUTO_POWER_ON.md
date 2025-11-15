# Konfiguracja Auto Power-On po awarii zasilania

## HP ProDesk 400 G5 Desktop Mini

### Włączenie Auto Power-On w BIOS

1. **Wejście do BIOS:**
   - Przy starcie naciśnij `F10` (lub `Esc` → `F10`)
   - Alternatywnie: `F2` lub `Del`

2. **Lokalizacja opcji:**
   - Przejdź do: **Power Management** lub **Advanced** → **Power Options**
   - Szukaj jednej z opcji:
     - "After Power Loss"
     - "AC Recovery"
     - "Power On After Power Loss"
     - "Restore AC Power Loss"

3. **Ustawienie:**
   - Wybierz: **"Power On"** lub **"Always On"**
   - **NIE** wybieraj: "Stay Off" lub "Last State"

4. **Zapis:**
   - `F10` → Save & Exit
   - Lub: `Esc` → Save Changes and Exit

### Weryfikacja

Po ustawieniu w BIOS, możesz przetestować:
1. Wyłącz serwer (shutdown)
2. Odłącz zasilanie na kilka sekund
3. Podłącz zasilanie ponownie
4. Serwer powinien automatycznie się włączyć

### Uwagi

- **To ustawienie jest w BIOS, nie w systemie operacyjnym**
- Nie można tego ustawić przez Ansible/Linux
- Wymaga fizycznego dostępu do urządzenia
- Działa niezależnie od systemu operacyjnego (Linux/Windows)

### Alternatywy

Jeśli masz UPS (zasilacz awaryjny):
- Skonfiguruj `nut` (Network UPS Tools) do bezpiecznego wyłączania
- UPS może utrzymać zasilanie przez kilka minut
- System wyłączy się bezpiecznie, a po przywróceniu zasilania włączy się automatycznie (dzięki BIOS)


