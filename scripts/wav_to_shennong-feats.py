import argparse
import glob
import os
import pickle
import numpy as np
import pandas as pd

from shennong.audio import Audio
from shennong.features.processor.mfcc import MfccProcessor
from shennong.features.postprocessor.delta import DeltaPostProcessor
from shennong.features.processor.bottleneck import BottleneckProcessor

mfcc_processor  = MfccProcessor(sample_rate=8000)
delta_processor = DeltaPostProcessor(order=2)
bnf_processor   = BottleneckProcessor(weights='BabelMulti')

parser = argparse.ArgumentParser(
    description='example: python wav_to_shennong-feats.py mfcc wrm-pd',
    formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )

parser.add_argument('features', help='features to extract using the Shennong library (mfcc or bnf), use _all_ for both')
parser.add_argument('dataset', help = 'name of dataset, use _all_ to iterate over all')

parser.add_argument('--feats_dir',  default='data/interim/features', help = "directory for features")
parser.add_argument('--datasets_dir', default='data/raw/datasets', help = "directory for raw datasets and labels files")

parser.add_argument('--queries_dir',  default='queries', help = "directory with .wav files for queries")
parser.add_argument('--references_dir',  default='references', help = "directory with .wav files for references")

args = parser.parse_args()

def wavs_to_feats_df(wavs_list, feats):

    assert feats in ['mfcc', 'bnf'], "Unknown feature parameter for wavs_to_feats_df function: {}".format(feats)

    feats_list = []

    for wav_file in wavs_list:

        wav_data = Audio.load(wav_file).resample(8000)

        assert wav_data.sample_rate == 8000, "Error. Could not resample file to 8000 Hz for MFCC/BNF feature extraction."
        assert wav_data.nchannels == 1, "Unexpected non-mono file supplied: {}".format(filename)

        if feats == 'mfcc':
            mfcc_data = mfcc_processor.process(wav_data)
            mfcc_data = delta_processor.process(mfcc_data)
            feats_list.append(mfcc_data.data)

        elif feats == 'bnf':
            bnf_data = bnf_processor.process(wav_data)
            feats_list.append(bnf_data.data)        

    feats_df = pd.DataFrame({
        "filename" : [ os.path.splitext(os.path.basename(f))[0] for f in wavs_list ], # '.../filename.wav' => 'filename',
        "features" : feats_list
    })

    return feats_df

def dir_to_feats_pkl(feats, input_dir, output_pickle):

    assert os.path.isdir(input_dir)

    input_wavs = glob.glob(os.path.join(input_dir, "*.wav"))

    feats_df = wavs_to_feats_df(input_wavs, feats)

    with open(output_pickle, 'wb') as handle:
        pickle.dump(feats_df, handle)

    print("Features written to {}".format(output_pickle))

features = ['mfcc', 'bnf'] if args.features == '_all_' else [ args.features ]
datasets = [ os.path.basename(p) for p in glob.glob(os.path.join(args.datasets_dir, "*")) ] if args.dataset == '_all_' else [ args.dataset ]

for feature in features:

    feat_output_dir = os.path.join(args.feats_dir, feature)

    if not os.path.isdir(feat_output_dir):
        os.makedirs(feat_output_dir)

    for dataset in datasets:

        ds_feat_output_dir = os.path.join(feat_output_dir, dataset)

        if not os.path.isdir(ds_feat_output_dir):
            os.makedirs(ds_feat_output_dir)

        queries_wav_dir  = os.path.join(args.datasets_dir, dataset, args.queries_dir)
        queries_pkl_path = os.path.join(ds_feat_output_dir, "queries.pickle")

        refs_wav_dir    = os.path.join(args.datasets_dir, dataset, args.references_dir)
        refs_pkl_path   = os.path.join(ds_feat_output_dir, "references.pickle")

        if feature == 'mfcc':
            dir_to_feats_pkl("mfcc", queries_wav_dir, queries_pkl_path)
            dir_to_feats_pkl("mfcc", refs_wav_dir, refs_pkl_path)

        elif feature == 'bnf':
            dir_to_feats_pkl("bnf", queries_wav_dir, queries_pkl_path)
            dir_to_feats_pkl("bnf", refs_wav_dir, refs_pkl_path)
