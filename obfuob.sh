#!/bin/bash

clear
echo -e "\e[1;36m=========== Trhacknon - Obfuscateur Interactif ===========\e[0m"

# Dépendances
command -v fzf >/dev/null || { echo >&2 "fzf est requis. Installe avec : sudo apt install fzf"; exit 1; }
command -v pyarmor >/dev/null || echo -e "\e[1;31m[!] PyArmor non détecté. Installe avec : pip install pyarmor\e[0m"
command -v nuitka >/dev/null || echo -e "\e[1;33m[!] Nuitka non détecté. Installe avec : pip install nuitka\e[0m"

# Sélection du script avec fzf
_t=$(find . -type f -name "*.py" | fzf --prompt="Sélectionne ton script Python : ")
[[ -z "$_t" ]] && { echo "Aucun fichier sélectionné."; exit 1; }
echo -e "\n\e[1;33mScript sélectionné : $_t\e[0m"

# Nom de sortie pour le dossier et l'archive
read -p "Nom de sortie personnalisé pour le dossier (laisser vide pour auto) : " _n
_b=$(basename "$_t" .py)
_o=${_n:-$_b}

# Choix méthode
_m=$(printf "pyarmor\npyc (bytecode)\nnuitka (binaire natif)\npyarmor + nuitka" | fzf --prompt="Choisis la méthode d'obfuscation : ")
_a=$(printf "tar.gz\nzip\naucun" | fzf --prompt="Format d'archive de sortie : ")
_e=$(printf "aucun\nzip (mot de passe)\ngpg (clé ou mot de passe)" | fzf --prompt="Souhaites-tu chiffrer l'archive ? ")

# === Fonction pour générer le fichier USE.md ===
_f() {
  cat <<EOL > "$_o/USE.md"
# Utilisation du projet obfusqué

## Description
Ce projet a été obfusqué en utilisant la méthode suivante : $_m.

## Méthode d'Obfuscation
- **Méthode utilisée :** $_m
- **Date de création :** $(date)
- **Format de l'archive :** $_a

## Instructions

1. Extraire l'archive :
   - Pour tar.gz :
     \`\`\`bash
     tar -xzf $_o.$_a
     \`\`\`
   - Pour zip :
     \`\`\`bash
     unzip $_o.$_a
     \`\`\`

2. Lancer le script obfusqué :
   - Naviguer dans le dossier extrait et exécuter le script obfusqué :
     \`\`\`bash
     python3 $(basename "$_t")
     \`\`\`

EOL
}

# === Fonction d'archivage + chiffrement ===
_g() {
  _a_f=""
  case "$_a" in
    "tar.gz")
      tar czf "${_o}.tar.gz" "$_o"
      _a_f="${_o}.tar.gz"
      ;;
    "zip")
      zip -r "${_o}.zip" "$_o" >/dev/null
      _a_f="${_o}.zip"
      ;;
    "aucun")
      echo -e "\e[1;33mPas d'archive générée. Dossier : $_o\e[0m"
      return
      ;;
  esac

  case "$_e" in
    "zip (mot de passe)")
      read -sp "Mot de passe ZIP : " _z; echo
      mv "$_a_f" "${_a_f}.tmp"
      zip -r --password "$_z" "$_a_f" "$_o" >/dev/null
      rm -f "${_a_f}.tmp"
      echo -e "\e[1;32mArchive ZIP chiffrée créée : $_a_f\e[0m"
      ;;
    "gpg (clé ou mot de passe)")
      _g_d="${_a_f}.gpg"
      read -p $'\e[1;34mUtiliser une clé publique (y) ou mot de passe symétrique (n) ? \e[0m' _g_c
      if [[ "$_g_c" =~ ^[Yy]$ ]]; then
        read -p "ID ou email de la clé GPG publique : " _g_k
        gpg -e -r "$_g_k" -o "$_g_d" "$_a_f" && rm -f "$_a_f"
        echo -e "\e[1;32mFichier chiffré avec GPG : $_g_d\e[0m"
      else
        gpg -c -o "$_g_d" "$_a_f" && rm -f "$_a_f"
        echo -e "\e[1;32mFichier chiffré avec mot de passe : $_g_d\e[0m"
      fi
      ;;
    *)
      echo -e "\e[1;32mArchive créée : $_a_f\e[0m"
      ;;
  esac

  # Générer le fichier USE.md pour l'archive
  _f
}

# === Obfuscation selon méthode ===
case "$_m" in
  "pyarmor")
    echo -e "\n\e[1;32m[+] Obfuscation avec PyArmor 8+...\e[0m"
    read -p "Activer expiration (Y/N) ? " _ex
    _ex_arg=""
    if [[ "$_ex" =~ ^[Yy]$ ]]; then
        read -p "Date d'expiration (ex: 2025-12-31) : " _date
        _ex_arg="--expiry $_date"
    fi

    mkdir -p "$_o"

    # PyArmor 9+: bonne commande
    pyarmor gen "$_t" --output "$_o" $_ex_arg

    _g
    ;;

  "pyc (bytecode)")
    echo -e "\n\e[1;34m[+] Compilation en .pyc...\e[0m"
    python3 -m compileall "$_t"
    _pyc=$(find . -type f -name "${_b}*.pyc" | head -n1)
    mkdir -p "$_o"
    cp "$_pyc" "$_o/"
    _g
    ;;

  "nuitka (binaire natif)")
    echo -e "\n\e[1;35m[+] Compilation avec Nuitka...\e[0m"
    nuitka --standalone --lto="auto" --follow-imports --output-dir="$_o" "$_t"
    _g
    ;;

  "pyarmor + nuitka")
    echo -e "\n\e[1;36m[+] Combo : PyArmor + Nuitka...\e[0m"
    _tmp="tmp_protect_$(date +%s)"
    mkdir "$_tmp"
    cp "$_t" "$_tmp/"
    cd "$_tmp" || exit 1
    pyarmor gen -output obf "$(basename "$_t")"
    cd obf || exit 1
    nuitka --standalone --lto="auto" --follow-imports "$(basename "$_t")" --output-dir="../../$_o"
    cd ../../
    rm -rf "$_tmp"
    _g
    ;;
esac

echo -e "\n\e[1;36m========= Obfuscation terminée avec succès ! =========\e[0m"
