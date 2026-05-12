#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
User Management für Wammsee - Interaktiv
"""

import sys
import getpass
import os
import bcrypt

DB_CONFIG = {
    'host': os.environ.get('DB_HOST', 'localhost'),
    'port': int(os.environ.get('DB_PORT', '5432')),
    'database': os.environ.get('DB_NAME', 'lakemap'),
    'user': os.environ.get('DB_USER', 'lakeuser'),
    'password': os.environ.get('DB_PASSWORD', 'lake123'),
}

def menu():
    print("\n=== User Management ===")
    print("  1) User erstellen")
    print("  2) User loeschen")
    print("  3) Passwort aendern")
    print("  4) User-Liste")
    print("  5) Beenden")
    return input("wahl: ").strip()


def get_db():
    import psycopg2
    return psycopg2.connect(**DB_CONFIG)


def hash_password(password):
    return bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()


def create():
    username = input("Username: ").strip()
    if not username:
        print("Abbruch")
        return
    
    password = getpass.getpass("Passwort: ")
    if not password:
        print("Abbruch")
        return
    
    pwd_hash = hash_password(password)
    conn = get_db()
    cur = conn.cursor()
    try:
        cur.execute(
            "INSERT INTO users (username, password_hash, is_admin) VALUES (%s, %s, FALSE) ON CONFLICT (username) DO NOTHING",
            (username, pwd_hash)
        )
        conn.commit()
        print(f"OK: {username} erstellt")
    finally:
        cur.close()
        conn.close()


def delete():
    username = input("Username: ").strip()
    if not username:
        print("Abbruch")
        return
    
    conn = get_db()
    cur = conn.cursor()
    try:
        cur.execute("DELETE FROM users WHERE username = %s", (username,))
        conn.commit()
        print(f"OK: {username} geloescht")
    finally:
        cur.close()
        conn.close()


def passwd():
    username = input("Username: ").strip()
    if not username:
        print("Abbruch")
        return
    
    password = getpass.getpass("Neues Passwort: ")
    if not password:
        print("Abbruch")
        return
    
    pwd_hash = hash_password(password)
    conn = get_db()
    cur = conn.cursor()
    try:
        cur.execute(
            "UPDATE users SET password_hash = %s WHERE username = %s",
            (pwd_hash, username)
        )
        conn.commit()
        print(f"OK: Passwort fuer {username} geaendert")
    finally:
        cur.close()
        conn.close()


def list_users():
    conn = get_db()
    cur = conn.cursor()
    try:
        cur.execute("SELECT username, is_admin FROM users ORDER BY id")
        print("\n=== User ===")
        for row in cur.fetchall():
            admin = " (Admin)" if row[1] else ""
            print(f"  {row[0]}{admin}")
    finally:
        cur.close()
        conn.close()


def main():
    while True:
        wahl = menu()
        
        if wahl == '1':
            create()
        elif wahl == '2':
            delete()
        elif wahl == '3':
            passwd()
        elif wahl == '4':
            list_users()
        elif wahl == '5' or wahl == 'q':
            print("Bye!")
            break
        else:
            print("Unbekannt")


if __name__ == '__main__':
    main()
