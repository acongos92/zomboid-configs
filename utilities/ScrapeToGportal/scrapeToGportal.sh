#!/bin/bash

# Step 1: Input Handling
API_KEY="$1"
COLLECTION_IDS_STR="$2" # String of collection IDs, space-separated
EXCLUSIONS_STR="$3" # String of exclusions, space-separated
FTP_HOST_AND_PORT="$4"
FTP_USERNAME="$5"
FTP_PASSWORD="$6"
SERVER_NAME="$7"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PZ_MOD_SCRAPER_SCRIPT=$SCRIPT_DIR/../vendor/PZModScraper/getcollection.py
CONFIG_FILE=$SCRIPT_DIR/config.yaml
IFS=' ' read -r -a COLLECTION_IDS <<< "$COLLECTION_IDS_STR"
IFS=' ' read -r -a EXCLUSIONS <<< "$EXCLUSIONS_STR"
#unparsed mod data
MOD_DATA=""
#full parsed workshop items string
WORKSHOP_ITEMS=""
#full parsed mods string
MODS=""

# Step 2: Mod Scraping
# Generate or modify YAML config for PZModScraper
generate_yaml_config() {
    # Convert arrays to comma-separated strings with each element quoted
    quoted_collection_ids=$(printf "\"%s\"," "${COLLECTION_IDS[@]}")
    quoted_exclusions=$(printf "\"%s\"," "${EXCLUSIONS[@]}")

    # Trim the trailing comma
    quoted_collection_ids=${quoted_collection_ids%,}
    quoted_exclusions=${quoted_exclusions%,}

    # Writing to the config file
    echo "writing config file"
    echo "default:" > $CONFIG_FILE
    echo "  apikey: \"$API_KEY\"" >> $CONFIG_FILE
    echo "  collections: [$quoted_collection_ids]" >> $CONFIG_FILE
    echo "  exclusions: [$quoted_exclusions]" >> $CONFIG_FILE
}

# Run PZModScraper with the generated YAML config
run_mod_scraper() {
    # Assuming PZModScraper is a command-line tool
    MOD_DATA=$(python3 "$PZ_MOD_SCRAPER_SCRIPT" --configpath "$CONFIG_FILE" default)
}

# Step 3: Parsing Scraped Data
parse_mod_data() {
    # Parse the output from PZModScraper
    # Assume output is stored in a file or variable
    echo "parse_mod_data"
    WORKSHOP_ITEMS=$(sed -n "2p" <<< "$MOD_DATA")
    WORKSHOP_ITEMS=WorkshopItems="$WORKSHOP_ITEMS"
    MODS=$(sed -n "4p" <<< "$MOD_DATA")
    MODS=Mods="$MODS"
}

# Step 4: Updating Server Configuration
update_server_config() {
    # FTP commands to retrieve servername.ini
    # Update WorkshopItems and Mods
    fullFile=$SCRIPT_DIR/$SERVER_NAME.ini
    echo "update_server_config"
    ftp -invp $FTP_HOST_AND_PORT << EOF
    user $FTP_USERNAME $FTP_PASSWORD
    get Server/$SERVER_NAME.ini $fullFile
    bye
EOF
    sed -i "s/WorkshopItems=.*/$WORKSHOP_ITEMS/g" $fullFile
    sed -i "s/Mods=.*/$MODS/g" $fullFile
}

# Step 5: Uploading Updated Configuration
upload_config() {
    FTP_COMMANDS=$1
    ftp -inv $FTP_HOST_AND_PORT << EOF
    user $FTP_USERNAME $FTP_PASSWORD
    $FTP_COMMANDS
    quit
EOF
}

# Script Execution Flow
generate_yaml_config
run_mod_scraper
parse_mod_data
update_server_config

