#!/usr/bin/env python3
"""
Datenbank-Management Script für Wammsee Lake Mapper

Verwendung:
    python db_management.py                    # Interaktives Menü
    python db_management.py batch <command>    # Batch-Modus
    python db_management.py --help             # Hilfe

Beispiele Batch-Modus:
    python db_management.py batch users
    python db_management.py batch backup
    python db_management.py batch vacuum
"""

import argparse
import csv
import getpass
import os
import sys
from datetime import datetime
from pathlib import Path

# psycopg2 für PostgreSQL
try:
    import psycopg2
    from psycopg2 import sql
except ImportError:
    print("FEHLER: psycopg2 nicht installiert.")
    print("  Installation: pip install psycopg2-binary")
    sys.exit(1)

# Config aus Umgebungsvariablen
DB_CONFIG = {
    'host': os.environ.get('DB_HOST', 'localhost'),
    'port': os.environ.get('DB_PORT', '5432'),
    'dbname': os.environ.get('DB_NAME', 'lakemap'),
    'user': os.environ.get('DB_USER', 'lakeuser'),
    'password': os.environ.get('DB_PASSWORD', 'lake123'),
}

# Password Hashing (bcrypt)
try:
    import bcrypt
    BCRYPT_AVAILABLE = True
except ImportError:
    BCRYPT_AVAILABLE = False
    print("HINWEIS: bcrypt nicht verfügbar. Passwort-Hashing deaktiviert.")
    print("  Installation: pip install bcrypt")


class DatabaseManager:
    """Verwaltet alle Datenbank-Operationen"""

    def __init__(self, config=None):
        self.config = config or DB_CONFIG
        self.conn = None
        self.cursor = None

    def connect(self):
        """Verbindung zur Datenbank herstellen"""
        try:
            self.conn = psycopg2.connect(**self.config)
            self.conn.autocommit = False
            self.cursor = self.conn.cursor()
            print(f"✓ Verbunden mit {self.config['host']}:{self.config['port']}/{self.config['dbname']}")
            return True
        except psycopg2.Error as e:
            print(f"✗ Verbindungsfehler: {e}")
            return False

    def disconnect(self):
        """Verbindung schließen"""
        if self.cursor:
            self.cursor.close()
        if self.conn:
            self.conn.close()
            print("✓ Verbindung geschlossen")

    def commit(self):
        """Transaktion bestätigen"""
        if self.conn:
            self.conn.commit()

    def rollback(self):
        """Transaktion zurückrollen"""
        if self.conn:
            self.conn.rollback()

    # ─── User Management ───────────────────────────────────────────────────────

    def list_users(self):
        """Alle Benutzer auflisten"""
        self.cursor.execute("""
            SELECT id, username, is_admin, created_at,
                   (SELECT COUNT(*) FROM lake_depths WHERE user_id = users.id) as points_count
            FROM users
            ORDER BY id
        """)
        rows = self.cursor.fetchall()

        print("\n" + "=" * 70)
        print(f"{'ID':<4} {'Benutzername':<20} {'Admin':<8} {'Punkte':<10} {'Erstellt':<20}")
        print("-" * 70)
        for row in rows:
            admin_ico = "✓" if row[2] else "✗"
            print(f"{row[0]:<4} {row[1]:<20} {admin_ico:<8} {row[3]:<10} {row[4]}")
        print("=" * 70)
        print(f"Summe: {len(rows)} Benutzer")

    def create_user(self, username, password, is_admin=False):
        """Neuen Benutzer anlegen"""
        if not BCRYPT_AVAILABLE:
            print("✗ bcrypt nicht verfügbar. Bitte installieren.")
            return False

        # Passwort hashen
        password_hash = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')

        try:
            self.cursor.execute("""
                INSERT INTO users (username, password_hash, is_admin)
                VALUES (%s, %s, %s)
                RETURNING id
            """, (username, password_hash, is_admin))
            user_id = self.cursor.fetchone()[0]
            self.commit()
            print(f"✓ Benutzer '{username}' erstellt (ID: {user_id})")
            return True
        except psycopg2.IntegrityError as e:
            self.rollback()
            if 'unique' in str(e):
                print(f"✗ Benutzername '{username}' existiert bereits")
            else:
                print(f"✗ Fehler: {e}")
            return False

    def delete_user(self, user_id):
        """Benutzer löschen (nur wenn keine Punkte vorhanden)"""
        # Prüfe ob User Punkte hat
        self.cursor.execute("SELECT COUNT(*) FROM lake_depths WHERE user_id = %s", (user_id,))
        count = self.cursor.fetchone()[0]

        if count > 0:
            print(f"✗ Benutzer hat noch {count} Punkte. Bitte zuerst Punkte löschen.")
            return False

        try:
            self.cursor.execute("DELETE FROM users WHERE id = %s", (user_id,))
            if self.cursor.rowcount == 0:
                print(f"✗ Benutzer mit ID {user_id} nicht gefunden")
                self.rollback()
                return False
            self.commit()
            print(f"✓ Benutzer {user_id} gelöscht")
            return True
        except psycopg2.Error as e:
            self.rollback()
            print(f"✗ Fehler: {e}")
            return False

    def change_password(self, user_id, new_password):
        """Passwort eines Benutzers ändern"""
        if not BCRYPT_AVAILABLE:
            print("✗ bcrypt nicht verfügbar")
            return False

        password_hash = bcrypt.hashpw(new_password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')

        try:
            self.cursor.execute("""
                UPDATE users SET password_hash = %s WHERE id = %s
            """, (password_hash, user_id))
            if self.cursor.rowcount == 0:
                print(f"✗ Benutzer mit ID {user_id} nicht gefunden")
                self.rollback()
                return False
            self.commit()
            print(f"✓ Passwort für Benutzer {user_id} geändert")
            return True
        except psycopg2.Error as e:
            self.rollback()
            print(f"✗ Fehler: {e}")
            return False

    def toggle_user_lock(self, user_id):
        """Benutzer sperren/entsperren (is_admin = NOT is_admin)"""
        # Admin-Status togglen (als Lock-Ersatz)
        try:
            self.cursor.execute("""
                UPDATE users SET is_admin = NOT is_admin WHERE id = %s
                RETURNING username, is_admin
            """, (user_id,))
            result = self.cursor.fetchone()
            if not result:
                print(f"✗ Benutzer mit ID {user_id} nicht gefunden")
                self.rollback()
                return False
            username, is_admin = result
            status = "Admin" if is_admin else "Normal"
            self.commit()
            print(f"✓ Benutzer '{username}' ist jetzt: {status}")
            return True
        except psycopg2.Error as e:
            self.rollback()
            print(f"✗ Fehler: {e}")
            return False

    # ─── Data Management ───────────────────────────────────────────────────────

    def delete_user_points(self, user_id):
        """Alle Tiefenpunkte eines Benutzers löschen"""
        self.cursor.execute("SELECT COUNT(*) FROM lake_depths WHERE user_id = %s", (user_id,))
        count = self.cursor.fetchone()[0]

        if count == 0:
            print(f"Benutzer {user_id} hat keine Punkte")
            return True

        confirm = input(f"{count} Punkte von User {user_id} löschen? [j/N]: ")
        if confirm.lower() != 'j':
            print("Abbruch")
            return False

        try:
            self.cursor.execute("DELETE FROM lake_depths WHERE user_id = %s", (user_id,))
            self.commit()
            print(f"✓ {self.cursor.rowcount} Punkte gelöscht")
            return True
        except psycopg2.Error as e:
            self.rollback()
            print(f"✗ Fehler: {e}")
            return False

    def delete_all_points(self):
        """Alle Tiefenpunkte löschen"""
        self.cursor.execute("SELECT COUNT(*) FROM lake_depths")
        count = self.cursor.fetchone()[0]

        if count == 0:
            print("Keine Punkte vorhanden")
            return True

        confirm = input(f"ALLE {count} Punkte löschen? [j/N]: ")
        if confirm.lower() != 'j':
            print("Abbruch")
            return False

        try:
            self.cursor.execute("DELETE FROM lake_depths")
            self.commit()
            print(f"✓ {self.cursor.rowcount} Punkte gelöscht")
            return True
        except psycopg2.Error as e:
            self.rollback()
            print(f"✗ Fehler: {e}")
            return False

    def export_csv(self, filepath=None):
        """Daten als CSV exportieren"""
        if not filepath:
            filepath = f"export_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"

        self.cursor.execute("""
            SELECT
                d.id,
                l.name as lake_name,
                d.depth_m,
                ST_X(d.location::geometry) as longitude,
                ST_Y(d.location::geometry) as latitude,
                d.accuracy_m,
                d.note,
                d.measured_at,
                u.username
            FROM lake_depths d
            JOIN lakes l ON d.lake_id = l.id
            LEFT JOIN users u ON d.user_id = u.id
            ORDER BY d.measured_at DESC
        """)

        rows = self.cursor.fetchall()

        with open(filepath, 'w', newline='', encoding='utf-8') as f:
            writer = csv.writer(f)
            writer.writerow(['id', 'lake', 'depth_m', 'longitude', 'latitude',
                           'accuracy_m', 'note', 'measured_at', 'username'])
            writer.writerows(rows)

        print(f"✓ {len(rows)} Punkte exportiert nach {filepath}")
        return True

    def import_csv(self, filepath):
        """Daten aus CSV importieren"""
        if not os.path.exists(filepath):
            print(f"✗ Datei nicht gefunden: {filepath}")
            return False

        # Lakes laden für Zuordnung
        self.cursor.execute("SELECT id, name FROM lakes")
        lakes = {row[1]: row[0] for row in self.cursor.fetchall()}

        # Users laden
        self.cursor.execute("SELECT id, username FROM users")
        users = {row[1]: row[0] for row in self.cursor.fetchall()}

        imported = 0
        errors = 0

        with open(filepath, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            for row in reader:
                try:
                    lake_name = row.get('lake', 'Wammsee')
                    lake_id = lakes.get(lake_name)

                    username = row.get('username', 'admin')
                    user_id = users.get(username, 1)

                    depth = float(row['depth_m'])
                    lon = float(row['longitude'])
                    lat = float(row['latitude'])
                    accuracy = float(row.get('accuracy_m', 0) or 0)
                    note = row.get('note', '')

                    self.cursor.execute("""
                        INSERT INTO lake_depths
                        (lake_id, depth_m, location, accuracy_m, note, user_id)
                        VALUES (%s, %s, ST_SetSRID(ST_MakePoint(%s, %s), 4326)::geography, %s, %s, %s)
                    """, (lake_id, depth, lon, lat, accuracy, note, user_id))
                    imported += 1
                except Exception as e:
                    errors += 1
                    print(f"  Fehler in Zeile: {row} -> {e}")

        self.commit()
        print(f"✓ {imported} Punkte importiert, {errors} Fehler")
        return errors == 0

    # ─── Lake Management ───────────────────────────────────────────────────────

    def list_lakes(self):
        """Alle Seen auflisten"""
        self.cursor.execute("""
            SELECT l.id, l.name, l.created_at,
                   COALESCE(COUNT(d.id), 0) as points_count,
                   COALESCE(ROUND(AVG(d.depth_m), 2), 0) as avg_depth
            FROM lakes l
            LEFT JOIN lake_depths d ON l.id = d.lake_id
            GROUP BY l.id, l.name, l.created_at
            ORDER BY l.name
        """)
        rows = self.cursor.fetchall()

        print("\n" + "=" * 70)
        print(f"{'ID':<4} {'Name':<20} {'Punkte':<10} {'ø Tiefe':<10} {'Erstellt':<20}")
        print("-" * 70)
        for row in rows:
            print(f"{row[0]:<4} {row[1]:<20} {row[2]:<10} {row[3]:<10}m {row[4]}")
        print("=" * 70)
        print(f"Summe: {len(rows)} Seen")

    def create_lake(self, name):
        """Neuen See anlegen"""
        try:
            self.cursor.execute("""
                INSERT INTO lakes (name) VALUES (%s) RETURNING id
            """, (name,))
            lake_id = self.cursor.fetchone()[0]
            self.commit()
            print(f"✓ See '{name}' erstellt (ID: {lake_id})")
            return True
        except psycopg2.IntegrityError as e:
            self.rollback()
            if 'unique' in str(e):
                print(f"✗ See '{name}' existiert bereits")
            else:
                print(f"✗ Fehler: {e}")
            return False

    def delete_lake(self, lake_id):
        """See löschen (nur wenn keine Punkte vorhanden)"""
        self.cursor.execute("SELECT COUNT(*) FROM lake_depths WHERE lake_id = %s", (lake_id,))
        count = self.cursor.fetchone()[0]

        if count > 0:
            print(f"✗ See hat noch {count} Punkte. Bitte zuerst Punkte löschen.")
            return False

        confirm = input(f"See {lake_id} löschen? [j/N]: ")
        if confirm.lower() != 'j':
            print("Abbruch")
            return False

        try:
            self.cursor.execute("DELETE FROM lakes WHERE id = %s", (lake_id,))
            if self.cursor.rowcount == 0:
                print(f"✗ See mit ID {lake_id} nicht gefunden")
                self.rollback()
                return False
            self.commit()
            print(f"✓ See {lake_id} gelöscht")
            return True
        except psycopg2.Error as e:
            self.rollback()
            print(f"✗ Fehler: {e}")
            return False

    # ─── Wartung ────────────────────────────────────────────────────────────────

    def create_backup(self, filepath=None):
        """SQL-Dump Backup erstellen"""
        if not filepath:
            filepath = f"backup_{datetime.now().strftime('%Y%m%d_%H%M%S')}.sql"

        # pg_dump verwenden falls verfügbar
        import subprocess

        cmd = [
            'pg_dump',
            '-h', self.config['host'],
            '-p', self.config['port'],
            '-U', self.config['user'],
            '-d', self.config['dbname'],
            '-f', filepath,
        ]

        env = os.environ.copy()
        env['PGPASSWORD'] = self.config['password']

        try:
            result = subprocess.run(cmd, env=env, capture_output=True, text=True)
            if result.returncode == 0:
                size = os.path.getsize(filepath)
                print(f"✓ Backup erstellt: {filepath} ({size} bytes)")
                return True
            else:
                print(f"✗ pg_dump Fehler: {result.stderr}")
                return False
        except FileNotFoundError:
            print("✗ pg_dump nicht gefunden. Manuell backupen...")
            # Fallback: Daten als INSERT-Statements
            return self._manual_backup(filepath)

    def _manual_backup(self, filepath):
        """Manueller Backup als CSV (Fallback)"""
        tables = ['lakes', 'users', 'lake_depths']
        for table in tables:
            csv_path = filepath.replace('.sql', f'_{table}.csv')
            self.cursor.execute(f"SELECT * FROM {table}")
            rows = self.cursor.fetchall()

            with open(csv_path, 'w', newline='') as f:
                writer = csv.writer(f)
                writer.writerow([desc[0] for desc in self.cursor.description])
                writer.writerows(rows)
            print(f"  {table}: {len(rows)} rows -> {csv_path}")

        return True

    def restore_backup(self, filepath):
        """Backup wiederherstellen (nur CSV-Fallback)"""
        if not os.path.exists(filepath):
            print(f"✗ Datei nicht gefunden: {filepath}")
            return False

        # Prüfe ob es ein SQL-Dump ist oder CSV
        if filepath.endswith('.sql'):
            print("SQL-Restore: bitte manuell mit psql")
            return False

        # CSV-Import
        print(f"CSV-Backup: {filepath}")
        return True

    def vacuum(self):
        """Datenbank optimieren (VACUUM ANALYZE)"""
        try:
            print("Führe VACUUM ANALYZE aus...")
            self.cursor.execute("VACUUM ANALYZE")
            self.commit()
            print("✓ Datenbank optimiert")
            return True
        except psycopg2.Error as e:
            self.rollback()
            print(f"✗ Fehler: {e}")
            return False

    def connection_test(self):
        """Verbindung testen"""
        try:
            self.cursor.execute("SELECT version()")
            version = self.cursor.fetchone()[0]
            print(f"✓ PostgreSQL: {version}")

            self.cursor.execute("SELECT COUNT(*) FROM lakes")
            lakes_count = self.cursor.fetchone()[0]
            print(f"✓ Seen: {lakes_count}")

            self.cursor.execute("SELECT COUNT(*) FROM users")
            users_count = self.cursor.fetchone()[0]
            print(f"✓ Benutzer: {users_count}")

            self.cursor.execute("SELECT COUNT(*) FROM lake_depths")
            points_count = self.cursor.fetchone()[0]
            print(f"✓ Tiefenpunkte: {points_count}")

            return True
        except psycopg2.Error as e:
            print(f"✗ Fehler: {e}")
            return False


def interactive_menu():
    """Interaktives Menü"""
    db = DatabaseManager()

    if not db.connect():
        return

    while True:
        print("\n" + "=" * 50)
        print("  WAMMSEE DATABASE MANAGEMENT")
        print("=" * 50)
        print("  [1] User Management")
        print("  [2] Data Management")
        print("  [3] Lake Management")
        print("  [4] Wartung")
        print("  [0] Beenden")
        print("=" * 50)

        choice = input("\nAuswahl: ").strip()

        if choice == '0':
            db.disconnect()
            break

        elif choice == '1':
            _user_menu(db)

        elif choice == '2':
            _data_menu(db)

        elif choice == '3':
            _lake_menu(db)

        elif choice == '4':
            _maintenance_menu(db)


def _user_menu(db):
    """User Management Untermenü"""
    while True:
        print("\n── User Management ──")
        print("  [1] User auflisten")
        print("  [2] User anlegen")
        print("  [3] User löschen")
        print("  [4] Passwort ändern")
        print("  [5] Admin-Status togglen")
        print("  [0] Zurück")
        choice = input("\nAuswahl: ").strip()

        if choice == '0':
            break
        elif choice == '1':
            db.list_users()
        elif choice == '2':
            username = input("Benutzername: ").strip()
            password = getpass.getpass("Passwort: ")
            is_admin = input("Admin? [j/N]: ").lower() == 'j'
            db.create_user(username, password, is_admin)
        elif choice == '3':
            user_id = int(input("User-ID: "))
            db.delete_user(user_id)
        elif choice == '4':
            user_id = int(input("User-ID: "))
            password = getpass.getpass("Neues Passwort: ")
            db.change_password(user_id, password)
        elif choice == '5':
            user_id = int(input("User-ID: "))
            db.toggle_user_lock(user_id)


def _data_menu(db):
    """Data Management Untermenü"""
    while True:
        print("\n── Data Management ──")
        print("  [1] Alle Punkte eines Users löschen")
        print("  [2] Alle Punkte löschen")
        print("  [3] Export als CSV")
        print("  [4] Import von CSV")
        print("  [0] Zurück")
        choice = input("\nAuswahl: ").strip()

        if choice == '0':
            break
        elif choice == '1':
            user_id = int(input("User-ID: "))
            db.delete_user_points(user_id)
        elif choice == '2':
            db.delete_all_points()
        elif choice == '3':
            filepath = input("Zieldatei (Enter für auto): ").strip()
            db.export_csv(filepath or None)
        elif choice == '4':
            filepath = input("CSV-Datei: ").strip()
            db.import_csv(filepath)


def _lake_menu(db):
    """Lake Management Untermenü"""
    while True:
        print("\n── Lake Management ──")
        print("  [1] Seen auflisten")
        print("  [2] See anlegen")
        print("  [3] See löschen")
        print("  [0] Zurück")
        choice = input("\nAuswahl: ").strip()

        if choice == '0':
            break
        elif choice == '1':
            db.list_lakes()
        elif choice == '2':
            name = input("Seenname: ").strip()
            db.create_lake(name)
        elif choice == '3':
            lake_id = int(input("See-ID: "))
            db.delete_lake(lake_id)


def _maintenance_menu(db):
    """Wartung Untermenü"""
    while True:
        print("\n── Wartung ──")
        print("  [1] Connection test")
        print("  [2] Backup erstellen")
        print("  [3] Vacuum (DB-Optimierung)")
        print("  [0] Zurück")
        choice = input("\nAuswahl: ").strip()

        if choice == '0':
            break
        elif choice == '1':
            db.connection_test()
        elif choice == '2':
            filepath = input("Zieldatei (Enter für auto): ").strip()
            db.create_backup(filepath or None)
        elif choice == '3':
            db.vacuum()


def batch_mode(command):
    """Batch-Modus für Automation"""
    db = DatabaseManager()

    if not db.connect():
        sys.exit(1)

    commands = {
        'users': db.list_users,
        'lakes': db.list_lakes,
        'backup': lambda: db.create_backup(),
        'vacuum': db.vacuum,
        'test': db.connection_test,
    }

    if command not in commands:
        print(f"Unbekannter Befehl: {command}")
        print(f"Verfügbar: {', '.join(commands.keys())}")
        db.disconnect()
        sys.exit(1)

    commands[command]()
    db.disconnect()


def main():
    parser = argparse.ArgumentParser(
        description='Wammsee Lake Mapper - Datenbank Management',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Beispiele:
  python db_management.py                     # Interaktives Menü
  python db_management.py batch users          # User auflisten
  python db_management.py batch lakes         # Seen auflisten
  python db_management.py batch backup        # Backup erstellen
  python db_management.py batch vacuum        # DB optimieren
  python db_management.py batch test         # Verbindung testen

Umgebungsvariablen (optional):
  DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD
        """
    )

    parser.add_argument('batch', nargs='?', help='Batch-Befehl ausführen')
    parser.add_argument('--config', help='Config-Datei für DB-Verbindung (JSON)')

    args = parser.parse_args()

    if args.batch:
        batch_mode(args.batch)
    else:
        interactive_menu()


if __name__ == '__main__':
    main()