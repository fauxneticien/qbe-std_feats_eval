# Evaluation of feature extraction methods for query-by-example spoken term detection with low resource languages

In this project we examine different feature extraction methods ([Kaldi MFCCs](https://kaldi-asr.org/doc/feat.html), [BUT/Phonexia Bottleneck features](https://speech.fit.vutbr.cz/software/but-phonexia-bottleneck-feature-extractor), and variants of [wav2vec 2.0](https://github.com/pytorch/fairseq/tree/master/examples/wav2vec)) for performing QbE-STD with data from language documentation projects. A walkthrough of the entire experiment pipeline can be found in `scripts/README.md`.

## Citation

```bibtex
@misc{san2021leveraging,
      title={Leveraging neural representations for facilitating access to untranscribed speech from endangered languages}, 
      author={San, Nay and Bartelds, Martijn and Browne, Mitchell and Clifford, Lily and Gibson, Fiona and Mansfield, John and Nash, David and Simpson, Jane and Turpin, Myfany and Vollmer, Maria and Wilmoth, Sasha and Jurafsky, Dan},
      year={2021},
      eprint={--update--},
      archivePrefix={arXiv},
      primaryClass={cs.CL}
}
```

## Directory structure

The directory structure for this project roughly follows the [Cookiecutter Data Science guidelines](https://drivendata.github.io/cookiecutter-data-science/#directory-structure).

```
├── README.md                    <- This top-level README
├── docker-compose.yml           <- Configurations for launching Docker containers
├── qbe-std_feats_eval.Rproj     <- RStudio project file, used to get repository path using R's 'here' package
├── requirements.txt             <- Python package requirements
├── tmp/                         <- Empty directory to download zip files into, if required
├── data/
│   ├── raw/                     <- Immutable data, not modified by scripts
│   │   ├── datasets/            <- Audio data and ground truth labels placed here
│   │   ├── model_checkpoints/   <- wav2vec 2.0 model checkpoint files placed here
│   ├── interim/                         
│   │   ├── features/            <- features generated by extraction scripts (automatically generated)
│   ├── processed/      
│   │   ├── dtw/                 <- results returned by DTW search (automatically generated)
│   │   ├── STDEval/             <- evaluation of DTW searches (automatically generated)
├── scripts/
│   ├── README.md                <- walkthrough for entire experiment pipeline
│   ├── wav_to_shennong-feats.py <- Extraction script for MFCC and BNF features using the Shennong library
│   ├── wav_to_w2v2-feats.py     <- Extraction script for wav2vec 2.0 features
│   ├── feats_to_dtw.py          <- QbE-STD DTW search using extracted features
│   ├── prep_STDEval.R           <- Helper script to generate files needed for STD evaluation
│   ├── gather_mtwv.R            <- Script to gather Maximum Term Weighted Values generated by STDEval
│   ├── STDEval-0.7/             <- NIST STDEval tool
├── analyses/
│   │   ├── data/                <- Final, post-processed data used in analyses
│   │   ├── xlsr-pilot.md        <- Pilot study with the 'XLSR' multilingual wav2vec 2.0 model
│   │   ├── mtwv.md              <- MTWV figures and statistics reported in paper
│   │   ├── error-analysis.md    <- Error analyses reported in paper
```

## Experiment data and artefacts

With the exception of raw audio and texts from the Australian language documentation projects (for which we do not have permission to release openly) and those from the [Mavir corpus](http://www.lllf.uam.es/ING/CorpusMavir.html) (which can be obtained from the original distributor, subject to signing their licence agreement), all other data used in and generated by the experiments are available on Zenodo (see [https://zenodo.org/communities/qbe-std_feats_eval](https://zenodo.org/communities/qbe-std_feats_eval)). These are:

- Dataset: Gronings [https://zenodo.org/record/4634878](https://zenodo.org/record/4634878)
- Model checkpoints: [https://zenodo.org/record/4632537](https://zenodo.org/record/4632537)
- Experiment artefacts:
	- Main experiments, MFCC, BNF and wav2vec 2.0 LibriSpeech 960h features (limited to 50 GB per archive by Zenodo):
		- Archive I (eng-mav, gbb-lg, wbp-jk, and wrl-mb datasets): [https://zenodo.org/record/4635438](https://zenodo.org/record/4635438)
		- Archive II (gbb-pd, gos-kdl, gup-wat, mwf-jm, pjt-sw01, and wrm-pd): [https://zenodo.org/record/4635493](https://zenodo.org/record/4635493)
	- Pilot experiments, wav2vec 2.0 XLSR-53 features (limited to 50 GB per archive by Zenodo):
		- Archive I (eng-mav, gbb-lg, wbp-jk, and wrl-mb datasets): [https://zenodo.org/record/4635438](https://zenodo.org/record/4635438)
		- Archive II (gbb-pd, gos-kdl, gup-wat, mwf-jm, pjt-sw01, and wrm-pd): [https://zenodo.org/record/4635493](https://zenodo.org/record/4635493)
	- All experiments, DTW search and evaluation data: [https://zenodo.org/record/4635587](https://zenodo.org/record/4635587)
