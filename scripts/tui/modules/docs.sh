#!/usr/bin/env bash
# Register documentation/links section

register_section docs "Documentation and links"

# xdg-open helper that degrades gracefully
_open_or_print() {
  local target="$1"
  if command -v xdg-open >/dev/null 2>&1; then
    nohup xdg-open "$target" >/dev/null 2>&1 &
  else
    echo "Open: $target"
  fi
}

# Offline docs folder
register_item docs docs_folder "Open offline documentation folder" "_open_or_print /etc/nix-iso-docs"

# Offline README (EN)
if [[ -e /etc/nix-iso-docs/README.html ]]; then
  register_item docs docs_readme_en "Open README (EN) offline" "_open_or_print /etc/nix-iso-docs/README.html"
fi

# Offline README (ES)
if [[ -e /etc/nix-iso-docs/README.es.html ]]; then
  register_item docs docs_readme_es "Abrir README (ES) sin conexión" "_open_or_print /etc/nix-iso-docs/README.es.html"
fi

# GitHub repo page (as requested)
register_item docs docs_github "Open GitHub repository" "_open_or_print https://github.com/dwilliam62/nix-iso"

