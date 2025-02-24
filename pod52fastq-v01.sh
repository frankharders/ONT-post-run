#!/bin/bash

# Get the current working directory
current_working_dir=$(pwd)

# Determine the current user
current_user=$(whoami)

# Print the current user
echo "The current user is: $current_user"

# Define the destination directory
destination_dir="GIT"

# Combine the current user and destination directory
download_dir="/home/$current_user/$destination_dir"

# Print the working directory
echo "The working directory is: $current_working_dir"

cd "$download_dir"

# URL of the GitHub releases page
REPO_URL="https://github.com/nanoporetech/dorado/releases/latest"

# Get the latest release URL
LATEST_URL=$(curl -sL -o /dev/null -w %{url_effective} "$REPO_URL")

# Extract the version number from the URL
VERSION=$(basename "$LATEST_URL" | sed 's/^v//')

# Construct the download URL for the Linux x64 file
DOWNLOAD_URL="https://cdn.oxfordnanoportal.com/software/analysis/dorado-$VERSION-linux-x64.tar.gz"

# Download the file
wget -O "dorado-$VERSION-linux-x64.tar.gz" "$DOWNLOAD_URL"

# Check if the download was successful
if [ $? -ne 0 ]; then
    echo "Failed to download the file. Please check the URL or your internet connection."
    exit 1
fi

# Define the extraction path
EXTRACT_PATH="$download_dir"

# Create the extraction directory if it doesn't exist
mkdir -p "$EXTRACT_PATH"

# Extract the downloaded file
tar -xzf "dorado-$VERSION-linux-x64.tar.gz" -C "$EXTRACT_PATH"

echo "Downloaded and extracted Dorado version $VERSION to $EXTRACT_PATH"

# Determine the directory one level higher than the Dorado execution file
MODEL_DIR="$(dirname "$EXTRACT_PATH")/GIT/dorado-$VERSION-linux-x64/models"

# Create the models directory if it doesn't exist
mkdir -p "$MODEL_DIR"

# Download the models into the models directory
$EXTRACT_PATH/dorado-$VERSION-linux-x64/bin/dorado download --models-directory "$MODEL_DIR" --model all

echo "Downloaded and extracted Dorado version $VERSION to $EXTRACT_PATH"
echo "Downloaded models to $MODEL_DIR"

# Return to actual working directory for processing the nanopore output files 
cd "$current_working_dir"

# Create directories
mkdir -p 1_dorado_pod52bam
mkdir -p 2_dorado_bam2fastq
mkdir -p 3_porechop_abi
mkdir -p 4_reads_trimmed

# Programs
DORADO="$EXTRACT_PATH/dorado-$VERSION-linux-x64/bin/dorado"
MODEL="$MODEL_DIR/dna_r10.4.1_e8.2_400bps_hac@v5.0.0"

# File to check
FILE="SampleSheet.csv"

# Check if file exists
if [ ! -f "$FILE" ]; then
    echo "File $FILE not found!"
    exit 1
fi

# Directory to gzip
DIR="2_dorado_bam2fastq"

# Check if directory exists
if [ ! -d "$DIR" ]; then
    echo "Directory $DIR not found!"
    exit 1
fi

# Check if the pod5 directory exists
if [ ! -d "pod5" ]; then
    echo "Directory pod5 not found!"
    exit 1
fi

# CSV data
csv_data=$(cat "$FILE")

# Extract the value of the "kit" field
kit_value=$(echo "$csv_data" | awk -F, 'NR==2 {print $4}' | cut -d'-' -f3,4)

# Print the extracted value
echo "The value of the 'kit' field is: $kit_value"

# Get the list of files into a variable
file_list=$(ls pod5/*.pod5)
files=($file_list)
countF=${#files[@]}

echo "Total files to process: $countF"

# Process files
for ((count0=0; count0<countF; count0++)); do
    line=${files[$count0]}
    file=$(basename "$line")
    name="${file%.*}"

    # Run the Dorado basecaller
    $DORADO basecaller --kit-name "$kit_value" --no-trim "$MODEL" "$line" > "1_dorado_pod52bam/${name}.bam"
    
    # Check if the Dorado command was successful
    if [ $? -ne 0 ]; then
        echo "Error processing file $line"
        exit 1
    fi

    echo "Processed file: $line"
    echo "Output name: $name"
done

echo "All pod5 files processed successfully, demultiplexing will start."

# Demultiplex
$DORADO demux -r 1_dorado_pod52bam/ -o 2_dorado_bam2fastq/ --kit-name EXP-PBC096 --emit-fastq

# Directory to gzip
DIR="2_dorado_bam2fastq"

# Check if directory exists
if [ ! -d "$DIR" ]; then
    echo "Directory $DIR not found!"
    exit 1
fi

# Get the list of files to be processed
FILES=("$DIR"/*.fastq)
total_files=${#FILES[@]}
processed_files=0

echo "Total files to process: $total_files"

# Process each file
for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        gzip "$file"
        processed_files=$((processed_files + 1))
        remaining_files=$((total_files - processed_files))
        echo "Processed $processed_files files. $remaining_files files remaining."
    fi
done

echo "All files processed."

# Activate the environment for downstream analysis
eval "$(conda shell.bash hook)"
conda activate porechop_abi

DIR_1="2_dorado_bam2fastq"
OUT_1="3_porechop_abi"

# Get the list of files to be processed
FILES_1=("$DIR_1"/*.gz)
total_files=${#FILES_1[@]}
processed_files=0

echo "Total files to process: $total_files"

# Process each file
for file in "${FILES_1[@]}"; do
    if [ -f "$file" ]; then
        echo "$file"
        stripped_name=$(basename "$file" | cut -d'_' -f3 | cut -f1 -d'.')
        echo "$stripped_name"

        sample_name=$(awk -F, -v search="$stripped_name" 'NR > 1 && $7 == search {print $8; exit}' "$FILE")
        echo "$sample_name"

        porechop_abi -i "$file" -o "$OUT_1/$sample_name.porechop.fastq.gz" --format fastq.gz --discard_middle -abi
        
        processed_files=$((processed_files + 1))
        remaining_files=$((total_files - processed_files))
        echo "Processed $processed_files files. $remaining_files files remaining."
    fi
done

exit 0
