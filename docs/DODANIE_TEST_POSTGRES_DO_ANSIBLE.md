# Dodanie kontenera testowego PostgreSQL do Ansible

## Obecna sytuacja

Kontener `nc-postgres-test` został utworzony przez Ansible playbook, ale:
- Nie jest w żadnym stacku (nie jest zarządzany przez docker-compose)
- Nie ma wszystkich optymalizacji z analizy
- Nie jest w liście `postgres_instances` w Ansible

## Rozwiązanie: Dodać do Ansible jako osobna instancja

### Opcja A: Dodać jako osobną instancję w postgres_instances (ZALECANE)

Dodajemy kontener testowy do listy `postgres_instances` w Ansible, ale z customową nazwą kontenera.

### Opcja B: Dodać jako osobny playbook/stack

Utworzyć osobny stack dla kontenera testowego zarządzany przez Ansible.

## Rekomendacja: Opcja B - Osobny stack przez Ansible

Najlepsze rozwiązanie to stworzyć osobny stack `test-postgres` zarządzany przez Ansible, który będzie używał przygotowanego `docker-compose.yml`.

## Co trzeba zrobić

### 1. Dodać rolę Ansible dla testowego PostgreSQL

Utworzyć `ansible/roles/postgres-test/` który będzie:
- Zarządzał kontenerem testowym przez docker-compose
- Używał przygotowanego `docker-compose.yml` z `stacks/test-postgres/`
- Miał wszystkie optymalizacje

### 2. Dodać playbook dla testowego PostgreSQL

Dodać do głównego playbooka możliwość zarządzania kontenerem testowym.

## Szybsze rozwiązanie: Ręczna migracja + później Ansible

1. Teraz: Migruj ręcznie używając przygotowanych plików
2. Później: Dodaj do Ansible jako osobny stack

