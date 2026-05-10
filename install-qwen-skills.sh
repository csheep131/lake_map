#!/usr/bin/env bash
set -euo pipefail

# Installiert die Qwen-Style Skills ins Kimi User-Skills-Verzeichnis
# Quelle: https://github.com/QwenLM/qwen-code (angepasst für Kimi CLI)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="${HOME}/.config/agents/skills"
SOURCE_DIR="${SCRIPT_DIR}/.agents/skills"

echo "=== Qwen-Style Skills Installer für Kimi CLI ==="
echo ""

# Verzeichnis erstellen
mkdir -p "${SKILLS_DIR}"
echo "Zielverzeichnis: ${SKILLS_DIR}"

# Skills kopieren
for skill in qwen-subagent-delegation qwen-hierarchical-context qwen-tool-permissions; do
    SRC="${SOURCE_DIR}/${skill}"
    DST="${SKILLS_DIR}/${skill}"
    
    if [ -d "${SRC}" ]; then
        if [ -d "${DST}" ]; then
            echo "→ Aktualisiere: ${skill}"
            rm -rf "${DST}"
        else
            echo "→ Installiere: ${skill}"
        fi
        cp -r "${SRC}" "${DST}"
        echo "  ✓ ${skill} installiert"
    else
        echo "  ✗ ${skill} nicht gefunden in ${SOURCE_DIR}"
        exit 1
    fi
done

echo ""
echo "=== Installation abgeschlossen ==="
echo ""
echo "Installierte Skills:"
ls -1 "${SKILLS_DIR}"
echo ""
echo "Nutzung:"
echo "  kimi --skills-dir ${SKILLS_DIR}"
echo ""
echo "Oder direkt im Projekt (bereits aktiv):"
echo "  .agents/skills/ ist projektlokal verfügbar"
echo ""
echo "Quick-Start:"
echo "  1. CONTEXT.md im Projektroot erstellen (hierarchischer Kontext)"
echo "  2. Subagents über Agent() Tool mit spezialisierten Prompts spawnen"
echo "  3. Approval-Mode: kimi --approval-mode auto-edit"
