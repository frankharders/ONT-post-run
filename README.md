# ONT-post-run
dorado demux

Demux ONT data with current version of dorado (v0.6.2)

list of edit in time:

last edit:
- change folder names for backup raw and polished data
- depricate porechop start using dorado

Layout of a processed directory:

00a_run_metadata    --> contains meta data from the run
01a_bc_reads        --> contains single fastq.gz file per sample, raw data 
01b_qc_reads        --> contains QC plots from raw data
temp_demuxed        --> temp folder containing single file demuxed sample data, not important can easy be repeated, fast!
02a_trim_reads      --> contains single file data per sample, is trimmed for adapter and barcode sequence using the latest version of dorado
02b_qc_reads_trim   --> contains QC plots from trimmed data

Steps:
- read in samplesheet by command line
- collect run metadata
- construct single fastq.gz file per sample
- NanoPlot QC om raw data
- demux and artefact trimming of the data
- NanoPplot QC on trimmed data
- end

We consider this as the last step in post processing the data before we start project specific analysis

# Before starting the script
Before starting copy the ONT samplesheet into the working directory
It will process all data/samples that are within the samplesheet.

frank, 2024-04-26




