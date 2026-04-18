#!/bin/bash
for SCRIPT in scripts/install-zaneyos-main.sh scripts/install-zaneyos.sh; do
  awk '
    /print_header "Setting Passwords"/ {
      in_passwords = 1
      next
    }
    /echo -e "\\${BLUE}Setting root password...\\${NC}"/ {
      in_passwords = 0
      next
    }
    in_passwords {
      password_block = password_block $0 "\n"
    }
    /print_header "Initiating NixOS Installation"/ {
      print "print_header \"Setting Passwords\""
      print password_block
      
      print "  echo -e \"${BLUE}Injecting passwords into NixOS configuration...${NC}\""
      print "  cat <<NIXEOF > ./hosts/$hostName/passwords.nix"
      print "{"
      print "  users.users.\\\"$systemUsername\\\".initialHashedPassword = \\\"$USER_HASH\\\";"
      print "  users.users.root.initialHashedPassword = \\\"$ROOT_HASH\\\";"
      print "}"
      print "NIXEOF"
      print "  echo -e \"${GREEN}✓ Passwords injected into ./hosts/$hostName/passwords.nix${NC}\""
      print "  # Add the passwords module to default.nix"
      print "  sed -i '\\|./hardware.nix|a \\    ./passwords.nix' ./hosts/$hostName/default.nix"
      print "  echo"
      print $0
      next
    }
    /sed -i "s|\\^root:\\[\\^:\\]\\*:|root:\\${ROOT_HASH}:|" \\/mnt\\/etc\\/shadow/ { next }
    /sed -i "s|\\^root:.*|root:\\${ROOT_HASH}:|" \\/mnt\\/etc\\/shadow/ { next }
    /echo -e "\\${GREEN}✓ Root password set\\${NC}"/ { next }
    /# Set user password if provided/ { skip_user_pass = 1; next }
    /echo -e "\\${BLUE}Setting password for user \\'\\$systemUsername\\'...\\${NC}"/ { next }
    /sed -i "s|\\^\\${systemUsername}:\\[\\^:\\]\\*:|\\${systemUsername}:\\${USER_HASH}:|" \\/mnt\\/etc\\/shadow/ { next }
    /sed -i "s|\\^\\${systemUsername}:.*|\\${systemUsername}:\\${USER_HASH}:|" \\/mnt\\/etc\\/shadow/ { next }
    /echo -e "\\${GREEN}✓ User password set\\${NC}"/ { skip_user_pass = 0; next }
    skip_user_pass { next }
    { print }
  ' "$SCRIPT" > "$SCRIPT.tmp"
  mv "$SCRIPT.tmp" "$SCRIPT"
  chmod +x "$SCRIPT"
done
