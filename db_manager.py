#!/usr/bin/env python3
"""
Wammsee Database Manager v1.0
PostgreSQL/PostGIS Database Management Tool for Lake Depth Data
"""

import argparse
import csv
import datetime
import json
import logging
import os
import subprocess
import sys
from pathlib import Path
from typing import Optional

import bcrypt
import colorama
import psycopg2
from colorama import Fore, Style

# Initialize colorama for cross-platform colored output
colorama.init(autoreset=True)

# =============================================================================
# CONFIGURATION
# =============================================================================

DEFAULT_CONFIG_PATH = Path(__file__).parent / "db_config.json"
LOG_FILE = Path(__file__).parent / "db_manager.log"


def load_config(config_path: Path = DEFAULT_CONFIG_PATH) -> dict:
    """Load database configuration from JSON file."""
    if not config_path.exists():
        logging.warning(f"Config file not found: {config_path}")
        return {}
    with open(config_path, "r") as f:
        return json.load(f)


# =============================================================================
# COLOR PRINTER
# =============================================================================

class Colors:
    """Color constants for CLI output."""
    HEADER = Fore.CYAN
    SUCCESS = Fore.GREEN
    ERROR = Fore.RED
    WARNING = Fore.YELLOW
    INFO = Fore.BLUE
    PROMPT = Fore.MAGENTA
    DIM = Fore.LIGHTBLACK_EX


def print_header(text: str, width: int = 50):
    """Print a header with box drawing characters."""
    print(f"\n{Colors.HEADER}{'═' * width}")
    print(f"║  {text}")
    print(f"{Colors.HEADER}{'═' * width}{Style.RESET_ALL}\n")


def print_success(text: str):
    print(f"{Colors.SUCCESS}✓ {text}{Style.RESET_ALL}")


def print_error(text: str):
    print(f"{Colors.ERROR}✗ {text}{Style.RESET_ALL}")


def print_warning(text: str):
    print(f"{Colors.WARNING}⚠ {text}{Style.RESET_ALL}")


def print_info(text: str):
    print(f"{Colors.INFO}ℹ {text}{Style.RESET_ALL}")


def print_dim(text: str):
    print(f"{Colors.DIM}{text}{Style.RESET_ALL}")


# =============================================================================
# INTERACTIVE INPUT
# =============================================================================

def ask_yes_no(question: str, default: str = "n") -> bool:
    """Ask a yes/no question and return boolean."""
    choices = "Y/n" if default == "y" else "y/N"
    while True:
        response = input(f"{Colors.PROMPT}{question} [{choices}]: {Style.RESET_ALL}").strip().lower()
        if not response:
            return default == "y"
        if response in ("y", "yes"):
            return True
        if response in ("n", "no"):
            return False
        print_warning("Please enter 'y' or 'n'")


def ask_input(question: str, default: Optional[str] = None, required: bool = True) -> str:
    """Ask for user input with optional default."""
    prompt = f"{Colors.PROMPT}{question}{Style.RESET_ALL}"
    if default:
        prompt += f" [{default}]"
    prompt += ": "

    while True:
        response = input(prompt).strip()
        if not response:
            if default is not None:
                return default
            if required:
                print_warning("This field is required")
                continue
        return response


def ask_password(question: str = "Password") -> str:
    """Ask for password input (hidden)."""
    import getpass
    while True:
        p1 = getpass.getpass(f"{Colors.PROMPT}{question}: {Style.RESET_ALL}")
        if len(p1) < 6:
            print_warning("Password must be at least 6 characters")
            continue
        p2 = getpass.getpass(f"{Colors.PROMPT}Confirm password: {Style.RESET_ALL}")
        if p1 == p2:
            return p1
        print_error("Passwords do not match")


def select_from_list(items: list, question: str = "Select option") -> Optional[int]:
    """Let user select from a numbered list. Returns index or None."""
    if not items:
        return None
    for i, item in enumerate(items, 1):
        print(f"  {i}. {item}")
    while True:
        try:
            choice = int(input(f"\n{Colors.PROMPT}{question}: {Style.RESET_ALL}"))
            if 1 <= choice <= len(items):
                return choice - 1
            print_warning(f"Please enter a number between 1 and {len(items)}")
        except ValueError:
            print_warning("Please enter a valid number")


# =============================================================================
# LOGGING SETUP
# =============================================================================

def setup_logging():
    """Configure logging to file and console."""
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s",
        handlers=[
            logging.FileHandler(LOG_FILE),
            logging.StreamHandler(sys.stdout),
        ],
    )
    return logging.getLogger(__name__)


# =============================================================================
# DATABASE CONNECTION
# =============================================================================

class DatabaseConnection:
    """Context manager for database connections."""

    def __init__(self, config: dict):
        self.config = config
        self.conn = None

    def __enter__(self):
        try:
            self.conn = psycopg2.connect(
                host=self.config.get("host", "localhost"),
                port=self.config.get("port", 5432),
                database=self.config.get("database", "lake_db"),
                user=self.config.get("user", "lakeuser"),
                password=self.config.get("password", ""),
            )
            self.conn.autocommit = False
            logging.info("Database connection established")
            return self.conn
        except psycopg2.Error as e:
            logging.error(f"Database connection failed: {e}")
            print_error(f"Connection failed: {e}")
            sys.exit(1)

    def __exit__(self, exc_type, exc_val, exc_tb):
        if self.conn:
            if exc_type:
                self.conn.rollback()
                logging.error("Transaction rolled back due to error")
            else:
                self.conn.commit()
            self.conn.close()
            logging.info("Database connection closed")


# =============================================================================
# DB MANAGER CLASS
# =============================================================================

class DatabaseManager:
    """Main database management class."""

    def __init__(self, config: dict):
        self.config = config
        self.logger = logging.getLogger(__name__)

    # -------------------------------------------------------------------------
    # User Management
    # -------------------------------------------------------------------------

    def list_users(self):
        """List all users with their details."""
        with DatabaseConnection(self.config) as conn:
            with conn.cursor() as cur:
                cur.execute("""
                    SELECT id, username, is_admin, created_at,
                           (SELECT COUNT(*) FROM lake_depths WHERE user_id = users.id) as point_count
                    FROM users
                    ORDER BY created_at DESC
                """)
                users = cur.fetchall()

        if not users:
            print_warning("No users found")
            return

        print_header("Users")
        print(f"{'ID':<4} {'Username':<20} {'Admin':<6} {'Points':<8} {'Created':<20}")
        print("-" * 65)
        for user in users:
            admin_status = "Yes" if user[2] else "No"
            created = user[3].strftime("%Y-%m-%d %H:%M") if user[3] else "N/A"
            print(f"{user[0]:<4} {user[1]:<20} {admin_status:<6} {user[4]:<8} {created}")

    def create_user(self, username: str, password: str, is_admin: bool = False) -> bool:
        """Create a new user with hashed password."""
        if not username or len(username) < 3:
            print_error("Username must be at least 3 characters")
            return False

        password_hash = bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()

        try:
            with DatabaseConnection(self.config) as conn:
                with conn.cursor() as cur:
                    cur.execute(
                        """
                        INSERT INTO users (username, password_hash, is_admin)
                        VALUES (%s, %s, %s)
                        """,
                        (username, password_hash, is_admin),
                    )
            print_success(f"User '{username}' created successfully")
            return True
        except psycopg2.Error as e:
            if "unique constraint" in str(e).lower():
                print_error(f"User '{username}' already exists")
            else:
                print_error(f"Failed to create user: {e}")
            return False

    def delete_user(self, username: str, cascade: bool = False) -> bool:
        """Delete a user, optionally with all their data."""
        with DatabaseConnection(self.config) as conn:
            with conn.cursor() as cur:
                # Get user ID
                cur.execute("SELECT id FROM users WHERE username = %s", (username,))
                user = cur.fetchone()

                if not user:
                    print_error(f"User '{username}' not found")
                    return False

                user_id = user[0]

                if cascade:
                    # Delete all depth measurements by this user
                    cur.execute("DELETE FROM lake_depths WHERE user_id = %s", (user_id,))
                    points_deleted = cur.rowcount

                # Delete user
                cur.execute("DELETE FROM users WHERE username = %s", (username,))

        msg = f"User '{username}' deleted"
        if cascade and points_deleted > 0:
            msg += f" along with {points_deleted} measurement points"
        print_success(msg)
        return True

    def change_password(self, username: str, new_password: str) -> bool:
        """Change user's password."""
        password_hash = bcrypt.hashpw(new_password.encode(), bcrypt.gensalt()).decode()

        try:
            with DatabaseConnection(self.config) as conn:
                with conn.cursor() as cur:
                    cur.execute(
                        "UPDATE users SET password_hash = %s WHERE username = %s",
                        (password_hash, username),
                    )
                    if cur.rowcount == 0:
                        print_error(f"User '{username}' not found")
                        return False
            print_success(f"Password for '{username}' changed successfully")
            return True
        except psycopg2.Error as e:
            print_error(f"Failed to change password: {e}")
            return False

    def lock_user(self, username: str, lock: bool = True) -> bool:
        """Lock or unlock a user by clearing their password (makes login impossible)."""
        # We use a special hash that bcrypt will never match
        locked_hash = "$2b$12$LOCKEDUSER000000000000000000000000000000000000000000000000000"

        try:
            with DatabaseConnection(self.config) as conn:
                with conn.cursor() as cur:
                    if lock:
                        cur.execute(
                            "UPDATE users SET password_hash = %s WHERE username = %s",
                            (locked_hash, username),
                        )
                        status = "locked"
                    else:
                        # For unlock, we'd need the original password - just show warning
                        print_warning("Unlock requires setting a new password")
                        return False

                    if cur.rowcount == 0:
                        print_error(f"User '{username}' not found")
                        return False
            print_success(f"User '{username}' {status}")
            return True
        except psycopg2.Error as e:
            print_error(f"Failed to {status} user: {e}")
            return False

    def reset_user_password(self, username: str) -> str:
        """Reset user password and return the new one."""
        import secrets
        import string

        new_password = "".join(
            secrets.choice(string.ascii_letters + string.digits) for _ in range(12)
        )

        if self.change_password(username, new_password):
            return new_password
        return ""

    # -------------------------------------------------------------------------
    # Data Management
    # -------------------------------------------------------------------------

    def delete_points_by_user(self, username: str) -> int:
        """Delete all depth measurements by a specific user."""
        with DatabaseConnection(self.config) as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "SELECT id FROM users WHERE username = %s", (username,)
                )
                user = cur.fetchone()
                if not user:
                    print_error(f"User '{username}' not found")
                    return 0

                cur.execute(
                    "DELETE FROM lake_depths WHERE user_id = %s", (user[0],)
                )
                deleted = cur.rowcount

        print_success(f"Deleted {deleted} points for user '{username}'")
        return deleted

    def delete_all_points(self, confirm_lake: Optional[str] = None) -> int:
        """Delete all depth measurements, optionally for a specific lake."""
        with DatabaseConnection(self.config) as conn:
            with conn.cursor() as cur:
                if confirm_lake:
                    cur.execute("SELECT id FROM lakes WHERE name = %s", (confirm_lake,))
                    lake = cur.fetchone()
                    if not lake:
                        print_error(f"Lake '{confirm_lake}' not found")
                        return 0
                    cur.execute("DELETE FROM lake_depths WHERE lake_id = %s", (lake[0],))
                else:
                    cur.execute("DELETE FROM lake_depths")
                deleted = cur.rowcount

        if confirm_lake:
            print_success(f"Deleted {deleted} points for lake '{confirm_lake}'")
        else:
            print_success(f"Deleted all {deleted} measurement points")
        return deleted

    def export_user_data(self, username: str, output_file: str) -> int:
        """Export all data for a user to CSV file."""
        with DatabaseConnection(self.config) as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT id FROM users WHERE username = %s", (username,))
                user = cur.fetchone()
                if not user:
                    print_error(f"User '{username}' not found")
                    return 0

                cur.execute("""
                    SELECT
                        ld.id,
                        l.name as lake_name,
                        ld.depth_m,
                        ST_X(ld.location::geometry) as longitude,
                        ST_Y(ld.location::geometry) as latitude,
                        ld.accuracy_m,
                        ld.note,
                        ld.measured_at,
                        ld.synced
                    FROM lake_depths ld
                    JOIN lakes l ON ld.lake_id = l.id
                    WHERE ld.user_id = %s
                    ORDER BY ld.measured_at
                """, (user[0],))

                rows = cur.fetchall()

        if not rows:
            print_warning(f"No data found for user '{username}'")
            return 0

        with open(output_file, "w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            writer.writerow([
                "id", "lake_name", "depth_m", "longitude", "latitude",
                "accuracy_m", "note", "measured_at", "synced"
            ])
            for row in rows:
                measured = row[7].strftime("%Y-%m-%d %H:%M:%S") if row[7] else ""
                writer.writerow([
                    row[0], row[1], row[2], row[3], row[4],
                    row[5] or "", row[6] or "", measured, row[8]
                ])

        print_success(f"Exported {len(rows)} points to '{output_file}'")
        return len(rows)

    def export_all_data(self, output_file: str) -> int:
        """Export all data to CSV file."""
        with DatabaseConnection(self.config) as conn:
            with conn.cursor() as cur:
                cur.execute("""
                    SELECT
                        ld.id,
                        l.name as lake_name,
                        ld.depth_m,
                        ST_X(ld.location::geometry) as longitude,
                        ST_Y(ld.location::geometry) as latitude,
                        ld.accuracy_m,
                        ld.note,
                        ld.measured_at,
                        u.username,
                        ld.synced
                    FROM lake_depths ld
                    JOIN lakes l ON ld.lake_id = l.id
                    LEFT JOIN users u ON ld.user_id = u.id
                    ORDER BY ld.measured_at
                """)

                rows = cur.fetchall()

        if not rows:
            print_warning("No data to export")
            return 0

        with open(output_file, "w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            writer.writerow([
                "id", "lake_name", "depth_m", "longitude", "latitude",
                "accuracy_m", "note", "measured_at", "username", "synced"
            ])
            for row in rows:
                measured = row[7].strftime("%Y-%m-%d %H:%M:%S") if row[7] else ""
                writer.writerow([
                    row[0], row[1], row[2], row[3], row[4],
                    row[5] or "", row[6] or "", measured, row[8] or "unknown", row[9]
                ])

        print_success(f"Exported {len(rows)} points to '{output_file}'")
        return len(rows)

    def import_points(self, input_file: str, lake_name: str, user_id: int = 1) -> int:
        """Import depth measurements from CSV file."""
        if not Path(input_file).exists():
            print_error(f"File not found: {input_file}")
            return 0

        with DatabaseConnection(self.config) as conn:
            with conn.cursor() as cur:
                # Find lake
                cur.execute("SELECT id FROM lakes WHERE name = %s", (lake_name,))
                lake = cur.fetchone()
                if not lake:
                    print_error(f"Lake '{lake_name}' not found")
                    return 0
                lake_id = lake[0]

                # Read CSV
                imported = 0
                errors = 0

                with open(input_file, "r", encoding="utf-8") as f:
                    reader = csv.DictReader(f)
                    for row_num, row in enumerate(reader, 2):  # Start at 2 (header is 1)
                        try:
                            longitude = float(row.get("longitude", row.get("lon", 0)))
                            latitude = float(row.get("latitude", row.get("lat", 0)))
                            depth = float(row.get("depth_m", row.get("depth", 0)))

                            if depth < 0:
                                print_warning(f"Row {row_num}: Negative depth, skipping")
                                continue

                            accuracy = float(row.get("accuracy_m", 5.0)) if row.get("accuracy_m") else 5.0
                            note = row.get("note", "")
                            measured_str = row.get("measured_at")

                            if measured_str:
                                measured_at = datetime.datetime.fromisoformat(measured_str)
                            else:
                                measured_at = datetime.datetime.now()

                            cur.execute("""
                                INSERT INTO lake_depths
                                (lake_id, depth_m, location, accuracy_m, note, measured_at, user_id, synced)
                                VALUES (%s, %s, ST_MakePoint(%s, %s)::geography, %s, %s, %s, %s, TRUE)
                            """, (lake_id, depth, longitude, latitude, accuracy, note, measured_at, user_id))
                            imported += 1

                        except (ValueError, KeyError) as e:
                            print_warning(f"Row {row_num}: Invalid data - {e}")
                            errors += 1

        print_success(f"Imported {imported} points" + (f" ({errors} errors)" if errors else ""))
        return imported

    def reset_all_data(self) -> bool:
        """Reset all data (truncate tables)."""
        if not ask_yes_no("Are you sure you want to delete ALL measurement data?"):
            print_info("Operation cancelled")
            return False

        if not ask_yes_no("This will delete ALL depth measurements. Type 'yes' to confirm"):
            print_info("Operation cancelled")
            return False

        with DatabaseConnection(self.config) as conn:
            with conn.cursor() as cur:
                cur.execute("TRUNCATE TABLE lake_depths RESTART IDENTITY CASCADE")

        print_success("All measurement data has been reset")
        return True

    # -------------------------------------------------------------------------
    # Lake Management
    # -------------------------------------------------------------------------

    def list_lakes(self):
        """List all lakes with statistics."""
        with DatabaseConnection(self.config) as conn:
            with conn.cursor() as cur:
                cur.execute("""
                    SELECT l.id, l.name,
                           ST_Area(l.polygon) / 10000 as area_ha,
                           (SELECT COUNT(*) FROM lake_depths WHERE lake_id = l.id) as point_count,
                           (SELECT MIN(depth_m) FROM lake_depths WHERE lake_id = l.id) as min_depth,
                           (SELECT MAX(depth_m) FROM lake_depths WHERE lake_id = l.id) as max_depth,
                           l.created_at
                    FROM lakes l
                    ORDER BY l.name
                """)
                lakes = cur.fetchall()

        if not lakes:
            print_warning("No lakes found")
            return

        print_header("Lakes")
        print(f"{'ID':<4} {'Name':<20} {'Area (ha)':<12} {'Points':<8} {'Min':<8} {'Max':<8}")
        print("-" * 70)
        for lake in lakes:
            area = f"{lake[2]:.2f}" if lake[2] else "N/A"
            min_d = f"{lake[4]:.1f}m" if lake[4] is not None else "-"
            max_d = f"{lake[5]:.1f}m" if lake[5] is not None else "-"
            print(f"{lake[0]:<4} {lake[1]:<20} {area:<12} {lake[3]:<8} {min_d:<8} {max_d:<8}")

    def create_lake(self, name: str, wkt_polygon: str = None) -> bool:
        """Create a new lake."""
        if not name:
            print_error("Lake name is required")
            return False

        try:
            with DatabaseConnection(self.config) as conn:
                with conn.cursor() as cur:
                    if wkt_polygon:
                        cur.execute(
                            """
                            INSERT INTO lakes (name, polygon)
                            VALUES (%s, ST_GeomFromText(%s, 4326))
                            """,
                            (name, wkt_polygon),
                        )
                    else:
                        cur.execute(
                            "INSERT INTO lakes (name) VALUES (%s)",
                            (name,),
                        )
            print_success(f"Lake '{name}' created successfully")
            return True
        except psycopg2.Error as e:
            if "unique constraint" in str(e).lower():
                print_error(f"Lake '{name}' already exists")
            else:
                print_error(f"Failed to create lake: {e}")
            return False

    def delete_lake(self, name: str, cascade: bool = False) -> bool:
        """Delete a lake and optionally its data."""
        with DatabaseConnection(self.config) as conn:
            with conn.cursor() as cur:
                # Check if lake exists
                cur.execute("SELECT id FROM lakes WHERE name = %s", (name,))
                lake = cur.fetchone()

                if not lake:
                    print_error(f"Lake '{name}' not found")
                    return False

                if cascade:
                    cur.execute("DELETE FROM lake_depths WHERE lake_id = %s", (lake[0],))

                cur.execute("DELETE FROM lakes WHERE name = %s", (name,))

        print_success(f"Lake '{name}' deleted" + (" and all its data" if cascade else ""))
        return True

    def lake_statistics(self, lake_name: str = None):
        """Show statistics for a lake or all lakes."""
        with DatabaseConnection(self.config) as conn:
            with conn.cursor() as cur:

                if lake_name:
                    # Single lake
                    cur.execute("""
                        SELECT
                            l.name,
                            COUNT(ld.id) as total_points,
                            AVG(ld.depth_m) as avg_depth,
                            MIN(ld.depth_m) as min_depth,
                            MAX(ld.depth_m) as max_depth,
                            STDDEV(ld.depth_m) as stddev_depth,
                            COUNT(DISTINCT ld.user_id) as unique_users,
                            ST_Area(l.polygon) / 10000 as area_ha
                        FROM lakes l
                        LEFT JOIN lake_depths ld ON l.id = ld.lake_id
                        WHERE l.name = %s
                        GROUP BY l.id, l.name
                    """, (lake_name,))
                    result = cur.fetchone()

                    if not result:
                        print_error(f"Lake '{lake_name}' not found")
                        return

                    print_header(f"Statistics for '{result[0]}'")
                    print(f"{'Total Points':<20} {result[1]}")
                    print(f"{'Average Depth':<20} {result[2]:.2f}m" if result[2] else f"{'Average Depth':<20} N/A")
                    print(f"{'Min Depth':<20} {result[3]:.2f}m" if result[3] else f"{'Min Depth':<20} N/A")
                    print(f"{'Max Depth':<20} {result[4]:.2f}m" if result[4] else f"{'Max Depth':<20} N/A")
                    print(f"{'Std Deviation':<20} {result[5]:.2f}m" if result[5] else f"{'Std Deviation':<20} N/A")
                    print(f"{'Unique Users':<20} {result[6]}")
                    print(f"{'Surface Area':<20} {result[7]:.2f} ha" if result[7] else f"{'Surface Area':<20} N/A")

                else:
                    # All lakes
                    cur.execute("""
                        SELECT
                            l.name,
                            COUNT(ld.id) as total_points,
                            AVG(ld.depth_m) as avg_depth
                        FROM lakes l
                        LEFT JOIN lake_depths ld ON l.id = ld.lake_id
                        GROUP BY l.id, l.name
                        ORDER BY total_points DESC
                    """)
                    results = cur.fetchall()

                    print_header("Lake Statistics Overview")
                    print(f"{'Lake':<20} {'Points':<10} {'Avg Depth':<15}")
                    print("-" * 50)
                    for row in results:
                        avg = f"{row[2]:.2f}m" if row[2] else "N/A"
                        print(f"{row[0]:<20} {row[1]:<10} {avg:<15}")

    # -------------------------------------------------------------------------
    # Statistics
    # -------------------------------------------------------------------------

    def user_statistics(self):
        """Show statistics for all users."""
        with DatabaseConnection(self.config) as conn:
            with conn.cursor() as cur:
                cur.execute("""
                    SELECT
                        u.username,
                        u.is_admin,
                        COUNT(ld.id) as points,
                        MIN(ld.measured_at) as first_measurement,
                        MAX(ld.measured_at) as last_measurement
                    FROM users u
                    LEFT JOIN lake_depths ld ON u.id = ld.user_id
                    GROUP BY u.id, u.username, u.is_admin
                    ORDER BY points DESC
                """)
                results = cur.fetchall()

        print_header("User Statistics")
        print(f"{'Username':<20} {'Admin':<6} {'Points':<8} {'First':<12} {'Last':<12}")
        print("-" * 65)
        for row in results:
            first = row[3].strftime("%Y-%m-%d") if row[3] else "Never"
            last = row[4].strftime("%Y-%m-%d") if row[4] else "Never"
            print(f"{row[0]:<20} {'Yes' if row[1] else 'No':<6} {row[2]:<8} {first:<12} {last:<12}")

    def data_overview(self):
        """Show overview of all data."""
        with DatabaseConnection(self.config) as conn:
            with conn.cursor() as cur:
                cur.execute("""
                    SELECT
                        (SELECT COUNT(*) FROM lakes) as lake_count,
                        (SELECT COUNT(*) FROM users) as user_count,
                        (SELECT COUNT(*) FROM lake_depths) as point_count,
                        (SELECT COUNT(*) FROM lake_depths WHERE synced = FALSE) as unsynced_count,
                        (SELECT AVG(depth_m) FROM lake_depths) as avg_depth,
                        (SELECT MAX(depth_m) FROM lake_depths) as max_depth
                """)
                stats = cur.fetchone()

        print_header("Data Overview")
        print(f"{'Lakes':<25} {stats[0]}")
        print(f"{'Users':<25} {stats[1]}")
        print(f"{'Total Measurements':<25} {stats[2]}")
        print(f"{'Unsynced Measurements':<25} {stats[3]}")
        print(f"{'Average Depth':<25} {stats[4]:.2f}m" if stats[4] else f"{'Average Depth':<25} N/A")
        print(f"{'Maximum Depth':<25} {stats[5]:.2f}m" if stats[5] else f"{'Maximum Depth':<25} N/A")

    def database_size(self):
        """Show database size information."""
        with DatabaseConnection(self.config) as conn:
            with conn.cursor() as cur:
                cur.execute("""
                    SELECT
                        pg_size_pretty(pg_database_size(current_database())) as db_size,
                        pg_size_pretty(pg_total_relation_size('lake_depths')) as points_size,
                        pg_size_pretty(pg_total_relation_size('lakes')) as lakes_size,
                        pg_size_pretty(pg_total_relation_size('users')) as users_size
                """)
                sizes = cur.fetchone()

        print_header("Database Size")
        print(f"{'Total Database':<25} {sizes[0]}")
        print(f"{'Depth Measurements':<25} {sizes[1]}")
        print(f"{'Lakes Table':<25} {sizes[2]}")
        print(f"{'Users Table':<25} {sizes[3]}")

    # -------------------------------------------------------------------------
    # Maintenance
    # -------------------------------------------------------------------------

    def create_backup(self, backup_dir: str = None) -> Optional[str]:
        """Create a database backup using pg_dump."""
        if backup_dir is None:
            backup_dir = self.config.get("backup_dir", "./backups")

        backup_path = Path(backup_dir)
        backup_path.mkdir(parents=True, exist_ok=True)

        timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_file = backup_path / f"lake_db_backup_{timestamp}.sql"

        db_name = self.config.get("database", "lake_db")
        db_user = self.config.get("user", "lakeuser")
        db_host = self.config.get("host", "localhost")
        db_port = self.config.get("port", 5432)

        try:
            result = subprocess.run(
                [
                    "pg_dump",
                    "-h", db_host,
                    "-p", str(db_port),
                    "-U", db_user,
                    "-Fc",  # Custom format for compression
                    "-f", str(backup_file),
                    db_name,
                ],
                env={**os.environ, "PGPASSWORD": self.config.get("password", "")},
                capture_output=True,
                text=True,
            )

            if result.returncode == 0:
                size = backup_file.stat().st_size
                size_str = f"{size / (1024*1024):.2f} MB" if size > 1024*1024 else f"{size / 1024:.2f} KB"
                print_success(f"Backup created: {backup_file} ({size_str})")
                return str(backup_file)
            else:
                print_error(f"Backup failed: {result.stderr}")
                return None

        except FileNotFoundError:
            print_error("pg_dump not found. Please install PostgreSQL client tools.")
            return None

    def restore_backup(self, backup_file: str) -> bool:
        """Restore a database backup using pg_restore."""
        if not Path(backup_file).exists():
            print_error(f"Backup file not found: {backup_file}")
            return False

        if not ask_yes_no("This will replace all current data. Continue?"):
            print_info("Restore cancelled")
            return False

        db_name = self.config.get("database", "lake_db")
        db_user = self.config.get("user", "lakeuser")
        db_host = self.config.get("host", "localhost")
        db_port = self.config.get("port", 5432)

        try:
            result = subprocess.run(
                [
                    "pg_restore",
                    "-h", db_host,
                    "-p", str(db_port),
                    "-U", db_user,
                    "-d", db_name,
                    "--clean",  # Drop existing objects
                    "--create",  # Also create the database
                    str(backup_file),
                ],
                env={**os.environ, "PGPASSWORD": self.config.get("password", "")},
                capture_output=True,
                text=True,
            )

            if result.returncode == 0:
                print_success(f"Backup restored from: {backup_file}")
                return True
            else:
                print_error(f"Restore failed: {result.stderr}")
                return False

        except FileNotFoundError:
            print_error("pg_restore not found. Please install PostgreSQL client tools.")
            return False

    def vacuum_database(self) -> bool:
        """Run VACUUM FULL on the database."""
        if not ask_yes_no("VACUUM FULL will lock the database. Continue?"):
            print_info("VACUUM cancelled")
            return False

        with DatabaseConnection(self.config) as conn:
            with conn.cursor() as cur:
                cur.execute("VACUUM FULL ANALYZE")

        print_success("Database VACUUM FULL completed")
        return True

    def connection_test(self) -> bool:
        """Test database connection."""
        try:
            with DatabaseConnection(self.config) as conn:
                with conn.cursor() as cur:
                    cur.execute("SELECT version()")
                    version = cur.fetchone()[0]
                    
                    # PostGIS prüfen (optional, da evtl. nicht installiert)
                    postgis = "nicht installiert"
                    try:
                        cur.execute("SELECT postgis_version()")
                        postgis = cur.fetchone()[0]
                    except psycopg2.Error:
                        pass

            print_header("Connection Test - SUCCESS")
            print_info(f"PostgreSQL: {version}")
            print_info(f"PostGIS: {postgis}")
            return True

        except Exception as e:
            print_header("Connection Test - FAILED")
            print_error(str(e))
            return False


# =============================================================================
# CLI INTERFACE
# =============================================================================

def print_menu():
    """Print the main menu."""
    print(f"""
{Colors.HEADER}╔════════════════════════════════════════════╗
║  Wammsee Database Manager v1.0             ║
╠════════════════════════════════════════════╣{Style.RESET_ALL}
{Colors.INFO}  1. User Management{Style.RESET_ALL}
{Colors.DIM}       ├─ 1.1 Create User{Style.RESET_ALL}
{Colors.DIM}       ├─ 1.2 Delete User (mit/ohne Daten){Style.RESET_ALL}
{Colors.DIM}       ├─ 1.3 Change Password{Style.RESET_ALL}
{Colors.DIM}       ├─ 1.4 List Users{Style.RESET_ALL}
{Colors.DIM}       └─ 1.5 Lock/Unlock User{Style.RESET_ALL}
{Colors.INFO}  2. Data Management{Style.RESET_ALL}
{Colors.DIM}       ├─ 2.1 Delete Points by User{Style.RESET_ALL}
{Colors.DIM}       ├─ 2.2 Delete All Points{Style.RESET_ALL}
{Colors.DIM}       ├─ 2.3 Export User Data (CSV){Style.RESET_ALL}
{Colors.DIM}       ├─ 2.4 Import Points (CSV){Style.RESET_ALL}
{Colors.DIM}       └─ 2.5 Reset All Data{Style.RESET_ALL}
{Colors.INFO}  3. Lake Management{Style.RESET_ALL}
{Colors.DIM}       ├─ 3.1 List Lakes{Style.RESET_ALL}
{Colors.DIM}       ├─ 3.2 Create Lake{Style.RESET_ALL}
{Colors.DIM}       ├─ 3.3 Delete Lake{Style.RESET_ALL}
{Colors.DIM}       └─ 3.4 Lake Statistics{Style.RESET_ALL}
{Colors.INFO}  4. Statistics{Style.RESET_ALL}
{Colors.DIM}       ├─ 4.1 User Statistics{Style.RESET_ALL}
{Colors.DIM}       ├─ 4.2 Data Overview{Style.RESET_ALL}
{Colors.DIM}       └─ 4.3 Database Size{Style.RESET_ALL}
{Colors.INFO}  5. Maintenance{Style.RESET_ALL}
{Colors.DIM}       ├─ 5.1 Create Backup{Style.RESET_ALL}
{Colors.DIM}       ├─ 5.2 Restore Backup{Style.RESET_ALL}
{Colors.DIM}       ├─ 5.3 Vacuum Database{Style.RESET_ALL}
{Colors.DIM}       └─ 5.4 Connection Test{Style.RESET_ALL}
{Colors.ERROR}  0. Exit{Style.RESET_ALL}
╚════════════════════════════════════════════╝
""")


def handle_user_menu(db: DatabaseManager):
    """Handle user management submenu."""
    while True:
        print(f"\n{Colors.INFO}--- User Management ---{Style.RESET_ALL}")
        print("  1. Create User")
        print("  2. Delete User")
        print("  3. Change Password")
        print("  4. List Users")
        print("  5. Lock/Unlock User")
        print("  0. Back")

        choice = input(f"\n{Colors.PROMPT}Select: {Style.RESET_ALL}").strip()

        if choice == "1":
            username = ask_input("Username", required=True)
            password = ask_password()
            is_admin = ask_yes_no("Admin user?")
            db.create_user(username, password, is_admin)

        elif choice == "2":
            username = ask_input("Username to delete", required=True)
            cascade = ask_yes_no("Delete all user's measurement data?")
            db.delete_user(username, cascade)

        elif choice == "3":
            username = ask_input("Username", required=True)
            new_password = ask_password("New Password")
            db.change_password(username, new_password)

        elif choice == "4":
            db.list_users()

        elif choice == "5":
            username = ask_input("Username", required=True)
            lock = ask_yes_no("Lock user? (No = unlock)")
            db.lock_user(username, lock)

        elif choice == "0":
            break


def handle_data_menu(db: DatabaseManager):
    """Handle data management submenu."""
    while True:
        print(f"\n{Colors.INFO}--- Data Management ---{Style.RESET_ALL}")
        print("  1. Delete Points by User")
        print("  2. Delete All Points")
        print("  3. Export User Data (CSV)")
        print("  4. Export All Data (CSV)")
        print("  5. Import Points (CSV)")
        print("  6. Reset All Data")
        print("  0. Back")

        choice = input(f"\n{Colors.PROMPT}Select: {Style.RESET_ALL}").strip()

        if choice == "1":
            username = ask_input("Username", required=True)
            db.delete_points_by_user(username)

        elif choice == "2":
            db.delete_all_points()

        elif choice == "3":
            username = ask_input("Username", required=True)
            filename = ask_input("Output filename", default="export.csv")
            db.export_user_data(username, filename)

        elif choice == "4":
            filename = ask_input("Output filename", default="export_all.csv")
            db.export_all_data(filename)

        elif choice == "5":
            filename = ask_input("CSV file to import", required=True)
            lake_name = ask_input("Target lake name", required=True)
            db.import_points(filename, lake_name)

        elif choice == "6":
            db.reset_all_data()

        elif choice == "0":
            break


def handle_lake_menu(db: DatabaseManager):
    """Handle lake management submenu."""
    while True:
        print(f"\n{Colors.INFO}--- Lake Management ---{Style.RESET_ALL}")
        print("  1. List Lakes")
        print("  2. Create Lake")
        print("  3. Delete Lake")
        print("  4. Lake Statistics")
        print("  0. Back")

        choice = input(f"\n{Colors.PROMPT}Select: {Style.RESET_ALL}").strip()

        if choice == "1":
            db.list_lakes()

        elif choice == "2":
            name = ask_input("Lake name", required=True)
            wkt = ask_input("WKT Polygon (optional)")
            db.create_lake(name, wkt if wkt else None)

        elif choice == "3":
            name = ask_input("Lake name to delete", required=True)
            cascade = ask_yes_no("Delete all measurement data for this lake?")
            db.delete_lake(name, cascade)

        elif choice == "4":
            lake_name = ask_input("Lake name (leave empty for all)", required=False)
            db.lake_statistics(lake_name if lake_name else None)

        elif choice == "0":
            break


def handle_stats_menu(db: DatabaseManager):
    """Handle statistics submenu."""
    while True:
        print(f"\n{Colors.INFO}--- Statistics ---{Style.RESET_ALL}")
        print("  1. User Statistics")
        print("  2. Data Overview")
        print("  3. Database Size")
        print("  0. Back")

        choice = input(f"\n{Colors.PROMPT}Select: {Style.RESET_ALL}").strip()

        if choice == "1":
            db.user_statistics()

        elif choice == "2":
            db.data_overview()

        elif choice == "3":
            db.database_size()

        elif choice == "0":
            break


def handle_maint_menu(db: DatabaseManager, config: dict):
    """Handle maintenance submenu."""
    backup_dir = config.get("backup_dir", "./backups")

    while True:
        print(f"\n{Colors.INFO}--- Maintenance ---{Style.RESET_ALL}")
        print("  1. Create Backup")
        print("  2. Restore Backup")
        print("  3. Vacuum Database")
        print("  4. Connection Test")
        print("  0. Back")

        choice = input(f"\n{Colors.PROMPT}Select: {Style.RESET_ALL}").strip()

        if choice == "1":
            db.create_backup(backup_dir)

        elif choice == "2":
            # List available backups
            backup_path = Path(backup_dir)
            if backup_path.exists():
                backups = sorted(backup_path.glob("lake_db_backup_*.sql"))
                if backups:
                    print(f"\n{Colors.INFO}Available backups:{Style.RESET_ALL}")
                    for i, b in enumerate(backups, 1):
                        size = b.stat().st_size
                        size_str = f"{size / 1024:.1f} KB"
                        print(f"  {i}. {b.name} ({size_str})")
                    idx = select_from_list([b.name for b in backups], "Select backup")
                    if idx is not None:
                        db.restore_backup(str(backups[idx]))
                else:
                    print_warning("No backups found")
            else:
                print_warning(f"Backup directory not found: {backup_dir}")

        elif choice == "3":
            db.vacuum_database()

        elif choice == "4":
            db.connection_test()

        elif choice == "0":
            break


def interactive_mode(db: DatabaseManager, config: dict):
    """Run interactive CLI mode."""
    while True:
        print_menu()
        choice = input(f"{Colors.PROMPT}Select option: {Style.RESET_ALL}").strip()

        if choice == "0":
            print_success("Goodbye!")
            break

        elif choice == "1":
            handle_user_menu(db)

        elif choice == "2":
            handle_data_menu(db)

        elif choice == "3":
            handle_lake_menu(db)

        elif choice == "4":
            handle_stats_menu(db)

        elif choice == "5":
            handle_maint_menu(db, config)

        else:
            print_warning("Invalid option")


# =============================================================================
# BATCH MODE
# =============================================================================

def batch_mode(args, config):
    """Run batch commands from command line arguments."""
    db = DatabaseManager(config)

    if args.user_action:
        action = args.user_action.lower()

        if action == "create":
            if not args.username or not args.password:
                print_error("--user and --password required for create")
                return 1
            db.create_user(args.username, args.password, args.admin)
            return 0

        elif action == "delete":
            if not args.username:
                print_error("--user required for delete")
                return 1
            db.delete_user(args.username, args.cascade)
            return 0

        elif action == "password":
            if not args.username or not args.password:
                print_error("--user and --password required for password change")
                return 1
            db.change_password(args.username, args.password)
            return 0

        elif action == "list":
            db.list_users()
            return 0

        elif action == "reset-password":
            if not args.username:
                print_error("--user required for reset-password")
                return 1
            new_pw = db.reset_user_password(args.username)
            if new_pw:
                print_success(f"New password for '{args.username}': {new_pw}")
                return 0
            return 1

    if args.backup:
        result = db.create_backup()
        return 0 if result else 1

    if args.restore:
        result = db.restore_backup(args.restore)
        return 0 if result else 1

    if args.export:
        if args.username:
            db.export_user_data(args.username, args.export)
        else:
            db.export_all_data(args.export)
        return 0

    if args.import_file:
        if not args.lake:
            print_error("--lake required for import")
            return 1
        db.import_points(args.import_file, args.lake)
        return 0

    if args.vacuum:
        db.vacuum_database()
        return 0

    if args.test:
        db.connection_test()
        return 0

    if args.stats:
        db.data_overview()
        return 0

    return 0


# =============================================================================
# MAIN
# =============================================================================

def main():
    parser = argparse.ArgumentParser(
        description="Wammsee Database Manager",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )

    # Configuration
    parser.add_argument(
        "--config", "-c",
        type=Path,
        default=DEFAULT_CONFIG_PATH,
        help="Path to config file (default: db_config.json)",
    )

    # Batch mode arguments
    batch_group = parser.add_argument_group("Batch Commands")
    batch_group.add_argument("--user", help="Username for user operations")
    batch_group.add_argument("--password", help="Password for user operations")
    batch_group.add_argument("--admin", action="store_true", help="Set user as admin")
    batch_group.add_argument("--cascade", action="store_true", help="Cascade delete data")

    user_actions = batch_group.add_mutually_exclusive_group()
    user_actions.add_argument(
        "--user-action",
        choices=["create", "delete", "password", "list", "reset-password"],
        help="User management action",
    )

    batch_group.add_argument("--backup", action="store_true", help="Create database backup")
    batch_group.add_argument("--restore", metavar="FILE", help="Restore from backup file")
    batch_group.add_argument("--export", metavar="FILE", help="Export data to CSV file")
    batch_group.add_argument("--import", dest="import_file", metavar="FILE", help="Import from CSV")
    batch_group.add_argument("--lake", help="Lake name for import/export operations")
    batch_group.add_argument("--vacuum", action="store_true", help="Run VACUUM on database")
    batch_group.add_argument("--test", action="store_true", help="Test database connection")
    batch_group.add_argument("--stats", action="store_true", help="Show database statistics")

    args = parser.parse_args()

    # Setup logging
    logger = setup_logging()
    logger.info("Database Manager started")

    # Load configuration
    config = load_config(args.config)

    if not config:
        print_warning(f"No config file found at {args.config}")
        print_info("Using default configuration or environment variables")

    # Create database manager
    db = DatabaseManager(config)

    # Determine mode
    has_batch_args = any([
        args.user_action, args.backup, args.restore,
        args.export, args.import_file, args.vacuum,
        args.test, args.stats,
    ])

    if has_batch_args:
        # Batch mode
        return batch_mode(args, config)
    else:
        # Interactive mode
        try:
            interactive_mode(db, config)
            return 0
        except KeyboardInterrupt:
            print("\n\nInterrupted by user")
            return 130


if __name__ == "__main__":
    sys.exit(main())