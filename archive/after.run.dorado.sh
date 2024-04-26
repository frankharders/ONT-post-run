#!/bin/bash

## all programs installed or downloaded in /data/GIT/ directory for processing
## only suitable for running on GridION

##### settings basecaller
## no quality trim
## no trim of adapter
## quality of the run and selection of the correct model
## model version is derived from user input
## barcode kit used is derived from user input
## output is bam
## multiple pod5 files to 1 bam file
## syntax bam file [sampleName].[barcodeXX].bam

##### settings demux
## barcode kit used is derived from user input
## threads used = 16
## no trim of adapter
## output is fastq
## directory will be deleted after processing the files to trimmed files by porechop

##### porechop settings
## output will be fastq.gz
## adapters and barcodes will be trimmed
## middle adapters will be trimmed
## data will be ready for downstream processing
## threads used = 16



##  general info
##  on later timepoint model and barcode kit can be derived from txt or json files but for now we use this


## last edit
## 30-01-2024, frank


echo -e "input ONT model";
echo -e "v4.2.0 or v4.3.0";

QUALITYTEMP="USER INPUT";

read -p "

Enter 1 for standard quality
Enter 2 for best quality: " QUALITYTEMP && [[ "$QUALITYTEMP" == [1,2] ]] || exit 1

MODELTEMP="USER INPUT2";

read -p "

Enter 1 for model v4.2.0
Enter 2 for model v4.3.0: " MODELTEMP && [[ "$MODELTEMP" == [1,2] ]] || exit 1

KITTEMP="USER INPUT3";

read -p "

Enter 1 for PCR barcoding
Enter 2 for Native barcoding
Enter 3 for Rapid barcoding: " KITTEMP && [[ "$KITTEMP" == [1,2,3] ]] || exit 1



echo -e "quality selected is $QUALITY";
echo -e "selected model is $MODELTEMP";
echo -e "selected barcoding kit is $KITTEMP";

## Quality of sequence run is set here

if [ "$QUALITYTEMP" == 1 ];then

QUALITY='hac';

else

QUALITY='sup';

fi


## The correct model for analyzing the pod output files is selected here

if [ "$MODELTEMP" == 1 ];then

MODEL='v4.2.0';

else

MODEL='v4.3.0';

fi

## The correct barcoding kit is selected 

if [ "$KITTEMP" == 1 ];then

KITNAME='EXP-PBC096';

elif [ "$KITTEMP" == 2 ];then

KITNAME='SQK-NBD114-96';

elif [ "$KITTEMP" == 3 ];then

KITNAME='SQK-RBK114-96';

else 

	echo "wrong kit is selected";


fi



# select and download model to use for post run polishing
model="$QUALITY"\@"$MODEL";

GITdir='/data/GIT/';
dorado="$GITdir"/'dorado-0.5.3-linux-x64/bin/dorado';
porechop="$GITdir"/Porechop/porechop-runner.py;
NODES=16;


FILE=samples.txt;

if [ -f "$FILE" ];then

# construct directories for output
mkdir -p 00_run_metadata; # contains meta data from the run
mkdir -p 01a_bc_reads; # contains single file data per sample, raw data 
mkdir -p 01b_qc_reads; # contains QC plots from raw data
mkdir -p temp_demuxed; # temp folder containing single file demuxed sample data, not important can easy be repeated, fast!
mkdir -p 02a_trim_reads; # contains single file data per sample, is porechopped for adapter and barcode sequence
mkdir -p 02b_qc_reads_trim; # contains QC plots from porechopped data

# variables used
BCreads=01a_bc_reads;
DEMUXED=temp_demuxed;
TRIM=02a_trim_reads;
TRIMQC=02b_qc_reads_trim;
FLOWCELL=$(cat barcode_alignment_* | cut -f8 | sed 1d | sort -u);


# run QC plots outside of the "run metrics html file"
NanoPlot --summary sequencing_summary*.txt -o 00_run_metadata/run_summary;

# ONT summary file is constructed during the run is to big so it's gzipped
gzip sequencing_summary*;
mv sequencing_summary*.gz 00_run_metadata;


## start loop for all samples

count0=1;
countP=$(cat "$FILE" | wc -l);

while [ $count0 -le $countP ];do

LINE=$(cat "$FILE" | awk 'NR=='$count0);

## split the csv file lines 
bc=$(echo "$LINE" | cut -f1 -d',');
name=$(echo "$LINE" | cut -f2 -d','); 


READSIN=pod5_pass/"$bc"/;
READSout="$BCreads"/"$name"."$bc"."$FLOWCELL".fastq.gz;

kit="$KITNAME"_;

echo -e "Sample $name";


## basecall data from original pod5_pass directory per sample(barcode)
	"$dorado" basecaller -v --no-trim --emit-fastq --kit-name "$KITNAME" "$model" "$READSIN"  | gzip > "$READSout";

## qc of the raw data
	NanoPlot -t 2 --fastq "$BCreads"/"$name"."$bc"."$FLOWCELL".fastq.gz --plots dot -o 01b_qc_reads/"$name"."$bc"."$FLOWCELL";

# construct a sample specific output folder
	mkdir -p "$DEMUXED"/"$name"."$bc"."$FLOWCELL";

	"$dorado" demux -v --no-trim --output-dir "$DEMUXED"/"$name"."$bc"."$FLOWCELL" --kit-name "$KITNAME" --threads "$NODES" --emit-fastq "$READSout";

## gzip output of dorado 	
	gzip "$DEMUXED"/"$name"."$bc"."$FLOWCELL"/"$kit""$bc".fastq;
	rm "$DEMUXED"/"$name"."$bc"."$FLOWCELL"/*.fastq;
	
	"$porechop" -i "$DEMUXED"/"$name"."$bc"."$FLOWCELL"/"$kit""$bc".fastq.gz --format fastq.gz -o "$TRIM"/"$name"."$bc"."$FLOWCELL"."$KITNAME".porechop.fastq.gz --discard_middle -v 1 -t "$NODES" ; 

## qc of the porechopped data
NanoPlot -t 2 --fastq "$TRIM"/"$name"."$bc"."$FLOWCELL"."$KITNAME".fastq.gz --plots dot -o "$TRIMQC"/"$name"."$bc"."$FLOWCELL"."$KITNAME";



count0=$((count0+1));
done


else

echo "create a 2 column samples.txt file with syntax barcodeXX,samplename";

fi


rm -rf "$DEMUXED";




exit 1






