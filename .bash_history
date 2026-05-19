
  ${B}CONFIG${N}
    Gradle props   : $KEYSTORE_PROPS   ${Y}(fill passwords)${N}
    Gradle snippet : $NEBULA_GRADLE_SNIPPET
    SHIELD registry: $SHIELD_REGISTRY
    SHIELD CLI     : $SHIELD_CLI
    Backups dir    : $BACKUP_DIR

${C}TRY IT${N}
    shield list
    shield verify $RELEASE_KS $RELEASE_ALIAS
    shield fingerprint $UPLOAD_KS $UPLOAD_ALIAS

${C}NEXT STEPS${N}
    1. Fill passwords:    nano $KEYSTORE_PROPS
    2. Merge Gradle:      cat $NEBULA_GRADLE_SNIPPET
                          → integrate into $APP_GRADLE_KTS
    3. Build:             cd $NEBULA_ROOT && ./gradlew assembleRelease
    4. Verify APK:        shield verify app/build/outputs/apk/release/app-release.apk
    5. Cold-store backup blob from $BACKUP_DIR (USB + cloud-encrypted)

${M}SHIELD PIN CONFIRMED • OWNER OVERRIDE ACTIVE • CHEF EATS FREE${N}

EOF

# Reload PATH first time
source ~/.bashrc
# List pinned identities
shield list
# Verify your release keystore against registry
shield verify ~/nebula/.secrets/nebula-release.keystore nebula-release
# Verify a built APK
shield verify ~/nebula/app/build/outputs/apk/release/app-release.apk
# Get a fingerprint
shield fingerprint ~/nebula/.secrets/nebula-upload.keystore nebula-upload
unshield in package unshield
#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# KNOCKSSTUDiOS • NEBULA • MASTER AUTORUN
# Chains: Signing → SHIELD Pin → Gradle Wiring → Backup → CLI Verifier
# Hardened • Self-healing • Termux-safe • Idempotent
# ═══════════════════════════════════════════════════════════════
set -uo pipefail
# ── CONFIG ─────────────────────────────────────────────────────
NEBULA_ROOT="${NEBULA_ROOT:-$HOME/nebula}"
SOUL_ROOT="${SOUL_ROOT:-$HOME/soul-engine}"
SECRETS_DIR="$NEBULA_ROOT/.secrets"
SCRIPTS_DIR="$NEBULA_ROOT/scripts"
BIN_DIR="$HOME/.local/bin"
RELEASE_KS="$SECRETS_DIR/nebula-release.keystore"
UPLOAD_KS="$SECRETS_DIR/nebula-upload.keystore"
RELEASE_ALIAS="nebula-release"
UPLOAD_ALIAS="nebula-upload"
SHIELD_REGISTRY_DIR="$SOUL_ROOT/shield/registry"
SHIELD_REGISTRY="$SHIELD_REGISTRY_DIR/signing-identities.json"
KEYSTORE_PROPS="$NEBULA_ROOT/keystore.properties"
GITIGNORE="$NEBULA_ROOT/.gitignore"
APP_GRADLE_KTS="$NEBULA_ROOT/app/build.gradle.kts"
APP_GRADLE_GROOVY="$NEBULA_ROOT/app/build.gradle"
BACKUP_DIR="$HOME/nebula-backups"
SHIELD_CLI="$BIN_DIR/shield"
# ── COLORS ─────────────────────────────────────────────────────
B="\033[1m"; G="\033[32m"; Y="\033[33m"; R="\033[31m"; C="\033[36m"; M="\033[35m"; N="\033[0m"
log()  { echo -e "${C}[NEBULA]${N} $*"; }
ok()   { echo -e "${G}[ OK ]${N} $*"; }
warn() { echo -e "${Y}[WARN]${N} $*"; }
err()  { echo -e "${R}[FAIL]${N} $*" >&2; }
hdr()  { echo -e "\n${B}${M}═══ $* ═══${N}"; }
step() { echo -e "${B}── $* ──${N}"; }
die() { err "$*"; return 1 2>/dev/null || exit 1; }
# ── BANNER ─────────────────────────────────────────────────────
clear 2>/dev/null || true
cat <<'EOF'

  ╔══════════════════════════════════════════════════════════╗
  ║   KNOCKSSTUDiOS • NEBULA • MASTER AUTORUN                ║
  ║   SOUL ENGINE (QUANTUM 44) • SHIELD ANTI-SPOOF           ║
  ╚══════════════════════════════════════════════════════════╝

EOF

# ════════════════════════════════════════════════════════════════
# PREFLIGHT
# ════════════════════════════════════════════════════════════════
hdr "PREFLIGHT"
command -v keytool >/dev/null || die "keytool missing → pkg install openjdk-17"
ok "keytool: $(command -v keytool)"
command -v gpg >/dev/null || warn "gpg missing → backup phase will skip (pkg install gnupg)"
command -v node >/dev/null || warn "node missing → JSON validation skipped (pkg install nodejs-lts)"
mkdir -p "$SECRETS_DIR" "$SCRIPTS_DIR" "$BIN_DIR" "$BACKUP_DIR"
chmod 700 "$SECRETS_DIR" "$BACKUP_DIR"
ok "dirs ready: secrets / scripts / bin / backups"
# ════════════════════════════════════════════════════════════════
# PHASE 1 • RELEASE KEYSTORE DETECTION
# ════════════════════════════════════════════════════════════════
hdr "PHASE 1 • RELEASE KEYSTORE"
if [[ -f "$RELEASE_KS" ]]; then     ok "found: $RELEASE_KS";     chmod 600 "$RELEASE_KS"; else     warn "missing at canonical path";     FOUND=$(find "$HOME" -name "nebula-release.keystore" 2>/dev/null | head -n1);     if [[ -n "$FOUND" ]]; then         warn "located at: $FOUND";         echo -n "Move to $RELEASE_KS? [y/N]: ";         read -r ANS;         [[ "$ANS" =~ ^[Yy]$ ]] && { mv "$FOUND" "$RELEASE_KS"; chmod 600 "$RELEASE_KS"; ok "moved"; }                                || { RELEASE_KS="$FOUND"; warn "using $RELEASE_KS"; };     else         echo -n "Generate new release keystore? [y/N]: ";         read -r ANS;         [[ "$ANS" =~ ^[Yy]$ ]] || die "release keystore required";         keytool -genkeypair -v -keystore "$RELEASE_KS" -alias "$RELEASE_ALIAS"             -keyalg RSA -keysize 2048 -validity 10000             -dname "CN=KNOCKS,O=KNOCKSSTUDiOS,C=US" || die "keygen failed";         chmod 600 "$RELEASE_KS";         ok "generated";     fi; fi
��═════════════════════════════════════════════
hdr "PHASE 5 • SHIELD REGISTRY"
mkdir -p "$SHIELD_REGISTRY_DIR"
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
cat > "$SHIELD_REGISTRY" <<EOF
{
  "version": "1.0.0",
  "engine": "SOUL_QUANTUM_44",
  "shield_policy": "anti-spoof",
  "owner": "KNOCKSSTUDiOS",
  "updated_at": "$TS",
  "identities": [
    {
      "id": "nebula-release-v1",
      "product": "NEBULA",
      "channel": "release",
      "algorithm": "RSA-2048",
      "signature": "SHA384withRSA",
      "sha256": "$RELEASE_SHA",
      "dn": "CN=KNOCKS, O=KNOCKSSTUDiOS, C=US",
      "rotatable": false,
      "owner_override": true,
      "purpose": "direct-signing",
      "registered_at": "$TS"
    },
    {
      "id": "nebula-upload-v1",
      "product": "NEBULA",
      "channel": "upload",
      "algorithm": "RSA-2048",
      "signature": "SHA256withRSA",
      "sha256": "$UPLOAD_SHA",
      "dn": "CN=KNOCKS Upload, O=KNOCKSSTUDiOS, C=US",
      "rotatable": true,
      "owner_override": true,
      "purpose": "play-store-upload",
      "registered_at": "$TS"
    }
  ]
}
EOF

if command -v node >/dev/null 2>&1; then     node -e "JSON.parse(require('fs').readFileSync('$SHIELD_REGISTRY'))" 2>/dev/null         && ok "registry written + JSON valid"         || warn "registry written but JSON invalid"; else     ok "registry written"; fi
# ════════════════════════════════════════════════════════════════
# PHASE 6 • GRADLE WIRING
# ════════════════════════════════════════════════════════════════
hdr "PHASE 6 • GRADLE SIGNING WIRING"
GRADLE_BLOCK_KTS=$(cat <<'GRADLE'

// ── KNOCKSSTUDiOS • NEBULA • Signing Config (autogen) ─────────
import java.util.Properties
import java.io.FileInputStream

val keystorePropsFile = rootProject.file("keystore.properties")
val keystoreProps = Properties().apply {
    if (keystorePropsFile.exists()) load(FileInputStream(keystorePropsFile))
}
fun sval(key: String, env: String): String? =
    System.getenv(env) ?: keystoreProps.getProperty(key)

android {
    signingConfigs {
        create("release") {
            val sf = sval("storeFile", "NEBULA_STORE_FILE")
            val sp = sval("storePassword", "NEBULA_STORE_PASS")
            val ka = sval("keyAlias", "NEBULA_KEY_ALIAS")
            val kp = sval("keyPassword", "NEBULA_KEY_PASS")
            if (sf != null && sp != null && ka != null && kp != null) {
                storeFile = rootProject.file(sf)
                storePassword = sp
                keyAlias = ka
                keyPassword = kp
                enableV1Signing = false
                enableV2Signing = true
                enableV3Signing = true
                enableV4Signing = true
            } else {
                println("⚠️  NEBULA signing missing — release will be UNSIGNED")
            }
        }
    }
    buildTypes {
        getByName("release") {
            isMinifyEnabled = true
            isShrinkResources = true
            signingConfig = signingConfigs.getByName("release")
        }
    }
}
GRADLE
)
NEBULA_GRADLE_SNIPPET="$NEBULA_ROOT/nebula-signing.gradle.kts"
echo "$GRADLE_BLOCK_KTS" > "$NEBULA_GRADLE_SNIPPET"
ok "Gradle KTS snippet written: $NEBULA_GRADLE_SNIPPET"
if [[ -f "$APP_GRADLE_KTS" ]]; then     if grep -q "KNOCKSSTUDiOS • NEBULA • Signing Config" "$APP_GRADLE_KTS"; then         warn "signing block already present in $APP_GRADLE_KTS";     else         warn "manual merge needed → append snippet contents into:";         warn "   $APP_GRADLE_KTS";         warn "   (do NOT duplicate android { } blocks — merge inside existing one)";     fi; elif [[ -f "$APP_GRADLE_GROOVY" ]]; then     warn "Groovy build.gradle detected — Kotlin DSL snippet won't drop in directly";     warn "request:  OPUS::BUILD gradle-signing-groovy"; else     warn "no app/build.gradle(.kts) yet — snippet saved for later use"; fi
# ════════════════════════════════════════════════════════════════
# PHASE 7 • ENCRYPTED BACKUP
# ════════════════════════════════════════════════════════════════
hdr "PHASE 7 • ENCRYPTED BACKUP"
if command -v gpg >/dev/null 2>&1; then     BACKUP_NAME="nebula-secrets-$(date +%Y%m%d-%H%M%S).tar.gz.gpg";     BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME";      log "creating encrypted blob — you'll set a BACKUP passphrase";     log "(use a DIFFERENT passphrase from your keystore passwords)";      if tar -czf - -C "$NEBULA_ROOT" .secrets keystore.properties 2>/dev/null         | gpg -c --cipher-algo AES256 --s2k-mode 3 --s2k-count 65011712               -o "$BACKUP_PATH"; then         chmod 600 "$BACKUP_PATH";         ok "backup: $BACKUP_PATH";          if gpg -d "$BACKUP_PATH" 2>/dev/null | tar -tzf - >/dev/null 2>&1; then             ok "backup integrity verified";         else             warn "backup written but verification readback failed (passphrase mismatch?)";         fi;     else         warn "backup creation failed";     fi; else     warn "gpg not installed — skipping encrypted backup";     warn "install:  pkg install gnupg  →  re-run this script"; fi
# ════════════════════════════════════════════════════════════════
# PHASE 8 • SHIELD CLI VERIFIER
# ════════════════════════════════════════════════════════════════
hdr "PHASE 8 • SHIELD CLI INSTALL"
cat > "$SHIELD_CLI" <<'SHIELDCLI'
#!/usr/bin/env bash
# ─── SOUL ENGINE • SHIELD • CLI VERIFIER ────────────────────────
# Usage:
#   shield list
#   shield verify <apk-or-keystore-path> [alias]
#   shield fingerprint <keystore-path> <alias>
# ────────────────────────────────────────────────────────────────
set -uo pipefail

REGISTRY="${SHIELD_REGISTRY:-$HOME/soul-engine/shield/registry/signing-identities.json}"

R="\033[31m"; G="\033[32m"; Y="\033[33m"; C="\033[36m"; B="\033[1m"; N="\033[0m"

die() { echo -e "${R}[shield] $*${N}" >&2; exit 1; }

[[ -f "$REGISTRY" ]] || die "registry missing: $REGISTRY"

CMD="${1:-}"
case "$CMD" in
    list)
        echo -e "${B}SHIELD REGISTRY${N}  ($REGISTRY)"
        if command -v node >/dev/null 2>&1; then
            node -e "
              const r=JSON.parse(require('fs').readFileSync('$REGISTRY'));
              console.log('engine: '+r.engine+'  policy: '+r.shield_policy);
              r.identities.forEach(i=>{
                console.log('  ['+i.id+']  '+i.product+'/'+i.channel);
                console.log('    sha256: '+i.sha256);
                console.log('    purpose: '+i.purpose+'  rotatable: '+i.rotatable);
              });"
        else
            cat "$REGISTRY"
        fi
        ;;

    fingerprint)
        KS="${2:-}"; AL="${3:-}"
        [[ -f "$KS" && -n "$AL" ]] || die "usage: shield fingerprint <keystore> <alias>"
        echo -n "keystore password: "; read -rs PW; echo
        keytool -list -v -keystore "$KS" -alias "$AL" -storepass "$PW" 2>/dev/null \
            | grep "SHA256:" | awk '{print $2}' | tr -d ':' | tr '[:upper:]' '[:lower:]'
        unset PW
        ;;

    verify)
        TARGET="${2:-}"
        [[ -f "$TARGET" ]] || die "usage: shield verify <apk-or-keystore> [alias]"

        FP=""
        if [[ "$TARGET" == *.apk ]]; then
            command -v apksigner >/dev/null || die "apksigner not in PATH"
            FP=$(apksigner verify --print-certs "$TARGET" 2>/dev/null \
                 | grep "SHA-256 digest:" | head -n1 | awk '{print $4}' \
                 | tr -d ':' | tr '[:upper:]' '[:lower:]')
        else
            AL="${3:-nebula-release}"
            echo -n "keystore password: "; read -rs PW; echo
            FP=$(keytool -list -v -keystore "$TARGET" -alias "$AL" -storepass "$PW" 2>/dev/null \
                 | grep "SHA256:" | awk '{print $2}' | tr -d ':' | tr '[:upper:]' '[:lower:]')
            unset PW
        fi

        [[ -n "$FP" ]] || die "could not extract fingerprint"
        echo -e "${C}target SHA-256: ${FP}${N}"

        if command -v node >/dev/null 2>&1; then
            MATCH=$(node -e "
              const r=JSON.parse(require('fs').readFileSync('$REGISTRY'));
              const m=r.identities.find(i=>i.sha256.toLowerCase()==='$FP');
              if(m){console.log('MATCH '+m.id+' '+m.product+'/'+m.channel);}
              else{console.log('NO_MATCH');}")
            if [[ "$MATCH" == MATCH* ]]; then
                echo -e "${G}[shield] ✅ $MATCH${N}"
                exit 0
            else
                echo -e "${R}[shield] ❌ FINGERPRINT NOT IN REGISTRY${N}"
                exit 2
            fi
        else
            if grep -q "\"$FP\"" "$REGISTRY"; then
                echo -e "${G}[shield] ✅ MATCH (grep fallback)${N}"
                exit 0
            else
                echo -e "${R}[shield] ❌ NO MATCH${N}"
                exit 2
            fi
        fi
        ;;

    *)
        cat <<USAGE
${B}SHIELD CLI${N}  •  SOUL ENGINE (QUANTUM 44)

  shield list
      Show all pinned signing identities

  shield fingerprint <keystore> <alias>
      Print SHA-256 of a keystore alias

  shield verify <apk>
      Verify APK signature against registry
  shield verify <keystore> <alias>
      Verify keystore alias against registry

  registry: $REGISTRY
USAGE
        ;;
esac
SHIELDCLI

chmod +x "$SHIELD_CLI"
ok "shield CLI installed: $SHIELD_CLI"
# Add ~/.local/bin to PATH if not already
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then     SHELL_RC="";     [[ -f "$HOME/.bashrc" ]] && SHELL_RC="$HOME/.bashrc";     [[ -f "$HOME/.zshrc"  ]] && SHELL_RC="$HOME/.zshrc";      if [[ -n "$SHELL_RC" ]] && ! grep -q ".local/bin" "$SHELL_RC"; then         echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$SHELL_RC";         ok "PATH updated in $SHELL_RC (restart shell or:  source $SHELL_RC)";     else         warn "add to your shell rc:  export PATH=\"\$HOME/.local/bin:\$PATH\"";     fi; fi
# ════════════════════════════════════════════════════════════════
# PHASE 9 • FINAL VERIFICATION
# ════════════════════════════════════════════════════════════════
hdr "PHASE 9 • FINAL VERIFICATION"
step "release fingerprint"
keytool -list -keystore "$RELEASE_KS" -alias "$RELEASE_ALIAS" -storepass "$RELEASE_PASS" 2>/dev/null     | grep -E "Alias|fingerprint" || warn "release verify skipped"
step "upload fingerprint"
keytool -list -keystore "$UPLOAD_KS" -alias "$UPLOAD_ALIAS" -storepass "$UPLOAD_PASS" 2>/dev/null     | grep -E "Alias|fingerprint" || warn "upload verify skipped"
step "shield self-test"
if [[ -x "$SHIELD_CLI" ]]; then     SHIELD_REGISTRY="$SHIELD_REGISTRY" "$SHIELD_CLI" list 2>/dev/null | head -n12 || warn "shield list failed"; fi
# ── CLEAR PASSWORD VARS ────────────────────────────────────────
unset RELEASE_PASS UPLOAD_PASS R_OUT U_OUT
# ════════════════════════════════════════════════════════════════
# SUMMARY
# ════════════════════════════════════════════════════════════════
hdr "AUTORUN COMPLETE"
cat <<EOF

${G}✅ NEBULA FULL SIGNING STACK DEPLOYED${N}

  ${B}KEYSTORES${N}
    Release  : $RELEASE_KS
    Upload   : $UPLOAD_KS

  ${B}FINGERPRINTS${N}
    Release  : $RELEASE_SHA
    Upload   : $UPLOAD_SHA

  ${B}CONFIG${N}
    Gradle props   : $KEYSTORE_PROPS   ${Y}(fill passwords)${N}
    Gradle snippet : $NEBULA_GRADLE_SNIPPET
    SHIELD registry: $SHIELD_REGISTRY
    SHIELD CLI     : $SHIELD_CLI
    Backups dir    : $BACKUP_DIR

${C}TRY IT${N}
    shield list
    shield verify $RELEASE_KS $RELEASE_ALIAS
    shield fingerprint $UPLOAD_KS $UPLOAD_ALIAS

${C}NEXT STEPS${N}
    1. Fill passwords:    nano $KEYSTORE_PROPS
    2. Merge Gradle:      cat $NEBULA_GRADLE_SNIPPET
                          → integrate into $APP_GRADLE_KTS
    3. Build:             cd $NEBULA_ROOT && ./gradlew assembleRelease
    4. Verify APK:        shield verify app/build/outputs/apk/release/app-release.apk
    5. Cold-store backup blob from $BACKUP_DIR (USB + cloud-encrypted)

${M}SHIELD PIN CONFIRMED • OWNER OVERRIDE ACTIVE • CHEF EATS FREE${N}

EOF

bash <(curl -s https://raw.githubusercontent.com/knocksstudios/claude-web-install/main/install.sh)
bash <(curl -s https://raw.githubusercontent.com/YOUR-USERNAME/YOUR-REPO/main/install.sh)
#!/bin/bash
set -e
echo "Creating Claude Web Chat…"
mkdir -p claude-web
cd claude-web
cat > index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Claude Chat</title>
  <style>
    body { font-family: Arial; background: #111; color: #fff; padding: 20px; }
    #chat { height: 70vh; overflow-y: auto; border: 1px solid #444; padding: 10px; }
    input { width: 100%; padding: 10px; margin-top: 10px; }
  </style>
</head>
<body>
  <h1>Claude Chat</h1>
  <div id="chat"></div>
  <input id="msg" placeholder="Say something…" />
  <script src="chat.js"></script>
</body>
</html>
EOF

cat > chat.js << 'EOF'
const API_KEY = "YOUR_CLAUDE_API_KEY";

async function sendMessage(text) {
  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "x-api-key": API_KEY,
      "anthropic-version": "2023-06-01",
      "content-type": "application/json"
    },
    body: JSON.stringify({
      model: "claude-3-opus-20240229",
      messages: [{ role: "user", content: text }]
    })
  });

  const data = await res.json();
  return data.content[0].text;
}

const chat = document.getElementById("chat");
const input = document.getElementById("msg");

input.addEventListener("keydown", async (e) => {
  if (e.key === "Enter") {
    const text = input.value;
    input.value = "";
    chat.innerHTML += `<div><b>You:</b> ${text}</div>`;
    const reply = await sendMessage(text);
    chat.innerHTML += `<div><b>Claude:</b> ${reply}</div>`;
    chat.scrollTop = chat.scrollHeight;
  }
});
EOF

echo "Done. Upload the claude-web folder to hollywoodimaging.studio"
const API_KEY = "sk-ant-xxxxxxxxxxxxxxxxxxxxxxxx";
bash <(curl -s https://raw.githubusercontent.com/knocksstudios/claude-web-install/main/install.sh)
bash <(curl -s https://raw.githubusercontent.com/YOUR-USERNAME/YOUR-REPO/main/install.sh)
#!/bin/bash
set -e
echo "Creating Claude Web Chat…"
mkdir -p claude-web
cd claude-web
cat > index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Claude Chat</title>
  <style>
    body { font-family: Arial; background: #111; color: #fff; padding: 20px; }
    #chat { height: 70vh; overflow-y: auto; border: 1px solid #444; padding: 10px; }
    input { width: 100%; padding: 10px; margin-top: 10px; }
  </style>
</head>
<body>
  <h1>Claude Chat</h1>
  <div id="chat"></div>
  <input id="msg" placeholder="Say something…" />
  <script src="chat.js"></script>
</body>
</html>
EOF

cat > chat.js << 'EOF'
const API_KEY = "YOUR_CLAUDE_API_KEY";

async function sendMessage(text) {
  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "x-api-key": API_KEY,
      "anthropic-version": "2023-06-01",
      "content-type": "application/json"
    },
    body: JSON.stringify({
      model: "claude-3-opus-20240229",
      messages: [{ role: "user", content: text }]
    })
  });

  const data = await res.json();
  return data.content[0].text;
}

const chat = document.getElementById("chat");
const input = document.getElementById("msg");

input.addEventListener("keydown", async (e) => {
  if (e.key === "Enter") {
    const text = input.value;
    input.value = "";
    chat.innerHTML += `<div><b>You:</b> ${text}</div>`;
    const reply = await sendMessage(text);
    chat.innerHTML += `<div><b>Claude:</b> ${reply}</div>`;
    chat.scrollTop = chat.scrollHeight;
  }
});
EOF

echo "Done. Upload the claude-web folder to hollywoodimaging.studio"
const API_KEY = "sk-ant-xxxxxxxxxxxxxxxxxxxxxxxx";
