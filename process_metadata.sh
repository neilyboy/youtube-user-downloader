#!/bin/bash

# This script processes the .info.json file generated by yt-dlp
# and creates a formatted .txt file with specific metadata fields.
# It's designed to be called by yt-dlp's --exec option.

METADATA_OUTPUT_DIR="$1" # First argument: Directory to save the .txt file
VIDEO_FILEPATH="$2"     # Second argument: Full path to the downloaded video file

LOG_DIR="$(dirname "$METADATA_OUTPUT_DIR")/logs" # Infer log dir relative to metadata dir
LOG_FILE="${LOG_DIR}/downloader.log"

# --- Logging Function ---
log_message() {
    local type="$1"
    local message="$2"
    # Check if log file exists and is writable, otherwise echo
    if [[ -w "$LOG_FILE" ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') [$type] [Metadata] $message" >> "$LOG_FILE"
    else
         echo "$(date '+%Y-%m-%d %H:%M:%S') [$type] [Metadata] $message"
    fi
}

# --- Input Validation ---
if [ -z "$METADATA_OUTPUT_DIR" ] || [ -z "$VIDEO_FILEPATH" ]; then
    log_message "ERROR" "Insufficient arguments provided to process_metadata.sh. Needs METADATA_DIR and VIDEO_FILEPATH."
    exit 1
fi

if [ ! -d "$METADATA_OUTPUT_DIR" ]; then
    log_message "ERROR" "Metadata output directory '$METADATA_OUTPUT_DIR' does not exist."
    exit 1
fi

if [ ! -f "$VIDEO_FILEPATH" ]; then
    # This might happen if yt-dlp failed after creating the file but before exec
    log_message "WARNING" "Video file '$VIDEO_FILEPATH' not found. Skipping metadata processing."
    exit 0 # Exit gracefully, maybe the download failed partially
fi

# --- Derive File Paths ---
VIDEO_BASENAME=$(basename "$VIDEO_FILEPATH")
VIDEO_NAME_NO_EXT="${VIDEO_BASENAME%.*}" # Remove the extension

# The .info.json file is expected to be next to the video file
INFO_JSON_PATH="${VIDEO_FILEPATH%.*}.info.json"

# Target .txt file path in the specified metadata directory
TXT_OUTPUT_PATH="${METADATA_OUTPUT_DIR}/${VIDEO_NAME_NO_EXT}.txt"

# --- Check if JSON File Exists ---
if [ ! -f "$INFO_JSON_PATH" ]; then
    log_message "ERROR" "Metadata JSON file not found: $INFO_JSON_PATH"
    exit 1
fi

# --- Extract and Format Metadata using jq ---
log_message "INFO" "Processing metadata for: $VIDEO_BASENAME"

# Use jq to extract fields. Handle nulls gracefully with // "N/A" or similar.
# Note: 'formats' is complex. Extracting details of the *selected* format(s) is more useful.
# yt-dlp often puts the selected format details directly in the top-level fields
# (like resolution, format_id, vcodec, acodec) after download/merge.
# http_headers can be very large, consider omitting or summarizing if needed.
jq -r \
    --arg video_filename "$VIDEO_BASENAME" \
    '
    "Video Filename: \($video_filename)",
    "---",
    "ID: \(.id // "N/A")",
    "Title: \(.title // "N/A")",
    "Channel: \(.channel // "N/A") (\(.channel_id // "N/A"))",
    "Uploader: \(.uploader // "N/A") (\(.uploader_id // "N/A"))",
    "Upload Date: \(.upload_date // "N/A")", # Format YYYYMMDD
    "Duration: \(.duration_string // (.duration | if . then tostring else "N/A" end))", # Prefer string, fallback to seconds
    "Resolution: \(.resolution // ((.width | tostring) + "x" + (.height | tostring)) // "N/A")",
    "FPS: \(.fps // "N/A")",
    "Video Codec: \(.vcodec // "N/A")",
    "Audio Codec: \(.acodec // "N/A")",
    "Video Bitrate (approx): \(.vbr // "N/A") kbps", # Often approximate
    "Audio Bitrate (approx): \(.abr // "N/A") kbps", # Often approximate
    "Format Note: \(.format_note // "N/A")", # e.g., 1080p, 720p
    "Format ID used: \(.format_id // "N/A")", # e.g., "137+140"
    "Video Extension: \(.video_ext // .ext // "N/A")", # Use specific video_ext if available
    "Audio Extension: \(.audio_ext // "N/A")",
    "Aspect Ratio: \(.aspect_ratio // "N/A")",
    "Description:",
    "---",
    (.description // "N/A"),
    "---"
    # Uncomment below if you absolutely need full format details (can be very long)
    # "All Available Formats:",
    # "---",
    # (.formats | map("Resolution: \(.resolution // "audio only"), Codecs: \(.vcodec // "none")+\(.acodec // "none"), Ext: \(.ext), Note: \(.format_note // ""), URL: \(.url)") | join("\n")),
    # "---"
    # Uncomment below if you need HTTP Headers (VERY VERBOSE)
    # "HTTP Headers (used for download):",
    # "---",
    # (.http_headers // "N/A" | tojson),
    # "---"
    ' \
    "$INFO_JSON_PATH" > "$TXT_OUTPUT_PATH"

status=$?
if [ $status -ne 0 ]; then
    log_message "ERROR" "jq failed (exit code $status) while processing: $INFO_JSON_PATH"
    # Optionally remove the potentially incomplete .txt file
    # rm -f "$TXT_OUTPUT_PATH"
    exit 1
else
    log_message "INFO" "Successfully created metadata file: $TXT_OUTPUT_PATH"
    # Optional: Remove the .info.json file after successful processing to save space
    # log_message "INFO" "Removing JSON file: $INFO_JSON_PATH"
    # rm -f "$INFO_JSON_PATH"
fi

exit 0
