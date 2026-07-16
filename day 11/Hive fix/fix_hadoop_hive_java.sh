#!/usr/bin/env bash
###############################################################################
# fix_hadoop_hive_java.sh
#
# Purpose : Diagnose and fix the "Hive won't start because of the Java version
#           configured for Hadoop" problem.
#
# Root    : Hadoop 3.3.x supports Java 8 and 11 (runtime) only. If JAVA_HOME
# cause     points at Java 17, Hadoop daemons and Hive fail with reflection /
#           InaccessibleObjectException errors. Hive 4.1.0 supports Java 8/11/17,
#           so aligning everything on Java 11 satisfies BOTH.
#
# What it  : Checks each value with if-conditions BEFORE changing anything, then
# does      prints (and optionally applies) the correct command.
#
# Usage   : ./fix_hadoop_hive_java.sh            # report + prompt before changes
#           ./fix_hadoop_hive_java.sh --apply    # apply fixes without prompting
#           ./fix_hadoop_hive_java.sh --dry-run  # only report, change nothing
###############################################################################

set -uo pipefail

# ---------------------------------------------------------------------------
# 0. Configuration — edit these to match your machine
# ---------------------------------------------------------------------------
TARGET_JAVA="/usr/lib/jvm/java-11-openjdk-amd64"          # Java 11 is safe for Hadoop 3.3.x + Hive 4.x
HADOOP_DIR="/opt/bigdata/hadoop-3.3.6"
HIVE_DIR="/opt/bigdata/apache-hive-4.1.0-bin"
BASHRC="${HOME}/.bashrc"

HADOOP_ENV="${HADOOP_DIR}/etc/hadoop/hadoop-env.sh"
HIVE_ENV="${HIVE_DIR}/conf/hive-env.sh"

MODE="prompt"   # prompt | apply | dry-run
[[ "${1:-}" == "--apply"   ]] && MODE="apply"
[[ "${1:-}" == "--dry-run" ]] && MODE="dry-run"

# ---------------------------------------------------------------------------
# Small helpers
# ---------------------------------------------------------------------------
say()  { printf '%s\n' "$*"; }
ok()   { printf '  [ OK ]  %s\n' "$*"; }
warn() { printf '  [WARN]  %s\n' "$*"; }
bad()  { printf '  [FAIL]  %s\n' "$*"; }

# Run a command, but respect the chosen MODE.
run_or_show() {
    local cmd="$1"
    if [[ "$MODE" == "dry-run" ]]; then
        say "    would run: $cmd"
        return 0
    fi
    if [[ "$MODE" == "prompt" ]]; then
        read -r -p "    Run: '$cmd' ? [y/N] " reply
        if [[ ! "$reply" =~ ^[Yy]$ ]]; then
            say "    skipped."
            return 1
        fi
    fi
    eval "$cmd"
}

say "=============================================================="
say " Hadoop / Hive Java-version fixer   (mode: $MODE)"
say "=============================================================="

# ---------------------------------------------------------------------------
# 1. Does the target Java (11) actually exist?
# ---------------------------------------------------------------------------
say ""
say "[1] Checking that the target JDK is installed ..."
if [[ -x "${TARGET_JAVA}/bin/java" ]]; then
    ok "Found Java 11 at ${TARGET_JAVA}"
else
    bad "Target JDK not found at ${TARGET_JAVA}"
    say "    Install it, then re-run this script:"
    say "        sudo apt update && sudo apt install -y openjdk-11-jdk"
    say "    Or edit TARGET_JAVA at the top of this script to your real path."
    exit 1
fi

# ---------------------------------------------------------------------------
# 2. Which Hadoop version is installed, and is TARGET_JAVA compatible?
# ---------------------------------------------------------------------------
say ""
say "[2] Checking Hadoop version compatibility ..."
if [[ -x "${HADOOP_DIR}/bin/hadoop" ]]; then
    HADOOP_VER="$("${HADOOP_DIR}/bin/hadoop" version 2>/dev/null | awk 'NR==1{print $2}')"
    ok "Detected Hadoop ${HADOOP_VER}"
    # Hadoop 3.5+ requires Java 17 on the server; 3.0–3.4 want Java 8/11.
    HADOOP_MINOR="$(printf '%s\n' "$HADOOP_VER" | cut -d. -f2)"
    if [[ "$HADOOP_MINOR" =~ ^[0-9]+$ ]] && (( HADOOP_MINOR >= 5 )); then
        warn "Hadoop 3.5+ expects Java 17. Java 11 may be too old for this version."
        warn "Either set TARGET_JAVA to a Java 17 path, or use Hadoop <= 3.4 with Java 11."
    else
        ok "Hadoop ${HADOOP_VER} runs on Java 11 — target JDK is correct."
    fi
else
    warn "Could not find hadoop at ${HADOOP_DIR}. Edit HADOOP_DIR at the top of the script."
fi

# ---------------------------------------------------------------------------
# 3. What does the CURRENT shell think JAVA_HOME is?
# ---------------------------------------------------------------------------
say ""
say "[3] Checking the current shell's JAVA_HOME ..."
if [[ -z "${JAVA_HOME:-}" ]]; then
    warn "JAVA_HOME is EMPTY in this shell."
elif [[ "${JAVA_HOME}" == "${TARGET_JAVA}" ]]; then
    ok "JAVA_HOME already points at the target: ${JAVA_HOME}"
else
    bad "JAVA_HOME points at the WRONG JDK: ${JAVA_HOME}"
fi

# ---------------------------------------------------------------------------
# 4. What does `java` on the PATH actually resolve to?
# ---------------------------------------------------------------------------
say ""
say "[4] Checking the active 'java' binary ..."
if command -v java >/dev/null 2>&1; then
    ACTIVE_JAVA_VER="$(java -version 2>&1 | awk -F\" 'NR==1{print $2}')"
    say "    java -version reports: ${ACTIVE_JAVA_VER}"
    if [[ "$ACTIVE_JAVA_VER" == 11.* ]]; then
        ok "Active java is version 11."
    else
        warn "Active java is NOT 11. Fixing the system default alternative:"
        run_or_show "sudo update-alternatives --set java ${TARGET_JAVA}/bin/java"
    fi
else
    bad "No 'java' on PATH at all."
fi

# ---------------------------------------------------------------------------
# 5. Fix JAVA_HOME in ~/.bashrc (the usual culprit for a stale value)
# ---------------------------------------------------------------------------
say ""
say "[5] Checking ~/.bashrc for a stale JAVA_HOME ..."
if [[ -f "$BASHRC" ]] && grep -q 'JAVA_HOME' "$BASHRC"; then
    CURRENT_LINE="$(grep -n 'export JAVA_HOME' "$BASHRC" | head -n1)"
    if grep -q "export JAVA_HOME=${TARGET_JAVA}" "$BASHRC"; then
        ok "~/.bashrc already exports the correct JAVA_HOME."
    else
        warn "~/.bashrc sets a different JAVA_HOME: ${CURRENT_LINE}"
        # Replace ANY java-XX-openjdk path with the target, in place (with backup).
        run_or_show "sed -i.bak 's|export JAVA_HOME=.*|export JAVA_HOME=${TARGET_JAVA}|' '${BASHRC}'"
    fi
else
    warn "~/.bashrc does not set JAVA_HOME. Appending it."
    run_or_show "printf 'export JAVA_HOME=%s\nexport PATH=\$JAVA_HOME/bin:\$PATH\n' '${TARGET_JAVA}' >> '${BASHRC}'"
fi

# ---------------------------------------------------------------------------
# 6. Fix JAVA_HOME inside hadoop-env.sh
# ---------------------------------------------------------------------------
say ""
say "[6] Checking hadoop-env.sh ..."
if [[ -f "$HADOOP_ENV" ]]; then
    if grep -Eq "^[[:space:]]*export JAVA_HOME=${TARGET_JAVA}[[:space:]]*$" "$HADOOP_ENV"; then
        ok "hadoop-env.sh already points at the target JDK."
    else
        warn "hadoop-env.sh JAVA_HOME is missing or wrong. Setting it."
        # Remove any existing (even commented) JAVA_HOME lines, then append the correct one.
        run_or_show "sed -i.bak '/JAVA_HOME=/d' '${HADOOP_ENV}' && echo 'export JAVA_HOME=${TARGET_JAVA}' >> '${HADOOP_ENV}'"
    fi
else
    bad "hadoop-env.sh not found at ${HADOOP_ENV}. Check HADOOP_DIR."
fi

# ---------------------------------------------------------------------------
# 7. Fix JAVA_HOME inside hive-env.sh (only if the file overrides it)
# ---------------------------------------------------------------------------
say ""
say "[7] Checking hive-env.sh ..."
if [[ -f "$HIVE_ENV" ]]; then
    if grep -Eq "^[[:space:]]*export JAVA_HOME=" "$HIVE_ENV"; then
        if grep -Eq "^[[:space:]]*export JAVA_HOME=${TARGET_JAVA}[[:space:]]*$" "$HIVE_ENV"; then
            ok "hive-env.sh already points at the target JDK."
        else
            warn "hive-env.sh overrides JAVA_HOME with a different value. Aligning it."
            run_or_show "sed -i.bak 's|export JAVA_HOME=.*|export JAVA_HOME=${TARGET_JAVA}|' '${HIVE_ENV}'"
        fi
    else
        ok "hive-env.sh does not override JAVA_HOME (it will inherit Hadoop's). Nothing to do."
    fi
else
    warn "hive-env.sh not found. Hive will inherit JAVA_HOME from the shell / Hadoop."
fi

# ---------------------------------------------------------------------------
# 8. Summary + next steps
# ---------------------------------------------------------------------------
say ""
say "=============================================================="
say " Done. Now reload your shell and start Hadoop:"
say "=============================================================="
say "    source ~/.bashrc"
say "    echo \$JAVA_HOME          # expect: ${TARGET_JAVA}"
say "    java -version            # expect: 11.x"
say "    start-dfs.sh"
say "    start-yarn.sh"
say "    jps                      # expect NameNode, DataNode, SecondaryNameNode,"
say "                             #        ResourceManager, NodeManager"
say "    hive"
say ""
say " If a daemon is missing from 'jps', read its log under:"
say "    ${HADOOP_DIR}/logs/"
