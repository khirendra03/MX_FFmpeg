#!/bin/bash

# A script to automate the download, configuration, and build of a new FFmpeg version for the MX Player project.
# Ensures a consistent and repeatable upgrade process.

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration ---
FFMPEG_BASE_URL="https://ffmpeg.org/releases"
JNI_DIR="ffmpeg/JNI"
# The build system expects the source code at this specific path
FFMPEG_JNI_SOURCE_DIR="${JNI_DIR}/ffmpeg"

# --- Helper Functions ---
log() {
    echo "[INFO] $1"
}

error() {
    echo "[ERROR] $1" >&2
    exit 1
}

# --- Main Script Logic ---

# 1. Validate Input
if [ -z "$1" ]; then
    error "No FFmpeg version specified. Usage: ./upgrade_ffmpeg.sh <version> (e.g., 7.2)"
fi

NEW_VERSION=$1
TARBALL="ffmpeg-${NEW_VERSION}.tar.bz2"
SOURCE_DIR="ffmpeg-${NEW_VERSION}"
DOWNLOAD_URL="${FFMPEG_BASE_URL}/${TARBALL}"

# 2. Download the new FFmpeg version
log "Downloading FFmpeg version ${NEW_VERSION} from ${DOWNLOAD_URL}..."
if [ -f "$TARBALL" ]; then
    log "Tarball ${TARBALL} already exists. Skipping download."
else
    wget -q --show-progress "${DOWNLOAD_URL}" || error "Failed to download ${TARBALL}. Please check the version number and your connection."
fi

# 3. Clean up old source directory
log "Cleaning up old FFmpeg source code..."
if [ -d "${SOURCE_DIR}" ]; then
    log "Removing existing directory ${SOURCE_DIR}."
    rm -rf "${SOURCE_DIR}"
fi

# The JNI build script looks for a directory named "ffmpeg". 
# We will remove the old one (which might be a symlink or a directory).
if [ -L "${FFMPEG_JNI_SOURCE_DIR}" ] || [ -d "${FFMPEG_JNI_SOURCE_DIR}" ]; then
    log "Removing old source directory at ${FFMPEG_JNI_SOURCE_DIR}."
    rm -rf "${FFMPEG_JNI_SOURCE_DIR}"
fi

# 4. Extract the new version
log "Extracting ${TARBALL}..."
tar -xjf "${TARBALL}" || error "Failed to extract ${TARBALL}."
log "Extraction complete. Source is in ./${SOURCE_DIR}/"

# 5. Link the new source code to the JNI directory
log "Linking new source directory to ${FFMPEG_JNI_SOURCE_DIR}..."
ln -s "$(pwd)/${SOURCE_DIR}" "${FFMPEG_JNI_SOURCE_DIR}" || error "Failed to create symbolic link."
log "Symbolic link created successfully."

# 6. Run the build script
log "Starting the FFmpeg build process. This may take a long time."
log "Build output will be logged to ${JNI_DIR}/rebuild-ffmpeg.log"

cd "${JNI_DIR}"
# Pass any additional arguments (like --debug) to the rebuild script
./rebuild-ffmpeg.sh all "${@:2}"
BUILD_STATUS=$?
cd - > /dev/null

if [ ${BUILD_STATUS} -ne 0 ]; then
    error "FFmpeg build failed. Please check the log file: ${JNI_DIR}/rebuild-ffmpeg.log"
fi

log "----------------------------------------------------------------"
log "FFmpeg upgrade and build process completed successfully!"
log "Version ${NEW_VERSION} is now built and ready."
log "----------------------------------------------------------------"

