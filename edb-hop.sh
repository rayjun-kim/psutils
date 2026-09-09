#!/bin/bash
# edb-hop.sh - install / configure / run the DB2-for-i -> EDB Postgres
# migration tool (Apache Hop project "edb-hop").
#
# Expects to be run from the directory it was extracted into, alongside
# a "files/" subdirectory holding:
#   files/edb-hop-v1.2.tar.gz          - the project's pipelines/config template
#   files/apache-hop-client-2.19.0.zip - the Apache Hop CLI client
#   files/java-21-openjdk.zip          - a JDK the client can run on
#
#   edb-mig-hop/
#     edb-hop.sh
#     files/
#       edb-hop-v1.2.tar.gz
#       apache-hop-client-2.19.0.zip
#       java-21-openjdk.zip
#
# --install extracts the Hop client to ./hop, then the bundled JDK to
# ./hop/java-bundle (kept inside hop/ rather than alongside it, since
# it's an implementation detail of running Hop, not a top-level thing).
#
# Usage:
#   ./edb-hop.sh --install [--force]
#   ./edb-hop.sh --config  [connection options...] [--show]
#   ./edb-hop.sh --run     [--level LEVEL] [--reset] [--param KEY=VALUE]...
#
#   ./edb-hop.sh --install --docker --base-image IMAGE [options]
#       Generates a Dockerfile that bakes edb-hop into a Hop web-app
#       (Tomcat) base image. Only ever writes the file and prints the
#       docker build/run commands - never invokes docker itself.
#   ./edb-hop.sh --run --docker [--tag NAME] [--port PORT] [--name NAME]
#       Actually runs `docker run` to start a container from an image
#       already built from that generated Dockerfile.
#
# Run './edb-hop.sh --config --help' etc. for per-command options.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$SCRIPT_DIR"
FILES_DIR="$INSTALL_DIR/files"
PROJECT_NAME="edb-hop"

HOP_ARCHIVE="$FILES_DIR/apache-hop-client-2.19.0.zip"
EDB_HOP_ARCHIVE="$FILES_DIR/edb-hop-v1.2.tar.gz"
JAVA_ARCHIVE="$FILES_DIR/java-21-openjdk.zip"

# ------------------------------------------------------------------
# Shared helpers
# ------------------------------------------------------------------

usage() {
  cat <<'EOF'
Usage: edb-hop.sh <command> [options]

Commands:
  --install [--force]        Install Java, Apache Hop, and the edb-hop
                              project into this directory.
  --config  [options]        Set ASIS/TOBE connection info in config.yaml,
                              ASIS.json and TOBE.json.
  --run     [options]        Run the migration workflow via hop-run.sh.

  --install --docker ...     Generate a Dockerfile that bakes edb-hop
                              into a Hop web-app base image (writes the
                              file and prints instructions only - never
                              runs docker itself).
  --run --docker ...         Start a container from an image already
                              built from that Dockerfile.

Run 'edb-hop.sh <command> --help' for command-specific options, and
'edb-hop.sh <command> --docker --help' for the docker-mode options.
EOF
}

# Prints the java-21-openjdk installation directory under the given
# base directory (hop/java-bundle once installed). Never hardcoded:
# the archive's top-level folder name is versioned (e.g.
# java-21-openjdk-21.0.12.1.1-1.2.el9_8.aarch64), so this is
# re-resolved by globbing every time rather than assumed.
resolve_java_home() {
  local base="$1"
  local dir
  dir=$(find "$base" -mindepth 1 -maxdepth 1 -type d -iname "java-21-openjdk*" 2>/dev/null | sort | head -n1)
  if [ -z "$dir" ]; then
    echo "ERROR: no java-21-openjdk installation found under $base - run '$0 --install' first." >&2
    return 1
  fi
  echo "$dir"
}

# Path to the marker file recording an --install-time
# --use-system-java/--java-home choice (a single line: the absolute JAVA_HOME
# to use). Kept alongside hop/ (not inside it) so it survives a plain
# `--install --force`, which only resets config.yaml/ASIS.json/TOBE.json, not
# this - re-running --install --force should not silently switch back to the
# bundled JDK underneath an operator who deliberately opted into the host's
# own Java.
java_home_override_file() {
  local hop_home="$1"
  echo "$(dirname "$hop_home")/.java_home_override"
}

# Resolves the JAVA_HOME edb-hop.sh should actually use: an --install-time
# --use-system-java/--java-home override if one was recorded, otherwise the
# bundled JDK under hop/java-bundle (the default, existing behavior). Used by
# both --install (to run hop-conf.sh) and --run, so the choice made once at
# --install time is honored consistently by every later --run.
resolve_java_home_for_hop() {
  local hop_home="$1"
  local override_file
  override_file=$(java_home_override_file "$hop_home")
  if [ -f "$override_file" ]; then
    local override_home
    override_home=$(cat "$override_file")
    if [ ! -x "$override_home/bin/java" ]; then
      echo "ERROR: $override_file points at '$override_home', but" >&2
      echo "  $override_home/bin/java is missing or not executable - was that Java" >&2
      echo "  installation removed/moved? Re-run --install --use-system-java or" >&2
      echo "  --install --java-home PATH to fix this, or delete $override_file to" >&2
      echo "  fall back to a bundled JDK under hop/java-bundle." >&2
      return 1
    fi
    echo "$override_home"
    return 0
  fi
  resolve_java_home "$hop_home/java-bundle"
}

# Prints the Apache Hop client home directory under $INSTALL_DIR.
resolve_hop_home() {
  if [ -f "$INSTALL_DIR/hop/hop-run.sh" ]; then
    echo "$INSTALL_DIR/hop"
    return 0
  fi
  local found
  found=$(find "$INSTALL_DIR" -mindepth 2 -maxdepth 2 -type f -iname "hop-run.sh" 2>/dev/null | head -n1)
  if [ -n "$found" ]; then
    dirname "$found"
    return 0
  fi
  echo "ERROR: no Apache Hop installation found under $INSTALL_DIR - run '$0 --install' first." >&2
  return 1
}

# Splits "--key=value" style args into separate "--key" "value" args
# so every command accepts both "--foo bar" and "--foo=bar". Sets the
# result into the global NORMALIZED_ARGS array (an array, not a command
# substitution, so values containing spaces survive intact).
#
# Every caller must then do `set -- "${NORMALIZED_ARGS[@]+"${NORMALIZED_ARGS[@]}"}"`
# - not the bare "${NORMALIZED_ARGS[@]}" form - because a command invoked
# with no extra flags at all (a bare `--install`, `--config`, or `--run`)
# leaves NORMALIZED_ARGS empty, and on bash 3.2 (still macOS's default
# /bin/bash, frozen pre-GPLv3) expanding an empty array under `set -u`
# raises "unbound variable" - confirmed while running this script for real
# on macOS. ${arr[@]+alt} is the portable idiom: it expands to nothing when
# the array has no set elements, avoiding the crash, and to `alt` (here,
# the array itself) otherwise. The same idiom is needed for any other
# array that can legitimately end up empty (see extra_params/p_arg in
# cmd_run() below).
normalize_eq_args() {
  NORMALIZED_ARGS=()
  local arg
  for arg in "$@"; do
    if [[ "$arg" == --*=* ]]; then
      NORMALIZED_ARGS+=("${arg%%=*}" "${arg#*=}")
    else
      NORMALIZED_ARGS+=("$arg")
    fi
  done
}

# Hard requirement for --install (it calls unzip directly) - fail fast
# with install instructions instead of a cryptic "command not found"
# partway through extracting an archive.
require_unzip() {
  if ! command -v unzip >/dev/null 2>&1; then
    echo "ERROR: 'unzip' is required but was not found on this system." >&2
    echo "  Install it first, e.g.:" >&2
    echo "    RHEL/Rocky/CentOS/Fedora : sudo dnf install -y unzip" >&2
    echo "    Debian/Ubuntu            : sudo apt-get install -y unzip" >&2
    return 1
  fi
}

# zip isn't actually used by edb-hop.sh itself (only unzip is) - this is
# just a courtesy heads-up since the two are commonly expected together.
notice_zip() {
  if ! command -v zip >/dev/null 2>&1; then
    echo "NOTICE: 'zip' is not installed on this system. edb-hop.sh itself" >&2
    echo "  only needs 'unzip', so this is not a blocker - just flagging it" >&2
    echo "  in case something else on this host expects 'zip' too." >&2
  fi
}

# Purely informational: edb-hop.sh always uses the bundled JDK it
# extracts under hop/java-bundle for its own operations, regardless of
# what's already on PATH, to guarantee the exact version Hop needs.
# This just surfaces what's already there so it isn't a silent surprise.
notice_system_java() {
  if command -v java >/dev/null 2>&1; then
    local ver
    ver=$(java -version 2>&1 | head -n1)
    echo "NOTICE: a system java is already on PATH ($ver), but edb-hop.sh"
    echo "  always uses the bundled JDK under hop/java-bundle for its own"
    echo "  operations instead, to guarantee the version Hop needs."
  fi
}

# Replaces the value of a top-level "key": "..." field anywhere in a
# JSON file (each field lives on its own line in Hop's connection
# metadata files, so a per-line match is unambiguous). No-op if value
# is empty, so callers can pass through unset options untouched.
set_json_field() {
  local file="$1" key="$2" value="$3"
  [ -z "$value" ] && return 0
  local esc
  esc=$(printf '%s' "$value" | sed -e 's/[&/\]/\\&/g')
  sed -i "s/\"${key}\": \"[^\"]*\"/\"${key}\": \"${esc}\"/" "$file"
}

# Reads the current value of a top-level "key": "..." field, for
# showing as the default in --config -i prompts (and in --show).
get_json_field() {
  local file="$1" key="$2"
  sed -n "s/.*\"${key}\": \"\([^\"]*\)\".*/\1/p" "$file" | head -n1
}

# Prints config.yaml's general.ASIS.active_source value (there is only one
# "active_source:" line in the file, so a plain per-line match is enough).
read_active_source() {
  local config_yaml="$1"
  [ -f "$config_yaml" ] || return 0
  sed -n 's/^[[:space:]]*active_source:[[:space:]]*//p' "$config_yaml" | head -n1
}

# Prints the extra JVM flags (space-separated) the currently active source
# connector needs, if any. Each source under sources/<name>/ may ship an
# optional "jvm-opts" file (one flag per line) for driver-specific JVM
# properties it needs (e.g. the DB2-for-i connector's AS/400 JT400 driver
# needs -Dcom.ibm.as400.access.AS400.guiAvailable=false to stop it from
# popping a GUI signon dialog on connection failure, which otherwise crashes
# with HeadlessException on a server with no X11 display). This keeps
# edb-hop.sh itself source-agnostic - a new connector with no such quirks
# simply omits the file, and one that needs its own flags just adds it,
# with no changes to edb-hop.sh required.
read_source_jvm_opts() {
  local project_dir="$1"
  local active_source
  active_source=$(read_active_source "$project_dir/config.yaml")
  [ -n "$active_source" ] || return 0
  local opts_file="$project_dir/sources/$active_source/jvm-opts"
  [ -f "$opts_file" ] || return 0
  tr '\n' ' ' < "$opts_file"
}

# ------------------------------------------------------------------
# --install
# ------------------------------------------------------------------

cmd_install() {
  normalize_eq_args "$@"
  set -- "${NORMALIZED_ARGS[@]+"${NORMALIZED_ARGS[@]}"}"

  # --docker switches this into an entirely different mode (generate a
  # Dockerfile, no local Java/Hop install) - peek for it up front.
  local a
  for a in "$@"; do
    if [ "$a" = "--docker" ]; then
      cmd_install_docker "$@"
      return
    fi
  done

  local force=0
  local use_system_java=0
  local java_home_arg=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --force) force=1; shift ;;
      --use-system-java) use_system_java=1; shift ;;
      --java-home) java_home_arg="$2"; shift 2 ;;
      -h|--help)
        cat <<'EOF'
Usage: edb-hop.sh --install [--force] [--use-system-java | --java-home PATH]

Extracts Java, Apache Hop, and the edb-hop project into this directory
and registers the "edb-hop" project with Hop. Safe to re-run: already
extracted archives are left alone, and an already-configured
config.yaml / ASIS.json / TOBE.json is preserved across upgrades
unless --force is given (which resets them back to the shipped
template - use this only if you want to start configuration over).

By default, --install bundles and always uses its own JDK under
hop/java-bundle, to guarantee an exact known-good Java regardless of
what (if anything) the host already has - matching edb-hop.sh's
"fully self-contained, nothing pre-installed required" design.

  --use-system-java   Use whatever `java` is already on this host's PATH
                       instead of bundling one - skips extracting
                       java-21-openjdk.zip entirely. Requires `java` to
                       already be on PATH.
  --java-home PATH     Use an existing Java installation at this exact
                       path (PATH/bin/java must exist) instead of
                       bundling one - e.g. a server's already-installed
                       Java that isn't necessarily first on PATH.

Either choice is recorded (in .java_home_override, next to hop/) and
honored by every later --run too, not just this one --install - re-run
--install --use-system-java/--java-home to change it, or delete
.java_home_override to fall back to the bundled JDK. Neither Hop nor
this script currently validates the chosen Java's actual version - if
Hop needs a version its own compatibility docs specify and the host's
`java` is older/newer than that, that mismatch is on you to check.

See 'edb-hop.sh --install --docker --help' for the Docker-image mode.
EOF
        return 0 ;;
      *) echo "Unknown --install option: $1" >&2; return 1 ;;
    esac
  done

  if [ "$use_system_java" -eq 1 ] && [ -n "$java_home_arg" ]; then
    echo "ERROR: --use-system-java and --java-home are mutually exclusive - pick one." >&2
    exit 1
  fi

  require_unzip || exit 1
  notice_zip
  if [ "$use_system_java" -eq 0 ] && [ -z "$java_home_arg" ]; then
    notice_system_java
  fi

  echo "== Apache Hop client =="
  if [ ! -f "$INSTALL_DIR/hop/hop-run.sh" ]; then
    [ -f "$HOP_ARCHIVE" ] || { echo "ERROR: $HOP_ARCHIVE not found." >&2; exit 1; }
    unzip -q -o "$HOP_ARCHIVE" -d "$INSTALL_DIR"
    if [ ! -f "$INSTALL_DIR/hop/hop-run.sh" ]; then
      # Official release zips sometimes extract into a single nested
      # version-named folder rather than flat "hop/" - detect and
      # flatten rather than assuming either layout.
      local nested
      nested=$(find "$INSTALL_DIR" -mindepth 2 -maxdepth 2 -type f -iname "hop-run.sh" 2>/dev/null | head -n1)
      if [ -n "$nested" ]; then
        mv "$(dirname "$nested")" "$INSTALL_DIR/hop"
      fi
    fi
  fi
  local hop_home
  hop_home=$(resolve_hop_home)
  chmod +x "$hop_home"/*.sh
  echo "  $hop_home"

  echo "== Java =="
  local java_home
  local override_file
  override_file=$(java_home_override_file "$hop_home")
  if [ "$use_system_java" -eq 1 ] || [ -n "$java_home_arg" ]; then
    if [ -n "$java_home_arg" ]; then
      java_home="$java_home_arg"
    else
      command -v java >/dev/null 2>&1 || {
        echo "ERROR: --use-system-java given, but no 'java' found on PATH." >&2
        exit 1
      }
      # java is commonly a symlink several levels deep (e.g.
      # /usr/bin/java -> /etc/alternatives/java -> the real JDK's
      # bin/java) - resolve it fully rather than assuming one hop.
      local java_bin
      java_bin=$(command -v java)
      if command -v realpath >/dev/null 2>&1; then
        java_bin=$(realpath "$java_bin")
      elif command -v readlink >/dev/null 2>&1; then
        # readlink -f isn't portable to BSD/macOS readlink, but this
        # script's --use-system-java is meant for the Linux server case
        # ("기존 서버 java" - an existing host's already-installed Java),
        # where GNU readlink's -f is available.
        java_bin=$(readlink -f "$java_bin" 2>/dev/null || echo "$java_bin")
      fi
      java_home=$(dirname "$(dirname "$java_bin")")
    fi
    if [ ! -x "$java_home/bin/java" ]; then
      echo "ERROR: '$java_home/bin/java' does not exist or is not executable." >&2
      if [ -n "$java_home_arg" ]; then
        echo "  --java-home '$java_home_arg' is wrong." >&2
      else
        echo "  Could not resolve a real JAVA_HOME from the 'java' found on PATH." >&2
      fi
      exit 1
    fi
    echo "$java_home" > "$override_file"
    echo "  using $java_home (recorded in $override_file - --run will use it too)"
  elif [ -f "$override_file" ]; then
    # A previous --install already chose --use-system-java/--java-home and
    # this is a plain re-install (no --force, no new Java flag) - honor
    # that choice rather than silently falling back to a bundled JDK.
    java_home=$(resolve_java_home_for_hop "$hop_home")
    echo "  using previously-configured $java_home (from $override_file)"
  else
    # Kept inside hop/java-bundle rather than alongside hop/ at the top
    # level, since it's an implementation detail of running Hop, not a
    # top-level thing the user needs to see next to edb-hop.sh.
    local java_bundle_dir="$hop_home/java-bundle"
    java_home=$(resolve_java_home "$java_bundle_dir" 2>/dev/null || true)
    if [ -z "$java_home" ]; then
      [ -f "$JAVA_ARCHIVE" ] || { echo "ERROR: $JAVA_ARCHIVE not found." >&2; exit 1; }
      mkdir -p "$java_bundle_dir"
      unzip -q -o "$JAVA_ARCHIVE" -d "$java_bundle_dir"
      java_home=$(resolve_java_home "$java_bundle_dir")
    fi
    echo "  $java_home"
  fi
  # Exported here (not just resolved as a local var) because the
  # project-registration step below runs hop-conf.sh, which itself
  # needs a java on PATH to execute - without this, --install would
  # silently depend on a system java happening to already be there.
  export JAVA_HOME="$java_home"
  export PATH="$JAVA_HOME/bin:$PATH"

  echo "== edb-hop project files =="
  [ -f "$EDB_HOP_ARCHIVE" ] || { echo "ERROR: $EDB_HOP_ARCHIVE not found." >&2; exit 1; }
  # Extracted into a temp dir rather than straight into $INSTALL_DIR so
  # it never lingers there as a stray "edb-hop/" copy once its contents
  # have been placed into the actual project directory below - cleaned
  # up via the EXIT trap regardless of how this function returns.
  local staging_dir
  staging_dir=$(mktemp -d)
  trap 'rm -rf "$staging_dir"' EXIT
  tar xzf "$EDB_HOP_ARCHIVE" -C "$staging_dir"

  local project_dir="$hop_home/config/projects/$PROJECT_NAME"
  mkdir -p "$project_dir"

  # Never silently clobber connection info a previous --config already
  # set, on a re-install that's really an upgrade of the pipeline code.
  # --force opts out of this and resets everything to the template.
  local preserve=(config.yaml metadata/rdbms/ASIS.json metadata/rdbms/TOBE.json)
  local backup_dir=""
  if [ "$force" -eq 0 ]; then
    backup_dir=$(mktemp -d)
    for p in "${preserve[@]}"; do
      if [ -f "$project_dir/$p" ]; then
        mkdir -p "$backup_dir/$(dirname "$p")"
        cp "$project_dir/$p" "$backup_dir/$p"
      fi
    done
  fi

  cp -r "$staging_dir/edb-hop/." "$project_dir/"

  if [ -n "$backup_dir" ]; then
    for p in "${preserve[@]}"; do
      if [ -f "$backup_dir/$p" ]; then
        cp "$backup_dir/$p" "$project_dir/$p"
        echo "  kept existing $p (already configured - use --force to reset)"
      fi
    done
    rm -rf "$backup_dir"
  fi
  rm -rf "$staging_dir"
  trap - EXIT
  echo "  deployed to $project_dir"

  echo "== Registering project '$PROJECT_NAME' =="
  (
    cd "$hop_home"
    if ./hop-conf.sh -pl 2>/dev/null | grep -q "^  $PROJECT_NAME :"; then
      echo "  already registered"
    else
      ./hop-conf.sh -p "$PROJECT_NAME" -pc -ph "config/projects/$PROJECT_NAME" -pkf
    fi
  )

  echo ""
  echo "Install complete."
  echo "Next: ./edb-hop.sh --config ...   (set up ASIS/TOBE connection info)"
  echo "Then: ./edb-hop.sh --run"
}

# ------------------------------------------------------------------
# --install --docker
# ------------------------------------------------------------------

cmd_install_docker() {
  local base_image="" project_name="$PROJECT_NAME"
  local webapp_root="/usr/local/tomcat/webapps/ROOT"
  local hop_home_in_image="/usr/local/tomcat"
  local out="$INSTALL_DIR/Dockerfile"

  while [ $# -gt 0 ]; do
    case "$1" in
      --docker) shift ;;
      --base-image) base_image="$2"; shift 2 ;;
      --project-name) project_name="$2"; shift 2 ;;
      --webapp-root) webapp_root="$2"; shift 2 ;;
      --hop-home) hop_home_in_image="$2"; shift 2 ;;
      --out) out="$2"; shift 2 ;;
      -h|--help)
        cat <<'EOF'
Usage: edb-hop.sh --install --docker --base-image IMAGE [options]

Generates a Dockerfile that bakes the edb-hop project into a Hop
web-app (Tomcat) base image. Only ever writes the file and prints the
docker build/run commands as guidance - this never invokes docker, and
never builds or runs anything itself.

  --base-image IMAGE   (required) the hop-webapp base image to build
                        FROM, e.g. your org's internal tag.
  --project-name NAME   Project name inside the image. Default: edb-hop
  --webapp-root PATH    Tomcat webapp root inside the base image.
                        Default: /usr/local/tomcat/webapps/ROOT
  --hop-home PATH       Where hop-conf.sh lives inside the base image,
                        used only to attempt project registration at
                        build time. Default: /usr/local/tomcat
  --out PATH            Where to write the Dockerfile. Default: ./Dockerfile

The generated Dockerfile ships the shipped placeholder config.yaml /
ASIS.json / TOBE.json as-is (same as a fresh --install with no
--config run yet) - it does not know about any local --config you've
already done. Configure the running container afterward (docker exec,
or mount a volume over its config directory), or edit the Dockerfile
to COPY an already-configured project directory instead of extracting
the raw archive, if you'd rather ship it pre-configured.

--webapp-root and --hop-home are assumptions based on a standard
Tomcat layout - verify them against your actual base image before
relying on this in production.
EOF
        return 0 ;;
      *) echo "Unknown --install --docker option: $1" >&2; return 1 ;;
    esac
  done

  if [ -z "$base_image" ]; then
    echo "ERROR: --base-image is required, e.g. --base-image your-registry/hop-web:2.19.0" >&2
    return 1
  fi
  [ -f "$EDB_HOP_ARCHIVE" ] || { echo "ERROR: $EDB_HOP_ARCHIVE not found." >&2; return 1; }

  # Bake in whatever JVM flags the shipped project's active source
  # connector needs (sources/<active_source>/jvm-opts, if it ships one) -
  # same mechanism cmd_run uses, so this stays source-agnostic instead of
  # hardcoding one connector's driver quirks into every generated image.
  local peek_active_source peek_jvm_opts jvm_opts_env_block=""
  peek_active_source=$(tar -xzO -f "$EDB_HOP_ARCHIVE" edb-hop/config.yaml 2>/dev/null \
    | sed -n 's/^[[:space:]]*active_source:[[:space:]]*//p' | head -n1)
  if [ -n "$peek_active_source" ]; then
    peek_jvm_opts=$(tar -xzO -f "$EDB_HOP_ARCHIVE" "edb-hop/sources/$peek_active_source/jvm-opts" 2>/dev/null | tr '\n' ' ')
    if [ -n "$peek_jvm_opts" ]; then
      jvm_opts_env_block="
# JVM flags required by the active source connector (sources/${peek_active_source}/jvm-opts).
ENV JAVA_TOOL_OPTIONS=\"${peek_jvm_opts}\"
"
    fi
  fi

  cat > "$out" <<DOCKERFILE
# Auto-generated by edb-hop.sh --install --docker - review before use.
# webapp-root/hop-home below are assumptions based on a standard Tomcat
# layout; verify them against ${base_image} if the build fails.
FROM ${base_image}

ARG PROJECT_NAME=${project_name}
ARG WEBAPP_ROOT=${webapp_root}

# edb-hop-v1.2.tar.gz's own top-level folder is named "edb-hop/", so
# extracting it directly under .../config/projects/ lands it at
# .../config/projects/edb-hop/ as long as PROJECT_NAME stays "edb-hop".
COPY edb-hop-v1.2.tar.gz /tmp/edb-hop-v1.2.tar.gz
RUN mkdir -p "\${WEBAPP_ROOT}/config/projects" && \\
    tar xzf /tmp/edb-hop-v1.2.tar.gz -C "\${WEBAPP_ROOT}/config/projects/" && \\
    rm /tmp/edb-hop-v1.2.tar.gz

# Register the project so Hop can resolve it by name - a vanilla Hop
# install only pre-registers "default"/"samples". Assumes hop-conf.sh
# is reachable at HOP_HOME the same way it is on the standalone CLI
# client; if this base image lays things out differently, this step
# only warns instead of failing the build - register manually if so.
ARG HOP_HOME=${hop_home_in_image}
RUN cd "\${HOP_HOME}" 2>/dev/null && [ -f ./hop-conf.sh ] && \\
    ( ./hop-conf.sh -p "\${PROJECT_NAME}" -pc -ph "webapps/ROOT/config/projects/\${PROJECT_NAME}" -pkf || \\
      echo "WARNING: could not register project '\${PROJECT_NAME}' - do it manually." ) \\
    || echo "WARNING: hop-conf.sh not found at \${HOP_HOME} - register project '\${PROJECT_NAME}' manually."
${jvm_opts_env_block}
EXPOSE 8080
DOCKERFILE

  echo "Wrote $out"
  echo ""
  echo "Not run automatically - build and start it yourself:"
  echo ""
  echo "  docker build -t ${project_name}:latest -f $out $INSTALL_DIR"
  echo "  ./edb-hop.sh --run --docker --tag ${project_name}:latest"
  echo ""
  echo "The image ships with placeholder ASIS/TOBE connection info - see"
  echo "'edb-hop.sh --install --docker --help' for how to change that."
  echo ""
  if ! command -v docker >/dev/null 2>&1; then
    echo "NOTICE: docker was not found on this machine. This command itself"
    echo "  doesn't need it (it only wrote a file), but building and running"
    echo "  the commands above will - install docker wherever you do that."
  fi
}

# ------------------------------------------------------------------
# --config
# ------------------------------------------------------------------

cmd_config() {
  local hop_home project_dir config_yaml asis_json tobe_json
  hop_home=$(resolve_hop_home)
  project_dir="$hop_home/config/projects/$PROJECT_NAME"
  config_yaml="$project_dir/config.yaml"
  asis_json="$project_dir/metadata/rdbms/ASIS.json"
  tobe_json="$project_dir/metadata/rdbms/TOBE.json"
  for f in "$config_yaml" "$asis_json" "$tobe_json"; do
    [ -f "$f" ] || { echo "ERROR: $f not found - run './edb-hop.sh --install' first." >&2; exit 1; }
  done

  local asis_host="" asis_port="" asis_database="" asis_user="" asis_password="" asis_schema=""
  local tobe_host="" tobe_port="" tobe_database="" tobe_user="" tobe_password="" tobe_schema=""
  local edbldr_path="" show=0 interactive=0

  normalize_eq_args "$@"
  set -- "${NORMALIZED_ARGS[@]+"${NORMALIZED_ARGS[@]}"}"
  while [ $# -gt 0 ]; do
    case "$1" in
      --asis-host) asis_host="$2"; shift 2 ;;
      --asis-port) asis_port="$2"; shift 2 ;;
      --asis-database) asis_database="$2"; shift 2 ;;
      --asis-user) asis_user="$2"; shift 2 ;;
      --asis-password) asis_password="$2"; shift 2 ;;
      --asis-schema) asis_schema="$2"; shift 2 ;;
      --tobe-host) tobe_host="$2"; shift 2 ;;
      --tobe-port) tobe_port="$2"; shift 2 ;;
      --tobe-database) tobe_database="$2"; shift 2 ;;
      --tobe-user) tobe_user="$2"; shift 2 ;;
      --tobe-password) tobe_password="$2"; shift 2 ;;
      --tobe-schema) tobe_schema="$2"; shift 2 ;;
      --edbldr-path) edbldr_path="$2"; shift 2 ;;
      --show) show=1; shift ;;
      -i|--interactive) interactive=1; shift ;;
      -h|--help)
        cat <<'EOF'
Usage: edb-hop.sh --config [options]
       edb-hop.sh --config -i

Source connection - AS/400 / DB2 for i (writes ASIS.json + config.yaml):
  --asis-host HOST         --asis-port PORT        --asis-database NAME
  --asis-user USER         --asis-password PASS    --asis-schema LIBRARY

Target connection - EDB Postgres (writes TOBE.json + config.yaml):
  --tobe-host HOST         --tobe-port PORT        --tobe-database NAME
  --tobe-user USER         --tobe-password PASS    --tobe-schema SCHEMA

Other:
  --edbldr-path PATH       Path to the edbldr binary on this host
  --show                   Print current values (password masked) and exit
  -i, --interactive        Prompt for every field one at a time instead
                            of taking them as flags. Shows the current
                            value for each; press Enter to keep it.

Only the fields you actually set (via flags, or by typing something at
a prompt in -i mode) are changed - everything else in
config.yaml/ASIS.json/TOBE.json is left exactly as it was. Safe to call
repeatedly to change one field at a time.
EOF
        return 0 ;;
      *) echo "Unknown --config option: $1" >&2; return 1 ;;
    esac
  done

  if [ "$show" -eq 1 ]; then
    echo "== ASIS (source) =="
    grep -E '"(hostname|port|databaseName|username|password)":' "$asis_json" | sed -E 's/"password": "[^"]*"/"password": "***"/'
    echo "== TOBE (target) =="
    grep -E '"(hostname|port|databaseName|username|password)":' "$tobe_json" | sed -E 's/"password": "[^"]*"/"password": "***"/'
    echo "== config.yaml =="
    grep -E '^\s*(schema|edbldr_path):' "$config_yaml"
    return 0
  fi

  if [ "$interactive" -eq 1 ]; then
    local cur pw_status

    echo "Interactive configuration - press Enter to keep the current value."
    echo ""
    echo "-- ASIS (source: AS/400 / DB2 for i) --"
    cur=$(get_json_field "$asis_json" hostname)
    read -r -p "  Host [$cur]: " asis_host
    cur=$(get_json_field "$asis_json" port)
    read -r -p "  Port [$cur]: " asis_port
    cur=$(get_json_field "$asis_json" databaseName)
    read -r -p "  Database/RDB name [$cur]: " asis_database
    cur=$(get_json_field "$asis_json" username)
    read -r -p "  User [$cur]: " asis_user
    [ -n "$(get_json_field "$asis_json" password)" ] && pw_status="already set" || pw_status="not set"
    read -r -s -p "  Password ($pw_status, Enter to keep): " asis_password
    echo ""
    cur=$(sed -n '/# Schema\/library to migrate\./{n;s/^[[:space:]]*schema:[[:space:]]*//p}' "$config_yaml")
    read -r -p "  Schema/library to migrate [$cur]: " asis_schema

    echo ""
    echo "-- TOBE (target: EDB Postgres) --"
    cur=$(get_json_field "$tobe_json" hostname)
    read -r -p "  Host [$cur]: " tobe_host
    cur=$(get_json_field "$tobe_json" port)
    read -r -p "  Port [$cur]: " tobe_port
    cur=$(get_json_field "$tobe_json" databaseName)
    read -r -p "  Database [$cur]: " tobe_database
    cur=$(get_json_field "$tobe_json" username)
    read -r -p "  User [$cur]: " tobe_user
    [ -n "$(get_json_field "$tobe_json" password)" ] && pw_status="already set" || pw_status="not set"
    read -r -s -p "  Password ($pw_status, Enter to keep): " tobe_password
    echo ""
    cur=$(sed -n '/connection: TOBE/{n;s/^[[:space:]]*schema:[[:space:]]*//p}' "$config_yaml")
    read -r -p "  Schema [$cur]: " tobe_schema

    echo ""
    cur=$(sed -n 's/^[[:space:]]*edbldr_path:[[:space:]]*//p' "$config_yaml" | head -n1)
    read -r -p "edbldr binary path [$cur]: " edbldr_path
    echo ""
  fi

  set_json_field "$asis_json" "hostname" "$asis_host"
  set_json_field "$asis_json" "port" "$asis_port"
  set_json_field "$asis_json" "databaseName" "$asis_database"
  set_json_field "$asis_json" "username" "$asis_user"
  set_json_field "$asis_json" "password" "$asis_password"

  set_json_field "$tobe_json" "hostname" "$tobe_host"
  set_json_field "$tobe_json" "port" "$tobe_port"
  set_json_field "$tobe_json" "databaseName" "$tobe_database"
  set_json_field "$tobe_json" "username" "$tobe_user"
  set_json_field "$tobe_json" "password" "$tobe_password"

  # config.yaml has two "schema:" lines (ASIS's and TOBE's) - each is
  # addressed via the unique line right above/below it rather than by
  # guessing placeholder text, so this works whether the current value
  # is the shipped placeholder or an already-real value.
  if [ -n "$asis_schema" ]; then
    local esc
    esc=$(printf '%s' "$asis_schema" | sed -e 's/[&/\]/\\&/g')
    sed -i "/# Schema\/library to migrate\./{n;s/schema:.*/schema: ${esc}/}" "$config_yaml"
  fi
  if [ -n "$tobe_schema" ]; then
    local esc
    esc=$(printf '%s' "$tobe_schema" | sed -e 's/[&/\]/\\&/g')
    sed -i "/connection: TOBE/{n;s/schema:.*/schema: ${esc}/}" "$config_yaml"
  fi
  if [ -n "$edbldr_path" ]; then
    local esc
    esc=$(printf '%s' "$edbldr_path" | sed -e 's/[&/\]/\\&/g')
    sed -i "s|^\(\s*\)edbldr_path:.*|\1edbldr_path: ${esc}|" "$config_yaml"
  fi

  echo "Configuration updated. Check with: ./edb-hop.sh --config --show"
}

# ------------------------------------------------------------------
# --run
# ------------------------------------------------------------------

cmd_run() {
  normalize_eq_args "$@"
  set -- "${NORMALIZED_ARGS[@]+"${NORMALIZED_ARGS[@]}"}"

  local a
  for a in "$@"; do
    if [ "$a" = "--docker" ]; then
      cmd_run_docker "$@"
      return
    fi
  done

  local hop_home java_home project_dir
  hop_home=$(resolve_hop_home)
  java_home=$(resolve_java_home_for_hop "$hop_home")
  project_dir="$hop_home/config/projects/$PROJECT_NAME"
  export JAVA_HOME="$java_home"
  export PATH="$JAVA_HOME/bin:$PATH"
  # Pick up whatever JVM flags the currently active source connector needs
  # (see sources/<active_source>/jvm-opts) - e.g. the DB2-for-i connector's
  # AS/400 driver quirk. A no-op if the active connector ships no such file.
  local source_jvm_opts
  source_jvm_opts=$(read_source_jvm_opts "$project_dir")
  export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:-}${source_jvm_opts:+ $source_jvm_opts}"

  local level="Basic"
  local reset=0
  local extra_params=()

  while [ $# -gt 0 ]; do
    case "$1" in
      --level) level="$2"; shift 2 ;;
      --reset) reset=1; shift ;;
      --param) extra_params+=("$2"); shift 2 ;;
      -h|--help)
        cat <<'EOF'
Usage: edb-hop.sh --run [--level LEVEL] [--reset] [--param KEY=VALUE]...

  --level LEVEL     Hop log level: NOTHING, ERROR, MINIMAL, BASIC,
                     DETAILED, DEBUG, ROWLEVEL. Default: Basic
  --reset           Force a full re-run, ignoring the checkpoint
                     (passes RESET_STATUS=true)
  --param K=V       Extra -p parameter passed through to hop-run.sh,
                     repeatable

See 'edb-hop.sh --run --docker --help' to run a Docker-image build instead.
EOF
        return 0 ;;
      *) echo "Unknown --run option: $1" >&2; return 1 ;;
    esac
  done

  local params=()
  [ "$reset" -eq 1 ] && params+=("RESET_STATUS=true")
  params+=("${extra_params[@]+"${extra_params[@]}"}")

  local p_arg=()
  if [ "${#params[@]}" -gt 0 ]; then
    local joined
    joined=$(IFS=,; echo "${params[*]}")
    p_arg=(-p "$joined")
  fi

  cd "$hop_home"
  ./hop-run.sh --project="$PROJECT_NAME" --file=migration.hwf --level="$level" "${p_arg[@]+"${p_arg[@]}"}"
}

# ------------------------------------------------------------------
# --run --docker
# ------------------------------------------------------------------

cmd_run_docker() {
  local tag="${PROJECT_NAME}:latest"
  local port=8080
  local name="$PROJECT_NAME"

  while [ $# -gt 0 ]; do
    case "$1" in
      --docker) shift ;;
      --tag) tag="$2"; shift 2 ;;
      --port) port="$2"; shift 2 ;;
      --name) name="$2"; shift 2 ;;
      -h|--help)
        cat <<EOF
Usage: edb-hop.sh --run --docker [options]

Starts a container from an image already built via
'edb-hop.sh --install --docker' + 'docker build' (this does NOT build
the image itself - only runs it).

  --tag NAME     Image tag to run. Default: ${PROJECT_NAME}:latest
  --port PORT    Host port mapped to the container's 8080. Default: 8080
  --name NAME    Container name. Default: ${PROJECT_NAME}
EOF
        return 0 ;;
      *) echo "Unknown --run --docker option: $1" >&2; return 1 ;;
    esac
  done

  if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: docker is required to use --run --docker but was not found on this machine." >&2
    echo "  Install it first, e.g.:" >&2
    echo "    RHEL/Rocky/CentOS/Fedora : sudo dnf install -y docker" >&2
    echo "    Debian/Ubuntu            : sudo apt-get install -y docker.io" >&2
    echo "  (or see https://docs.docker.com/engine/install/ for your distro)" >&2
    return 1
  fi

  echo "Starting container '$name' from $tag on port $port..."
  docker run -d -p "${port}:8080" --name "$name" "$tag"
  echo ""
  echo "Container started. Check logs with:  docker logs -f $name"
  echo "Hop web UI:                          http://localhost:${port}/"
  echo ""
  echo "Connection info (ASIS/TOBE) is whatever was baked into the image"
  echo "at build time - configure it via the web UI or 'docker exec -it"
  echo "$name bash' if you shipped the unconfigured template."
}

# ------------------------------------------------------------------
# Dispatch
# ------------------------------------------------------------------

case "${1:-}" in
  --install) shift; cmd_install "$@" ;;
  --config)  shift; cmd_config "$@" ;;
  --run)     shift; cmd_run "$@" ;;
  -h|--help|"") usage ;;
  *) echo "Unknown command: $1" >&2; usage; exit 1 ;;
esac
