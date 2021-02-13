# Evaluation of feature extraction methods for query-by-example spoken term detection with low resource languages

In this project we examine different feature extraction methods ([Kaldi MFCCs](https://kaldi-asr.org/doc/feat.html), [BUT/Phonexia Bottleneck features](https://speech.fit.vutbr.cz/software/but-phonexia-bottleneck-feature-extractor), and variants of [wav2vec 2.0](https://github.com/pytorch/fairseq/tree/master/examples/wav2vec)) for performing QbE-STD with data from language documentation projects.

## Usage

The recommended way to use the code in this repository is to use the provided Docker images, [fauxneticien/shennong](https://hub.docker.com/repository/docker/fauxneticien/shennong) (for extracting MFCCs/BNFs using the Shennong feature extraction library) and [fauxneticien/qbe-std_feats_eval](https://hub.docker.com/repository/docker/fauxneticien/qbe-std_feats_eval), for the wav2vec 2.0 extraction methods, as well as the Dynamic Time Warping (DTW) comparisons and F-beta evaluation routine.

If you want to use GPUs with the [fauxneticien/qbe-std_feats_eval](https://hub.docker.com/repository/docker/fauxneticien/qbe-std_feats_eval) Docker image, make sure your CUDA version is at least 11.0 (or upgrade CUDA using instructions [here](https://developer.nvidia.com/cuda-11.0-download-archive?target_os=Linux&target_arch=x86_64&target_distro=Ubuntu&target_version=1804&target_type=deblocal)). Everything should work on a fresh Ubuntu 18.04 LTS installation with Docker >= 20.0 and CUDA >= 11.0.

### Walkthrough with sample data

#### 1. Download/clone this repository and navigate into the repo directory:

```bash
git clone https://github.com/fauxneticien/qbe-std_feats_eval.git
cd qbe-std_feats_eval
```
	
#### 2. Copy sample data from `docs/assets/sample_data` into `data/raw/datasets`:

```bash
cp -R docs/assets/sample_dataset data/raw/datasets/sample
```
	
This sample dataset consists of the following files:

```
sample/
|-- labels.csv
|-- queries
|--|-- hello.wav
|--|-- car.wav
|-- references
|--|-- goodbye-hello-goodbye.wav
|--|-- wheres-the-car.wav	
```
	
where `labels.csv` provides a label (1 = query occurs in the reference, 0 = it does not) for each combination of query and reference in the respective directories:
	
| query |        reference      | label |
|-------|-----------------------|-------|
| hello | goodbye-hello-goodbye |   1   |
| hello | wheres-the-car        |   0   |
|  car  | goodbye-hello-goodbye |   0   |
|  car  | wheres-the-car        |   1   |
	
#### 3. Extract features

The feature extraction creates `queries.pickle` and `references.pickle` files of the following form (example shown for `data/interim/features/mfcc/queries.pickle`):

| filename | features |
|----------|----------|
|   car    | [[16.485865, -11.592721, -14.900574, 20.032818...
|   hello  | [[11.749482, -9.294043, -6.118123, -7.8093295,...

Each row in the features file contains the filename of the `.wav` file from which the features were extracted and a NumPy matrix of shape (M, F) where M is the number of time frames (varies from file to file) and F the number of feature components (e.g. 39 for Kaldi MFCCs, 80 for BUT BNFs).

##### 3a. MFCCs/BNFs (`scripts/wav_to_shennong-feats.py`)

We do this inside the `shennong` conda environment inside the `fauxneticien/shennong` container. We couldn't get the dependencies to play nice with those in `fauxneticien/qbe-std_feats_eval` hence two seperate images.
	
```bash
docker-compose run --rm shennong
conda activate shennong
python scripts/wav_to_shennong-feats.py mfcc sample
exit
```
	
##### 3b. wav2vec 2.0 (to do)

#### 4. Generate DTW-based scores (`scripts/feats_to_dtw.py`)

Using features based on a given feature extraction method, we add a corresponding prediction for how likely the query occurs in the reference using an iterative Dynamic Time Warping search, where a window the size of the query is moved along the length of the reference and a DTW-based distance is calculated at each iteration. The final score is `1 - min(dists)`, and is appended to the labels table (example from `data/processed/dtw/mfcc_sample.csv`)

| query |        reference      | label | prediction |
|-------|-----------------------|-------|------------|
| hello | goodbye-hello-goodbye |   1   |    0.99    |
| hello | wheres-the-car        |   0   |    0.79    |
|  car  | goodbye-hello-goodbye |   0   |    0.86    |
|  car  | wheres-the-car        |   1   |    1.0     |

```bash
docker-compose run --rm dev
python scripts/feats_to_dtw.py mfcc sample
```

#### 4. Generate F-beta scores (`scripts/dtw_to_fbeta.py`)

By default we generate F2 scores at various thresholds and report a maximum F2 achieved at some given threshold:

```bash
# Launch Docker image if not already inside one
# docker-compose run --rm dev
python scripts/feats_to_dtw.py mfcc_sample.csv
#
#     F-beta results for data/processed/dtw/mfcc_sample.csv, with beta = 2
#        Max F-beta: 1.0
#        Precision:  1.0
#        Recall:     1.0
#        Threshold:  0.9999711785568958
#
#    Raw results saved to: data/processed/fbeta/f2_mfcc_sample.csv
```

The raw results are saved in a CSV file in `data/processed/fbeta` (e.g. for plotting precision-recall curves).