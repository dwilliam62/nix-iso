#!/usr/bin/env bash
# Register documentation/links section

register_section docs "Documentation and links"

# Smart opener for GUI and TTY environments
_open_or_print() {
  local target="$1"

  # If it's a directory
  if [ -d "$target" ]; then
    if command -v xdg-open >/dev/null 2>&1 && [ -n "${XDG_CURRENT_DESKTOP:-}" ]; then
      nohup xdg-open "$target" >/dev/null 2>&1 &
      return
    fi
    echo "Listing: $target"
    ls -la "$target" || true
    return
  fi

  # If it's an HTML file
  case "$target" in
    *.html|*.htm)
      if command -v xdg-open >/dev/null 2>&1 && [ -n "${XDG_CURRENT_DESKTOP:-}" ]; then
        nohup xdg-open "$target" >/dev/null 2>&1 &
        return
      fi
      if command -v w3m >/dev/null 2>&1; then w3m "$target"; return; fi
      if command -v lynx >/dev/null 2>&1; then lynx "$target"; return; fi
      if command -v links >/dev/null 2>&1; then links "$target"; return; fi
      if command -v elinks >/dev/null 2>&1; then elinks "$target"; return; fi
      if command -v pandoc >/dev/null 2>&1; then
        pandoc -f html -t plain "$target" | ${PAGER:-less -R}
        return
      fi
      ;;
  esac

  # URLs or other files: try GUI first, then pager
  if [ -n "${XDG_CURRENT_DESKTOP:-}" ] && command -v xdg-open >/dev/null 2>&1; then
    nohup xdg-open "$target" >/dev/null 2>&1 &
    return
  fi
  if [ -f "$target" ]; then
    ${PAGER:-less -R} "$target" || cat "$target"
  else
    printf "Open: %s\n" "$target"
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

