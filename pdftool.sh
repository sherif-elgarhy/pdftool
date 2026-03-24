#!/usr/bin/env bash

# set -e intentionally omitted: interactive menus rely on functions returning
# non-zero (e.g. user cancels nnn) without killing the whole script.
# Each call site handles errors explicitly with || continue / || return.

# ──────[ COLORS ]──────
if [ -t 1 ]; then
  CYAN='\033[0;36m'
  YELLOW='\033[0;33m'
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  RESET='\033[0m'
else
  CYAN=""
  YELLOW=""
  RED=""
  GREEN=""
  RESET=""
fi

# ──────[ FUNCTIONS ]──────

NNN_FILTER="\.[Pp][Dd][Ff]$"

detect_platform() {
  if [ -n "$TERMUX_VERSION" ] || [[ "$HOME" == *com.termux* ]]; then
    echo "termux"
  elif [ -n "$PROOT_DISTRO_NAME" ]; then
    echo "proot-distro"
  elif [[ -r /system/build.prop ]] && grep -q "ro.build.version.sdk" /system/build.prop; then
    echo "android"
  elif [[ "$OSTYPE" == "linux-android" ]]; then
    echo "android"
  elif [[ "$(uname -s)" == "Linux" ]]; then
    echo "linux"
  elif [[ "$(uname -s)" == "Darwin" ]]; then
    echo "darwin"
  else
    echo "unknown"
  fi
}

# Map a command name to its apt package name where they differ
apt_package_name() {
  case "$1" in
    pdfinfo|pdftoppm|pdftotext) echo "poppler-utils" ;;
    *) echo "$1" ;;
  esac
}

check_dependencies() {
  BASE_DIR="$HOME"
  echo -e "${CYAN}🧪 Checking dependencies:${RESET} $*"
  local missing=()
  local platform
  platform="$(detect_platform)"
  if [ "$platform" = "termux" ]; then
    BASE_DIR="$HOME/storage/shared"
  fi

  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing+=("$cmd")
    fi
  done

  if [ ${#missing[@]} -eq 0 ]; then
    echo -e "${GREEN}✅ All dependencies are available.${RESET}"
    return 0
  fi

  echo -e "${RED}⚠️  Missing dependencies:${RESET}"
  for cmd in "${missing[@]}"; do
    echo -e "  - ${YELLOW}$cmd${RESET}"
  done
  echo

  case "$platform" in
    termux)
      echo -e "${CYAN}📟 Termux detected.${RESET}"
      echo -e "❓ Auto-install missing packages with ${YELLOW}pkg${RESET}? [Y/n]"
      read -rp "➤ " reply
      if [[ "$reply" =~ ^[Yy]$ || -z "$reply" ]]; then
        if pkg update && pkg install -y "${missing[@]}"; then
          echo -e "\n${GREEN}✅ Dependencies installed successfully.${RESET}"
          return 0
        fi
        echo -e "\n${RED}❌ Failed to install dependencies!${RESET}"
      fi
      echo -e "\n${RED}❌ Cannot proceed without required tools! Exiting.${RESET}"
      ;;

    linux)
      echo -e "${CYAN}🐧 Linux detected.${RESET}"
      # Map command names to apt package names
      local apt_pkgs=()
      for cmd in "${missing[@]}"; do
        apt_pkgs+=("$(apt_package_name "$cmd")")
      done
      # Deduplicate
      mapfile -t apt_pkgs < <(printf '%s
' "${apt_pkgs[@]}" | sort -u)
      local install_cmd="sudo apt install -y ${apt_pkgs[*]}"
      echo -e "💡 Install command: ${YELLOW}${install_cmd}${RESET}"
      read -rp "👉 Install now? [Y/n]: " reply
      if [[ "$reply" =~ ^[Yy]$ || -z "$reply" ]]; then
        if eval "$install_cmd"; then
          echo -e "${GREEN}✅ Dependencies installed successfully.${RESET}"
          # Re-check that commands are now available
          local still_missing=()
          for cmd in "${missing[@]}"; do
            command -v "$cmd" >/dev/null 2>&1 || still_missing+=("$cmd")
          done
          if [ ${#still_missing[@]} -eq 0 ]; then
            return 0
          fi
          echo -e "${RED}❌ Still missing after install: ${still_missing[*]}${RESET}"
        else
          echo -e "${RED}❌ Installation failed. Please install manually.${RESET}"
        fi
      fi
      echo -e "${RED}❌ Cannot proceed without required tools! Exiting.${RESET}"
      ;;

    darwin)
      echo -e "${CYAN}🍏 macOS detected.${RESET}"
      if ! command -v brew &>/dev/null; then
        echo -e "${YELLOW}⚠️  Homebrew not found. Install it from https://brew.sh then run:${RESET}"
        echo -e "   ${YELLOW}brew install ${missing[*]}${RESET}"
        exit 1
      fi
      local install_cmd="brew install ${missing[*]}"
      echo -e "💡 Install command: ${YELLOW}${install_cmd}${RESET}"
      read -rp "👉 Install now? [Y/n]: " reply
      if [[ "$reply" =~ ^[Yy]$ || -z "$reply" ]]; then
        if eval "$install_cmd"; then
          echo -e "${GREEN}✅ Dependencies installed successfully.${RESET}"
          local still_missing=()
          for cmd in "${missing[@]}"; do
            command -v "$cmd" >/dev/null 2>&1 || still_missing+=("$cmd")
          done
          if [ ${#still_missing[@]} -eq 0 ]; then
            return 0
          fi
          echo -e "${RED}❌ Still missing after install: ${still_missing[*]}${RESET}"
        else
          echo -e "${RED}❌ Installation failed. Please install manually.${RESET}"
        fi
      fi
      echo -e "${RED}❌ Cannot proceed without required tools! Exiting.${RESET}"
      ;;

    android)
      echo -e "${CYAN}📱 Android shell detected (non-Termux).${RESET}"
      echo -e "➡️  Please use Termux from F-Droid."
      ;;

    *)
      echo -e "${RED}❓ Unknown platform. Please install manually:${RESET}"
      echo -e "   ${YELLOW}${missing[*]}${RESET}"
      ;;
  esac

  exit 1
}

is_encrypted() {
  local file="$1"
  if qpdf --show-encryption "$file" 2>/dev/null | grep -q "not encrypted"; then
    return 1 # not encrypted
  else
    return 0 # encrypted
  fi
}

validate_pdf() {
  local file="$1"
  local action="$2"

  # 1. Check file existence
  if [ ! -f "$file" ]; then
    echo -e "${RED}❌ Error: File not found ${RESET}" >&2
    return 1
  fi

  # 2. Basic MIME type check
  if ! file -b --mime-type "$file" | grep -q "application/pdf"; then
    echo -e "${RED}❌ Error: File does not appear to be a PDF.${RESET}" >&2
    return 1
  fi

  # 3. Structural validity check
  if ! qpdf --check "$file" >/dev/null 2>&1; then
    if ! is_encrypted "$file"; then
      echo -e "${RED}❌ Error: This is a structurally invalid or unreadable PDF.${RESET}" >&2
      return 1
    fi
  fi

  # 4. Encryption state check
  if [[ "$action" == "decrypt" ]]; then
    if ! is_encrypted "$file"; then
      echo -e "${YELLOW}⚠️  This file is already decrypted." >&2
      echo -e "   Please pick an encrypted file to decrypt.${RESET}" >&2
      return 1
    fi
  elif [[ "$action" == "encrypt" ]]; then
    if is_encrypted "$file"; then
      echo -e "${YELLOW}⚠️  This file is already encrypted." >&2
      echo -e "   Please pick a decrypted file (or decrypt it first).${RESET}" >&2
      return 1
    fi
  fi

  return 0
}

pick_file() {
  local action="$1"   # "decrypt" or "encrypt"
  local mode="${2:-single}" # "single" or "multi"
  local launch_dir="${3:-$BASE_DIR}"

  {
    echo "📁  Launching nnn file manager for PDF selection ($mode)"
    echo "👉  Navigate with arrow keys"
    echo "    Press [Enter] to open folder"
    [[ "$mode" == "single" ]] && echo "    Press [Space] to select file"
    [[ "$mode" == "multi"  ]] && echo "    Press [Space] to tag multiple files"
    echo "    Press [Q] to quit"
    echo ""
  } >&2
  sleep 1

  local tmpfile file
  tmpfile="${launch_dir}/nnn.txt"
  (
    cd "$launch_dir"
    if [[ "$mode" == "single" ]]; then
      nnn -p "$tmpfile" -F "$NNN_FILTER"
    else
      # Use the same -F flag for consistency; NNN_FILT env var is unreliable
      # across nnn versions and doesn't apply in all multi-select scenarios
      nnn -p "$tmpfile" -F "$NNN_FILTER"
    fi
  )

  if [[ ! -s "$tmpfile" ]]; then
    echo -e "${YELLOW}❌ No files selected.${RESET}" >&2
    rm -f "$tmpfile"
    return 1
  fi

  # If multi → return whole list. If single → validate immediately.
  if [[ "$mode" == "multi" ]]; then
    cat "$tmpfile"
    rm -f "$tmpfile"
    return 0

  else
    local file
    file=$(<"$tmpfile")
    rm -f "$tmpfile"

    if ! validate_pdf "$file" "$action"; then
      return 1
    fi

    echo "$file"
    return 0
  fi
}

safe_output_name() {
  local base="$1"
  local ext="$2"
  local output="${base}.${ext}"
  local i=1
  while [ -f "$output" ]; do
    output="${base}_$i.${ext}"
    ((i++))
  done
  echo "$output"
}

pdf_info() {
  local file="$1"
  validate_pdf "$file" || return 1

  echo "📄 PDF Info Summary:"
  echo "────────────────────────"

  qpdf --check "$file" 2>&1 | grep -v -i "linearized" | sed 's/^/  🧪 /'

  echo
  echo "🔐 Encryption Info:"
  qpdf --show-encryption "$file" | sed 's/^/  🔍 /'

  echo "🚀 Linearization Info:"
  if qpdf --check-linearization "$file" >/dev/null 2>&1; then
    echo "  ✅ This PDF is linearized (web-optimized)"
  else
    echo "  ❌ Not linearized"
  fi
}

batch_process() {
  local action="$1"
  local pw confirm

  case "$action" in
    "decrypt")
      read -sp "🔑 Enter password for all selected PDFs: " pw
      echo  # newline after silent read
      ;;

    "encrypt")
      while true; do
        read -sp "🔑 Set password for all selected PDFs: " pw
        echo
        if [[ -z "$pw" ]]; then
          echo -e "${YELLOW}⚠️  Cancelled encryption.${RESET}"
          return 0  # user explicitly bailed out, exit cleanly
        fi

        read -sp "🔑 Confirm password: " confirm
        echo
        if [[ "$pw" != "$confirm" ]]; then
          echo -e "${RED}❌ Passwords do not match. Try again.${RESET}"
          continue  # re-prompt from the top
        else
          break
        fi
     done
     ;;
  esac

  echo -e "${CYAN}\n📂 Launching nnn for multi-select...${RESET}"
  # Read selected files into an array
  mapfile -t files < <(pick_file "$action" "multi") || return 1

  echo -e "${GREEN}📂 Starting batch $action...${RESET}"

  # Loop through array safely
  for file in "${files[@]}"; do
    [[ ! -f "$file" ]] && echo -e "${RED}❌ File not found: $file${RESET}" && continue
    if ! validate_pdf "$file" "$action"; then
      echo -e "${YELLOW}⚠️  Skipping invalid file: $file${RESET}"
      continue
    fi

    base="${file%.*}"

    case "$action" in
      "decrypt")
        output=$(safe_output_name "${base}_decrypted" "pdf")
        echo -e "🔓 ${CYAN}Decrypting → ${RESET}$output"
        qpdf --password="$pw" --decrypt "$file" "$output" \
          && echo -e "${GREEN}✅ Success!${RESET}" \
          || echo -e "${RED}❌ Failed: $file${RESET}"
        ;;

      "encrypt")
        output=$(safe_output_name "${base}_locked" "pdf")
        echo -e "🔐 ${CYAN}Encrypting → ${RESET}$output"
        qpdf --encrypt "$pw" "$pw" 256 -- "$file" "$output" \
          && echo -e "${GREEN}✅ Success!${RESET}" \
          || echo -e "${RED}❌ Failed: $file${RESET}"
        ;;
    esac
  done

  echo -e "${GREEN}✅ Batch $action complete.${RESET}"
}

merge_pdfs() {
  echo -e "${CYAN}📎 Select PDFs to merge (in order):${RESET}"
  mapfile -t files < <(pick_file "merge" "multi") || return 1

  echo -e "${CYAN}✨ Merging…${RESET}"

  read -rp "📝 Output filename (without .pdf): " name
  [[ -z "$name" ]] && name="merged"
  output=$(safe_output_name "$name" "pdf")

  qpdf --empty --pages "${files[@]}" -- "$output" \
    && echo -e "${GREEN}✅ Merged: $output${RESET}" \
    || echo -e "${RED}❌ Merge failed${RESET}"
}

split_pdf() {
  file=$(pick_file "split") || return 1
  read -rp "📄 Enter page range (e.g. 1-3,5,7-9): " range

  base="${file%.*}_split"
  output=$(safe_output_name "$base" "pdf")

  qpdf "$file" --pages "$file" "$range" -- "$output" \
    && echo -e "${GREEN}✅ Created: $output${RESET}" \
    || echo -e "${RED}❌ Split failed${RESET}"
}

open_pdf_terminal() {
  local file
  file=$(pick_file "") || return 1

  if command -v chafa >/dev/null; then
    # chafa renders images as Unicode art in the terminal
    echo -e "${CYAN}🖼️  Rendering with chafa...${RESET}"
    local pages tmpdir
    pages=$(pdfinfo "$file" | awk '/Pages/{print $2}')
    tmpdir=$(mktemp -d)

    for i in $(seq 1 "$pages"); do
      echo "📄 Page $i / $pages"
      # pdftoppm writes files to disk — capture the actual output file, then pass to chafa
      pdftoppm -f "$i" -l "$i" -png -r 96 "$file" "$tmpdir/page"
      local img="$tmpdir/page-${i}.png"
      # pdftoppm zero-pads with enough digits for the page count
      [[ ! -f "$img" ]] && img=$(ls "$tmpdir"/page-*.png 2>/dev/null | head -1)
      if [[ -f "$img" ]]; then
        chafa --size=80x40 --colors=8 "$img"
        rm -f "$img"
      fi
      echo
      read -n1 -s -rp "Press any key to continue, Q to quit..." key
      echo
      [[ "$key" =~ [Qq] ]] && break
    done
    rm -rf "$tmpdir"

  elif command -v img2txt >/dev/null; then
    echo -e "${CYAN}🖼️  Rendering with img2txt...${RESET}"
    img2txt "$file"
  elif command -v pdftotext >/dev/null; then
    echo -e "${CYAN}📖 Showing text view...${RESET}"
    pdftotext "$file" - | less -R
  else
    echo -e "${RED}❌ No terminal PDF viewer found.${RESET}"
    echo -e "   Install ${YELLOW}chafa${RESET} for image rendering or ${YELLOW}pdftotext${RESET} for text view."
  fi
}

show_help() {
  echo "Usage: $0 [OPTIONS] <FILE>"
  echo
  echo "  -d, --decrypt        Decrypts a PDF file."
  echo "  -e, --encrypt        Encrypts a PDF file with a new password."
  echo "  -p <PASSWORD>        Specify the password on the command line."
  echo "  -h, --help           Show this help message and exit."
  echo
  echo "If no options are provided, the script will run in interactive menu mode."
  exit 0
}

# ──────[ MAIN LOGIC ]──────
run_interactive() {
  local option file base output

  while true; do
    echo
    echo -e "${CYAN}📄 PDF Toolbox${RESET}"
    echo "──────────────────────────────"
    echo -e "1) ${GREEN}🔓 Decrypt PDF ${RESET}'Remove password'"
    echo -e "2) ${GREEN}🔐 Encrypt PDF ${RESET}'Add password'"
    echo -e "3) ${GREEN}🧾 View PDF info ${RESET}"
    echo -e "4) ${GREEN}🔄 Batch decrypt ${RESET}"
    echo -e "5) ${GREEN}🔄 Batch encrypt ${RESET}"
    echo -e "6) ${GREEN}📎 Merge PDFs ${RESET}"
    echo -e "7) ${GREEN}✂️  Split PDF ${RESET}"
    echo -e "8) ${GREEN}👁️  View PDF in terminal ${RESET}"
    echo "Q) ❌ Quit"
    echo

    read -rp "👉 Select an option: " option
    echo

    case "$option" in
      1)
        file=$(pick_file "decrypt") || continue
        base="${file%.*}_decrypted"
        output=$(safe_output_name "$base" "pdf")

        while true; do
          read -sp "🔑 Enter password to unlock (leave blank to cancel): " pw
          echo
          if [[ -z "$pw" ]]; then
            echo -e "${YELLOW}⚠️  Cancelled decryption.${RESET}"
            break
          fi

          if qpdf --password="$pw" --decrypt "$file" "$output"; then
            echo -e "${GREEN}✅ Decrypted: ${RESET}$output"
            break
          else
            echo -e "${RED}❌ Incorrect password or decryption failed.${RESET}"
            # loop will continue, letting the user retry
          fi
        done
        ;;

      2)
        file=$(pick_file "encrypt") || continue
        base="${file%.*}_locked"
        output=$(safe_output_name "$base" "pdf")

        while true; do
          read -sp "🔑 Set new password (leave blank to cancel): " newpw

          if [[ -z "$newpw" ]]; then
            echo -e "${YELLOW}⚠️  Cancelled encryption.${RESET}"
            break  # exit the password loop, return to main menu
          fi

          read -sp "🔑 Confirm new password: " confirm
          echo

          if [[ "$newpw" != "$confirm" ]]; then
            echo -e "${RED}❌ Passwords do not match. Try again.${RESET}"
            continue
          fi

          if qpdf --encrypt "$newpw" "$newpw" 256 -- "$file" "$output"; then
            echo -e "${GREEN}🔐 Encrypted: ${RESET}$output"
          else
            echo -e "${RED}❌ Encryption failed.${RESET}"
          fi
          break
        done
        ;;

      3)
        file=$(pick_file) || continue
        pdf_info "$file"
        ;;

      4) batch_process "decrypt" ;;
      5) batch_process "encrypt" ;;
      6) merge_pdfs ;;
      7) split_pdf ;;
      8) open_pdf_terminal ;;

      Q|q)
        echo -e "${CYAN}👋 Goodbye!${RESET}"
        break
        ;;

      *)
        echo -e "${RED}❌ Invalid option. Try again.${RESET}"
        ;;
    esac
  done
}

main() {
  check_dependencies "qpdf" "nnn"
  local file password action base output

  file=""
  password=""
  action=""

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      -d|--decrypt)
        action="decrypt"
        shift
        ;;
      -e|--encrypt)
        action="encrypt"
        shift
        ;;
      -p|--password)
        password="$2"
        shift 2
        ;;
      -h|--help)
        show_help
        ;;
      *)
        if [[ -z "$file" ]]; then
          file="$1"
        else
          echo -e "${RED}❌ Invalid argument: $1 ${RESET}"
          show_help
        fi
        shift
        ;;
    esac
  done

  if [[ -n "$action" && -n "$file" ]]; then
    validate_pdf "$file" "$action" || return 1

    if [[ -z "$password" ]]; then
      if [[ "$action" == "decrypt" ]]; then
        read -sp "🔑 Enter password to unlock: " password
      else
        read -sp "🔑 Set new password: " password
      fi
      echo
    fi

    base="${file%.*}"

    if [[ "$action" == "decrypt" ]]; then
      output=$(safe_output_name "${base}_decrypted" "pdf")
      if qpdf --password="$password" --decrypt "$file" "$output"; then
        echo -e "${GREEN}✅ Decrypted: ${RESET}$output"
      else
        echo -e "${RED}❌ Failed to decrypt: $file ${RESET}"
      fi

    else # encrypt
      output=$(safe_output_name "${base}_locked" "pdf")
      if qpdf --encrypt "$password" "$password" 256 -- "$file" "$output"; then
        echo -e "${GREEN}🔐 Encrypted: ${RESET}$output"
      else
        echo -e "${RED}❌ Failed to encrypt: $file ${RESET}"
      fi
    fi
    return 0

  elif [[ -n "$action" || -n "$password" || -n "$file" ]]; then
    echo -e "${RED}❌ Missing required arguments. Please provide an action and a file path.${RESET}"
    show_help
    exit 1

  else
    # No arguments, run interactive menu
    run_interactive
  fi
}

main "$@"
