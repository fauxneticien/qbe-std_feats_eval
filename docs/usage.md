# Replication/usage instructions

In this document, we walk through running our analyses on the Gronings dataset (gos-kdl), which has been released on Zenodo ([https://zenodo.org/record/4634878](https://zenodo.org/record/4634878)).
The datasets expected by our scripts have the following form:

```
gos-kdl/
|-- labels.csv
|-- queries/
|--|-- ED_aapmoal.wav
|--|-- ED_achter.wav
...
|-- references/
|--|-- OV-aapmoal-verschillend-mor-aapmoal-prachteg-van-kleur.wav
|--|-- HS-en-achterin-stonden-nog-wat-riegen-weckpotten-op-plaank
...
```

For every pairing of a .wav file in `queries/` with a .waf file in `references/`, the `labels.csv` file contains the ground truth of whether the given query occurs in the reference. We expect the wav files to be 16 kHz mono 16-bit WAV PCM.

| query |        reference      | label |
|-------|-----------------------|-------|
| ED_aapmoal | OV-aapmoal-verschillend-mor-<b>aapmoal</b>-prachteg-van-kleur |   1   |
| ED_aapmoal | HS-en-achterin-stonden-nog-wat-riegen-weckpotten-op-plaank        |   0   |
|  ED_achter  | OV-aapmoal-verschillend-mor-aapmoal-prachteg-van-kleur |   0   |
|  ED_achter  | HS-en-<b>achter</b>in-stonden-nog-wat-riegen-weckpotten-op-plaank        |   1   |

## System requirements

The instructions here are working as of 2021-03-24, tested on a virtual instance with 24 CPU cores and 64 GB of RAM running Ubuntu 20.04 LTS, Docker Engine 20.10.5, and Docker Compose 1.28.4.

### Docker installation script

The script was used to install docker and docker-compose on a fresh instance of Ubuntu 20.04 LTS, based on [DigitalOcean instructions](https://www.digitalocean.com/community/tutorials/how-to-install-and-use-docker-on-ubuntu-20-04).

```bash
sudo apt update && \
sudo apt-get -y install apt-transport-https ca-certificates curl software-properties-common && \
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add - && \
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable" && \
sudo apt update && \
apt-cache policy docker-ce && \
sudo apt-get -y install docker-ce && \
sudo curl -L "https://github.com/docker/compose/releases/download/1.28.4/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose && \
sudo chmod +x /usr/local/bin/docker-compose
```

## 1. Setup

### 1.1 Clone qbe-std_feats_eval repository

```bash
git clone https://github.com/fauxneticien/qbe-std_feats_eval.git
cd qbe-std_feats_eval
```

### 1.2 Set up `gos-kdl` dataset locally

```bash
# Download gos-kdl.zip into qbe-std_feats_eval/tmp directory
wget https://zenodo.org/record/4634878/files/gos-kdl.zip -P tmp/

## Install unzip if necessary
# apt-get install unzip

# Create directory data/raw/datasets/gos-kdl
mkdir -p data/raw/datasets/gos-kdl

# Unzip into directory
unzip tmp/gos-kdl.zip -d data/raw/datasets/gos-kdl
``` 

### 1.3 Fetch model checkpoint(s)

The exact model checkpoint files used in our pilot and main experiments have been placed on Zenodo ([https://zenodo.org/record/4632537](https://zenodo.org/record/4632537)).

```bash
# Fetch the Librispeech 960 checkpoint
wget https://zenodo.org/record/4632537/files/20210225-Large-0FT.pt \
   -P data/raw/model_checkpoints/
   
# Fetch the XLSR-53 checkpoint (optional)
wget https://zenodo.org/record/4632537/files/20210127-XLSR53.pt \
   -P data/raw/model_checkpoints/
```

#### 1.4 Pull docker image(s)

```bash
# For extracting wav2vec 2.0 features and running evaluation scripts
docker pull fauxneticien/qbe-std_feats_eval

# For extracting MFCC and BNF features (optional)
docker pull fauxneticien/shennong
```

## 2. Feature extraction

All extraction routines create a `queries.pickle` and `references.pickle`, which are Pandas data frames with two columns. As illustrated below, the first column is the name of the .wav file from which features were extracted using some feature extraction routine (e.g. MFCC) and the second column is a NumPy array of the features for that wav file created by the routine.
By default, these files are placed in `data/interim/features/{DATASET}/{FEATURE}/`, for example, `data/interim/features/gos-kdl/mfcc/queries.pickle`.


| filename | features |
|----------|----------|
|   ED_aapmoal    | [[16.485865, -11.592721, -14.900574, 20.032818...
|   ED_achter  | [[11.749482, -9.294043, -6.118123, -7.8093295,...

### 2.1 MFCC and BNF features

We couldn't get the Shennong dependencies to play nice with the ones needed for the wav2vec 2.0 image, so if you want to extract MFCC and BNF features (as we did for our baselines), you'll have to do it in the `fauxneticien/shennong` image.

```bash
# Start docker container according to 'shennong' config
# specified in the docker-compose.yml file
docker-compose run --rm shennong

# Activate conda environment inside the container 
conda activate shennong

# Extract MFCC and BNF features using wav_to_shennong-feats.py
#
# For help, run: python scripts/wav_to_shennong-feats.py -h

python scripts/wav_to_shennong-feats.py \
    _all_ \
    gos-kdl

# Exit the shennong container
exit
```

### 2.2 wav2vec 2.0 features

```bash
# Start docker container according to 'dev' config
# specified in the docker-compose.yml file
docker-compose run --rm dev

# Extract features from all stages/layers (encoder, quantizer, transformer 1-24)
# of wav2vec 2.0 model using model weights from specified checkpoint file.
#
# For help, run: python scripts/wav_to_shennong-feats.py -h

python scripts/wav_to_w2v2-feats.py \
    data/raw/model_checkpoints/20210225-Large-0FT.pt \
    gos-kdl \
    --stage _all_ \
    --layer _all_
```

### 2.3 Fetch features from Zenodo (optional)

Extracted features from all 10 datasets have been uploaded to Zenodo (see [https://zenodo.org/record/4635493](https://zenodo.org/record/4635493) and [https://zenodo.org/record/4635438](https://zenodo.org/record/4635438)). Features for any of the datasets can be downloaded and extracted using (for example):

```bash
# Get link from 'Download' button on https://zenodo.org/record/4635438
wget https://zenodo.org/record/4635438/files/wbp-jk.zip -P tmp/

# Make data/interim/features directory if necessary
# mkdir -p data/interim/features

unzip tmp/wbp-jk.zip -d data/interim/features
```

## 3. DTW search

Using features based on a given feature extraction method, we add a corresponding prediction for how likely the query occurs in the reference using an iterative Dynamic Time Warping search, where a window the size of the query is moved along the length of the reference and a DTW-based distance is calculated at each iteration. The final score is `1 - min(dists)`, and is appended to the labels table (example from `data/processed/dtw/mfcc_gos-kdl.csv`)

| query |        reference      | label | prediction |
|-------|-----------------------|-------|------------|
| ED_aapmoal | OV-aapmoal-verschillend-mor-aapmoal-prachteg-van-kleur |   1   |    0.908723813004581    |
| ED_aapmoal | HS-en-achterin-stonden-nog-wat-riegen-weckpotten-op-plaank        |   0   |    0.8474109272820750    |
|  ED_achter  | OV-aapmoal-verschillend-mor-aapmoal-prachteg-van-kleur |   0   |    0.8848427561266850    |
|  ED_achter  | HS-en-achterin-stonden-nog-wat-riegen-weckpotten-op-plaank        |   1   |    0.855101419144621     |

```
# If you're not already inside the 'dev' container:
# docker-compose run --rm dev

# Run DTW search for each feature extraction method on gos-kdl
#
# For help, run scripts/feats_to_dtw.py -h

python scripts/feats_to_dtw.py \
    _all_ \
    gos-kdl
```

### 3.1 Fetch DTW search results from Zenodo (optional)

Our system prediction results have been uploaded to Zenodo (see [https://zenodo.org/record/4635587](https://zenodo.org/record/4635587)). To download results use (for example):

```bash
# Get link from 'Download' button on 
wget https://zenodo.org/record/4635587/files/main_dtw.zip -P tmp/

# Make data/processed directory if necessary
# mkdir -p data/processed

unzip tmp/main_dtw.zip -d data/processed
```

## 4. Evaluation

We use the Maximum Term Weighted Value (MTWV) as the evaluation metric and use the NIST STDEval tool (included in the repository) to calculate it.
Briefly stated, with the default costs (false positive: 1, false negative: 10), a MTWV of 0.48 indicates a system that correctly detects 48% of all queries searched, while producing at most 10 false positives for each true positive correctly retrieved [22]. A perfect system detecting all relevant instances with no false positives scores a MTWV of 1 while a system that simply returns nothing scores a MTWV of 0.

### 4.1 STDEval requirements

We include a helper script `scripts/prep_STDEval.R` to produce the relevant files needed by the STDEval tool, and provide a brief summary of the purpose of each file.
For a full description of the NIST STD evaluation, see the [2006 Spoken Term Detection Evaluation Plan](https://catalog.ldc.upenn.edu/docs/LDC2011S02/std06-evalplan-v10.pdf).

#### 4.1.1 Experiment Control File (*.ecf.xml)

This file describes the reference audio, listing their total duration (e.g. `source_signal_duration="1354.55"`) and the duration of each audio file in the reference.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<ecf source_signal_duration="1354.55" version="20130512-1800">
<excerpt audio_filename="GD-aaltied-wuir-hai-ofblaft-omdat-e-zo-swaart-was.wav" channel="1" tbeg="0.000" dur="4.36" language="multiple" source_type="gos-kdl" />
<excerpt audio_filename="GD-aan-de-kaande-stonden-de-pabbe-en-moeke-van-t-jonkje.wav" channel="1" tbeg="0.000" dur="3.63" language="multiple" source_type="gos-kdl" />
<!-- ... //-->
<!-- ... //-->
</ecf>
```

#### 4.1.2 Term List file (*.tlist.xml)

This file refers to the ECF file (e.g. `ecf_filename="gos-kdl.ecf.xml"`) and contains the filenames of the queries to be searched in the reference corpus.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<termlist ecf_filename="gos-kdl.ecf.xml" language="multiple" version="20130512-1500">
<term termid="ED_aapmoal"><termtext>ED_aapmoal</termtext></term>
<term termid="ED_achter"><termtext>ED_achter</termtext></term>
<!-- ... //-->
<!-- ... //-->
</termlist>
```

#### 4.1.3 Rich Transcription Time Mark file (*.rttm)

This file, like our `labels.csv` file, contains the ground truth of which queries occur in which references. See Appendix D of the 2006 STD Evaluation Plan for the meaning of each space separated column.

```
SPEAKER GD-aaltied-wuir-hai-ofblaft-omdat-e-zo-swaart-was 1 0.000 4.360 <NA> <NA> SELF <NA>
LEXEME GD-aaltied-wuir-hai-ofblaft-omdat-e-zo-swaart-was 1 0.000 4.360 GD_aaltied lex SELF <NA>
LEXEME GD-aaltied-wuir-hai-ofblaft-omdat-e-zo-swaart-was 1 0.000 4.360 GD_swaart lex SELF <NA>
```

#### 4.1.4 Spoken Term Detection List file (*.stdlist.xml)

This file contains the search results of the STD system (i.e. predictions returned by the DTW search). For our purposes, we populate only the `score` attribute with the prediction, and use the ground-truth labels for the hard yes/no decision as a placeholder. The yes/no decisions can be used if you want to find out the *Actual* Term Weighted Value (ATWV), which is the actual performance achieved by your system when you threshold your scores (e.g. YES = Score > 0.85). By contrast the MTWV is the maximum value achievable by your system at the optimal threshold (which it will find for you).

```xml
<?xml version="1.0" encoding="UTF-8"?>
<stdlist termlist_filename="gos-kdl.tlist.xml" indexing_time="0.0" language="multiple" index_size="0" system_id="example">
	<detected_termlist termid="ED_aapmoal" term_search_time="0.0" oov_term_count="0">
		<term file="GD-aaltied-wuir-hai-ofblaft-omdat-e-zo-swaart-was" channel="1" tbeg="0" dur="4.36" score="0.872283175517642" decision="NO"/>
		<term file="GD-aan-de-kaande-stonden-de-pabbe-en-moeke-van-t-jonkje" channel="1" tbeg="0" dur="3.63" score="0.849960824470862" decision="NO"/>
	</detected_termlist>
	<!-- ... //-->
	<detected_termlist termid="ED_achter" term_search_time="0.0" oov_term_count="0">
		<term file="GD-aaltied-wuir-hai-ofblaft-omdat-e-zo-swaart-was" channel="1" tbeg="0" dur="4.36" score="0.850603789705973" decision="NO"/>
		<term file="GD-aan-de-kaande-stonden-de-pabbe-en-moeke-van-t-jonkje" channel="1" tbeg="0" dur="3.63" score="0.862153172783973" decision="NO"/>
	</detected_termlist>
</stdlist>	
```

### 4.2 Prepare files for STDEval tool

The `scripts/prep_STDEval.R` script takes the datasets directory (need the `labels.csv` files for to make the `tlist.xml` files and the folder of reference audio to get their durations and names for the `ecf.xml` and `rttm` files), the dtw output directory (prediction CSV files needed to make the `stdlist.xml` files), and an output directory to place the generated files. It will also copy `STDEval-0.7` and `gather_mtwv.R` from the scripts directory into the new directory for convenience.

```
Rscript scripts/prep_STDEval.R \
    data/raw/datasets \
    data/processed/dtw \
    data/processed/STDEval
```

### 4.3 Using the STDEval tool

The `stdeval_commands.txt` file contains all the commands needed to run the STDEval tool for each feature for each dataset, with some default parameters we have chosen (see `STDEval-0.7/doc/STDEval.html` for explanations):

```bash
# Example with line breaks for clarity. In the 'stdeval_commands.txt' file,
# each command (one per dataset per feature extraction method) appears as a single line
#
# perl -I STDEval-0.7/src \
#    STDEval-0.7/src/STDEval.pl \
#    -s gos-kdl/mfcc/*.stdlist.xml \
#    -number-trials-per-sec=1 \
#    -e gos-kdl/*.ecf.xml \
#    -r gos-kdl/*.rttm \
#    -t gos-kdl/*.tlist.xml
#    -A \
#    -o gos-kdl/mfcc/score.mtwv.txt \
#    -d gos-kdl/mfcc/score.det \
#    -S 2.0 \
#    -F 0.5 \
#    -p 0.0279 \
#    -k 1 \
#    -K 10 >& gos-kdl/mfcc/score.log
```

#### 4.3.1 Run all commands in `stdeval_commands.txt` in parallel

```
# Change directory in order to have STDEval-0.7 folder in the working directory
cd data/processed/STDEval

# Switch to Perl 5.18.4 (STDEval does not like the default Ubuntu 20.04 Perl version, 5.26)
perlbrew switch perl-5.18.4

# Run all commands in `stdeval_commands.txt` in parallel
parallel --verbose --progress < stdeval_commands.txt

# Collect MTWVs from all score.mtwv.txt files
Rscript gather_mtwv.R

# Some housekeeping, if needed
#
# exit     # To exit perl-5.18
# exit     # To exit the docker container 
```

#### 4.3.2 View MTWV results in `all_mtwv.csv`

The `gather_mtwv.R` script produces the following CSV file, which lists for each dataset and feature extraction method the MTWV, the probability of false alarms and the probability of misses of the system, and the decision score (threshold) that yields the MTWV.

| dataset |        features      | mtwv | p_fa | p_miss | desc_score |
|-------|-----------------------|-------|------------|----|----|
| gos-kdl | bnf | 0.3695 | 0.04305 | 0.48 | 0.93797675 |
| gos-kdl | mfcc |   0.3695 | 0.04305 | 0.48 | 0.93797675 |
| gos-kdl | 20210225-Large-0FT_encoder | 0.4467 | 0.07503 | 0.292 | 0.87028207 |
| ... | ... | ... | ... | ... | ... |
| gos-kdl | 20210225-Large-0FT_transformer-L24 | 0.2452 | 0.06833 | 0.517 | 0.9389963 |


### 4.4 Fetch STDEval results from Zenodo (optional)

All input files used in and output returned by the STDEval tool for our main and pilot experiments have been uploaded to Zenodo (see [https://zenodo.org/record/4635587](https://zenodo.org/record/4635587)). To download the data use (for example):

```bash
# Get link from 'Download' button on 
wget https://zenodo.org/record/4635587/files/main_STDEval.zip -P tmp/

# Make data/processed directory if necessary
# mkdir -p data/processed

unzip tmp/main_STDEval.zip -d data/processed
```

# 5. Analyses

For our analyses based on the results derived using the procedure described here, see the documents in the [analyses](https://github.com/fauxneticien/qbe-std_feats_eval/tree/master/analyses) folder. The `main-all_mtwv.csv` and `xlsr-all_mtwv.csv` in the `analyses/data` folder are those found in the respective `STDEval` folders available on Zenodo.
