#!/bin/bash
# NAME: Fn as Hotkey
# Fn as RetroArch hotkey enable (GO-Super / Y3506, scheme "default").
# Options > Tools reads this label. On an installed card, copy this file to /roms/tools/.
#
# Select (button 12) stays input_player1_select_btn, so games receive it.
# Function (button 16, GPIO F5) becomes the hotkey modifier.
# Menu stays on button 16: Fn alone opens the RetroArch menu.
# Pause moves to button 4: Fn + L1 pauses, and does not fire together with the menu.
#
# Re-applying the "default" control scheme keeps these two lines.
# The "no_function" scheme (R36H) puts the modifier back on Select.

set -u

HOTKEY_BTN="${HOTKEY_BTN:-16}"
MENU_BTN="${MENU_BTN:-16}"
PAUSE_BTN="${PAUSE_BTN:-4}"

CONFIG_DIR_64="${CONFIG_DIR_64:-/home/ark/.config/retroarch}"
CONFIG_DIR_32="${CONFIG_DIR_32:-/home/ark/.config/retroarch32}"
SCHEME_DIR="${SCHEME_DIR:-/usr/local/bin/r36_config/controls}"

FILES=(
  "$CONFIG_DIR_64/retroarch.cfg"
  "$CONFIG_DIR_64/retroarch.cfg.bak"
  "$CONFIG_DIR_32/retroarch.cfg"
  "$CONFIG_DIR_32/retroarch.cfg.bak"
)

updated=0
missing=0

set_cfg_value() {
  local file="$1" key="$2" value="$3"
  if grep -qE "^${key}[[:space:]]*=" "$file"; then
    sed -i -E "s/^(${key}[[:space:]]*=[[:space:]]*).*/\\1${value}/" "$file"
  else
    printf '%s = %s\n' "$key" "$value" >> "$file"
  fi
}

for file in "${FILES[@]}"; do
  if [ ! -f "$file" ]; then
    echo "Ausente, ignorado: $file"
    missing=$((missing + 1))
    continue
  fi
  if [ ! -w "$file" ]; then
    echo "Sem permissão de escrita: $file"
    exit 1
  fi
  set_cfg_value "$file" "input_enable_hotkey_btn" "\"${HOTKEY_BTN}\""
  set_cfg_value "$file" "input_menu_toggle_btn" "\"${MENU_BTN}\""
  set_cfg_value "$file" "input_pause_toggle_btn" "\"${PAUSE_BTN}\""
  echo "Atualizado: $file"
  updated=$((updated + 1))
done

if [ "$updated" -eq 0 ]; then
  echo "Nenhum retroarch.cfg foi alterado."
  exit 1
fi

write_file() {
  local dest="$1" src="$2"
  if [ -w "$dest" ]; then
    cat "$src" > "$dest"
    return $?
  fi
  if command -v sudo >/dev/null 2>&1; then
    sudo tee "$dest" < "$src" >/dev/null
    return $?
  fi
  echo "Sem permissão de escrita: $dest"
  return 1
}

# Keep a scheme reapply from restoring Select as the modifier or pause on Fn.
upsert_scheme_section() {
  local file="$1" section="$2" match="$3" replace="$4"
  local tmp status
  if [ ! -f "$file" ]; then
    echo "Scheme ausente, ignorado: $file"
    return 0
  fi
  tmp="$(mktemp)"
  awk -v section="$section" -v replace="$replace" '
    BEGIN { in_section = 0; found = 0; wrote = 0 }
    $0 ~ "^\\[" section "\\]$" { in_section = 1; found = 1; print; next }
    in_section && /^\[/ {
      if (!wrote) { print "replace = " replace; wrote = 1 }
      in_section = 0
    }
    in_section && $0 ~ "^replace[[:space:]]*=" {
      print "replace = " replace
      wrote = 1
      next
    }
    { print }
    END {
      if (in_section && !wrote) print "replace = " replace
      if (!found) exit 2
    }
  ' "$file" > "$tmp"
  status=$?
  if [ "$status" -eq 0 ]; then
    write_file "$file" "$tmp" || { rm -f "$tmp"; return 1; }
    rm -f "$tmp"
    echo "Scheme já continha [$section], valor regravado: $file"
    return 0
  fi
  rm -f "$tmp"
  if [ "$status" -eq 2 ]; then
    tmp="$(mktemp)"
    cat "$file" > "$tmp"
    # Two leading newlines: one finishes a file that has no trailing newline,
    # the other leaves a blank line before the new section.
    cat >> "$tmp" <<EOF


[$section]
files = /home/ark/.config/retroarch/retroarch.cfg, /home/ark/.config/retroarch/retroarch.cfg.bak, /home/ark/.config/retroarch32/retroarch.cfg, /home/ark/.config/retroarch32/retroarch.cfg.bak
operation = replace_line
match = $match
replace = $replace
EOF
    write_file "$file" "$tmp" || { rm -f "$tmp"; return 1; }
    rm -f "$tmp"
    echo "Scheme recebeu [$section]: $file"
    return 0
  fi
  echo "Falha ao atualizar [$section] em $file"
  return 1
}

DEFAULT_SCHEME="$SCHEME_DIR/default.ini"
NO_FUNCTION_SCHEME="$SCHEME_DIR/no_function.ini"

if [ -f "$DEFAULT_SCHEME" ]; then
  upsert_scheme_section "$DEFAULT_SCHEME" "retroarch_hotkey" \
    '^input_enable_hotkey_btn\s*=\s*.*$' \
    "input_enable_hotkey_btn = \"${HOTKEY_BTN}\"" || exit 1
  upsert_scheme_section "$DEFAULT_SCHEME" "retroarch_pause" \
    '^input_pause_toggle_btn\s*=\s*.*$' \
    "input_pause_toggle_btn = \"${PAUSE_BTN}\"" || exit 1
else
  echo "Scheme default ausente, ignorado: $DEFAULT_SCHEME"
fi

if [ -f "$NO_FUNCTION_SCHEME" ]; then
  upsert_scheme_section "$NO_FUNCTION_SCHEME" "retroarch_hotkey" \
    '^input_enable_hotkey_btn\s*=\s*.*$' \
    'input_enable_hotkey_btn = "12"' || exit 1
fi

echo
echo "Fn (botão ${HOTKEY_BTN}) é o modificador das hotkeys do RetroArch."
echo "Select (botão 12) volta a ser só o botão do jogo."
echo "Fn sozinho abre o menu. Fn + L1 pausa."
echo "Os demais atalhos continuam os mesmos, agora com Fn no lugar de Select."
echo "Feche o jogo atual antes de testar. Arquivos ausentes: ${missing}."
sleep 8
