#!/usr/bin/env bash
# Library for nix-iso TUI
# Provides registration and simple ASCII UI helpers.

# Section registry
# - SECTIONS_ORDER: indexes section_ids in display order
# - SECTIONS_TITLES[section_id] = title
# - SECTION_ITEMS_<section_id>: array of item_ids in this section
# Items registry
# - ITEM_LABEL[item_id] = label string
# - ITEM_CMD[item_id]   = command string to run when selected
# - ITEM_WARN[item_id]  = optional warning string

shopt -s extglob

# Arrays and maps
SECTIONS_ORDER=()
declare -A SECTIONS_TITLES=()
declare -A ITEM_LABEL=()
declare -A ITEM_CMD=()
declare -A ITEM_WARN=()

register_section() {
  local id="$1" title="$2"
  SECTIONS_ORDER+=("$id")
  SECTIONS_TITLES["$id"]="$title"
  # create items array for this section via nameref
  eval "SECTION_ITEMS_${id}=()"
}

register_item() {
  local section_id="$1" id="$2" label="$3" cmd="$4" warn_text="${5:-}"
  # Append to section items
  eval "SECTION_ITEMS_${section_id}+=(\"$id\")"
  ITEM_LABEL["$id"]="$label"
  ITEM_CMD["$id"]="$cmd"
  ITEM_WARN["$id"]="$warn_text"
}

# UI helpers
repeat_char() { local char="$1" count="$2"; printf "%${count}s" "" | tr ' ' "$char"; }
color_cyan() { printf "\033[36m%s\033[0m" "$*"; }
color_yellow() { printf "\033[33m%s\033[0m" "$*"; }
color_red() { printf "\033[31m%s\033[0m" "$*"; }

print_header() {
  local title="$1"
  local width=${COLUMNS:-80}
  echo "$(repeat_char = "$width")"
  printf " %s\n" "$title"
  echo "$(repeat_char = "$width")"
  echo
}

warn() { echo "$(color_yellow "[warn]") $*"; }
error() { echo "$(color_red "[error]") $*" >&2; }

is_number() { [[ "$1" =~ ^[0-9]+$ ]]; }

confirm() {
  local prompt="${1:-Are you sure?}"
  while true; do
    read -rp "$prompt [y/N]: " ans
    case "${ans:-}" in
      [Yy]|[Yy][Ee][Ss]) return 0 ;;
      ""|[Nn]|[Nn][Oo]) return 1 ;;
      *) warn "Please answer y or n" ;;
    esac
  done
}

