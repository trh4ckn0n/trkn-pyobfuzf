#!/bin/bash

clear
echo -e "\e[1;36m=========== Obfuscateur Python Interactif - By Trhacknon ===========\e[0m"

# Dépendances
command -v fzf >/dev/null || { echo >&2 "fzf est requis. Installe avec : sudo apt install fzf"; exit 1; }
command -v pyarmor >/dev/null || echo -e "\e[1;31m[!] PyArmor non détecté. Installe avec : pip install pyarmor\e[0m"
command -v nuitka >/dev/null || echo -e "\e[1;33m[!] Nuitka non détecté. Installe avec : pip install nuitka\e[0m"

# Sélection du script avec fzf
target=$(find . -type f -name "*.py" | fzf --prompt="Sélectionne ton script Python : ")
[[ -z "$target" ]] && { echo "Aucun fichier sélectionné."; exit 1; }
echo -e "\n\e[1;33mScript sélectionné : $target\e[0m"

# Nom de sortie pour le dossier et l'archive
read -p "Nom de sortie personnalisé pour le dossier (laisser vide pour auto) : " customname
basename_output=$(basename "$target" .py)
output_name=${customname:-$basename_output}

# Choix méthode
method=$(printf "pyarmor\npyc (bytecode)\nnuitka (binaire natif)\npyarmor + nuitka" | fzf --prompt="Choisis la méthode d'obfuscation : ")
archive_format=$(printf "tar.gz\nzip\naucun" | fzf --prompt="Format d'archive de sortie : ")
encrypt=$(printf "aucun\nzip (mot de passe)\ngpg (clé ou mot de passe)" | fzf --prompt="Souhaites-tu chiffrer l'archive ? ")

# === Fonction pour générer le fichier USE.md ===
generate_use_md() {
  cat <<EOL > "$output_name/USE.md"
# Utilisation du projet obfusqué

## Description
Ce projet a été obfusqué en utilisant la méthode suivante : $method.

## Méthode d'Obfuscation
- **Méthode utilisée :** $method
- **Date de création :** $(date)
- **Format de l'archive :** $archive_format

## Instructions

1. Extraire l'archive :
   - Pour tar.gz :
     \`\`\`bash
     tar -xzf $output_name.$archive_format
     \`\`\`
   - Pour zip :
     \`\`\`bash
     unzip $output_name.$archive_format
     \`\`\`

2. Lancer le script obfusqué :
   - Naviguer dans le dossier extrait et exécuter le script obfusqué :
     \`\`\`bash
     python3 $(basename "$target")
     \`\`\`

EOL
}

# === Fonction d'archivage + chiffrement ===
archive_result() {
  archive_file=""
  case "$archive_format" in
    "tar.gz")
      tar czf "${output_name}.tar.gz" "$output_name"
      archive_file="${output_name}.tar.gz"
      ;;
    "zip")
      zip -r "${output_name}.zip" "$output_name" >/dev/null
      archive_file="${output_name}.zip"
      ;;
    "aucun")
      echo -e "\e[1;33mPas d'archive générée. Dossier : $output_name\e[0m"
      return
      ;;
  esac

  case "$encrypt" in
    "zip (mot de passe)")
      read -sp "Mot de passe ZIP : " zip_pass; echo
      mv "$archive_file" "${archive_file}.tmp"
      zip -r --password "$zip_pass" "$archive_file" "$output_name" >/dev/null
      rm -f "${archive_file}.tmp"
      echo -e "\e[1;32mArchive ZIP chiffrée créée : $archive_file\e[0m"
      ;;
    "gpg (clé ou mot de passe)")
      gpg_dest="${archive_file}.gpg"
      read -p $'\e[1;34mUtiliser une clé publique (y) ou mot de passe symétrique (n) ? \e[0m' gpg_choice
      if [[ "$gpg_choice" =~ ^[Yy]$ ]]; then
        read -p "ID ou email de la clé GPG publique : " gpg_key
        gpg -e -r "$gpg_key" -o "$gpg_dest" "$archive_file" && rm -f "$archive_file"
        echo -e "\e[1;32mFichier chiffré avec GPG : $gpg_dest\e[0m"
      else
        gpg -c -o "$gpg_dest" "$archive_file" && rm -f "$archive_file"
        echo -e "\e[1;32mFichier chiffré avec mot de passe : $gpg_dest\e[0m"
      fi
      ;;
    *)
      echo -e "\e[1;32mArchive créée : $archive_file\e[0m"
      ;;
  esac

  # Générer le fichier USE.md pour l'archive
  generate_use_md
}

# === Obfuscation selon méthode ===
case "$method" in
  "pyarmor")
    echo -e "\n\e[1;32m[+] Obfuscation avec PyArmor 8+...\e[0m"
    read -p "Activer expiration (Y/N) ? " exp
    exp_arg=""
    if [[ "$exp" =~ ^[Yy]$ ]]; then
        read -p "Date d'expiration (ex: 2025-12-31) : " date
        exp_arg="--expiry $date"
    fi

    mkdir -p "$output_name"

    # PyArmor 9+: bonne commande
    pyarmor gen "$target" --output "$output_name" $exp_arg

    archive_result
    ;;

  "pyc (bytecode)")
    echo -e "\n\e[1;34m[+] Compilation en .pyc...\e[0m"
    python3 -m compileall "$target"
    pyc_file=$(find . -type f -name "${basename_output}*.pyc" | head -n1)
    mkdir -p "$output_name"
    cp "$pyc_file" "$output_name/"
    archive_result
    ;;

  "nuitka (binaire natif)")
    echo -e "\n\e[1;35m[+] Compilation avec Nuitka...\e[0m"
    nuitka --standalone --lto --follow-imports --output-dir="$output_name" "$target"
    archive_result
    ;;

  "pyarmor + nuitka")
    echo -e "\n\e[1;36m[+] Combo : PyArmor + Nuitka...\e[0m"
    tmpdir="tmp_protect_$(date +%s)"
    mkdir "$tmpdir"
    cp "$target" "$tmpdir/"
    cd "$tmpdir" || exit 1
    pyarmor gen --restrict 1 -O obf "$(basename "$target")"
    cd obf || exit 1
    nuitka --standalone --lto --follow-imports "$(basename "$target")" --output-dir="../../$output_name"
    cd ../../
    rm -rf "$tmpdir"
    archive_result
    ;;
esac

echo -e "\n\e[1;36m========= Obfuscation terminée avec succès ! =========\e[0m"
