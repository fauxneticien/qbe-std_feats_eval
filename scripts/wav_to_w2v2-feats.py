import argparse
import glob
import os
import pickle
import numpy as np
import pandas as pd
from pathlib import Path
from tqdm import tqdm

import fairseq
import torch
import torchaudio

parser = argparse.ArgumentParser(
    description='example: python wav_to_w2v2-feats.py data/raw/model_checkpoints/20210127_LV60-0FT.pt wrm-pd',
    formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )

parser.add_argument('model_pt', help='path to wav2vec 2.0 model checkpoint')
parser.add_argument('dataset', help = 'name of dataset, use _all_ to iterate over all')

parser.add_argument('--stage', default = 'encoder', help = 'name of wav2vec 2.0 output stage: encoder, quantizer, transformer, or _all_')
parser.add_argument('--layer', default = '1', help = 'if stage is transformer, which layer of transformer, or _all_')

parser.add_argument('--feats_dir',  default='data/interim/features', help = "directory for features")
parser.add_argument('--datasets_dir', default='data/raw/datasets', help = "directory for raw datasets and labels files")

parser.add_argument('--queries_dir',  default='queries', help = "directory with .wav files for queries")
parser.add_argument('--references_dir',  default='references', help = "directory with .wav files for references")

args = parser.parse_args()

model, cfg, task = fairseq.checkpoint_utils.load_model_ensemble_and_task([args.model_pt])
model = model[0]
model = model.eval()

if torch.cuda.device_count() > 0:
    model.cuda()

def extract_w2v2_feats(wav_data, stage, layer = None, model = model):

    if torch.cuda.device_count() > 0:
        wav_data = wav_data.cuda()

    if stage == "encoder":

        x = model.feature_extractor(wav_data)
        x = x.transpose(1, 2)

    elif stage == "quantizer":

        x, _ = model.quantize(wav_data)

    else:

        x = model.feature_extractor(wav_data)
        x = x.transpose(1, 2)
        x = model.layer_norm(x)
        x = model.post_extract_proj(x)

        # Transformer encoder
        x_conv = model.encoder.pos_conv(x.transpose(1, 2))
        x_conv = x_conv.transpose(1, 2)
        x += x_conv

        if not model.encoder.layer_norm_first:
            x = model.encoder.layer_norm(x)
            
        x = x.transpose(0, 1)

        for i, t_layer in enumerate(model.encoder.layers):
            x, z = t_layer(x, self_attn_padding_mask=None, need_weights=False)
            if i == layer - 1:
                break

        x = x.transpose(0, 1)
    
    return x.squeeze(0).detach().cpu().numpy()

def load_audio(wav_path):
    wav_dat, wav_sr = torchaudio.load(wav_path)
    # Resample to 16 kHz for wav2vec 2.0, and covert to mono if necessary
    wav_dat = torchaudio.transforms.Resample(wav_sr, 16000)(wav_dat).mean(0, True)

    return wav_dat

def dir_to_w2v2_feats_pkl(stage, layer, input_dir, output_pickle):

    assert os.path.isdir(input_dir)

    input_files = glob.glob(os.path.join(input_dir, "*.wav"))
    input_wavs  = [ load_audio(f) for f in input_files ]

    fnames_list = [ os.path.splitext(os.path.basename(f))[0] for f in input_files ] # '.../filename.wav' => 'filename',
    feats_list  = [ extract_w2v2_feats(w, stage, layer) for w in tqdm(input_wavs) ]

    feats_df = pd.DataFrame({
        "filename" : fnames_list,
        "features" : feats_list
    })

    with open(output_pickle, 'wb') as handle:
        pickle.dump(feats_df, handle)

    print("Features written to {}".format(output_pickle))

datasets = [ os.path.basename(p) for p in glob.glob(os.path.join(args.datasets_dir, "*")) ] if args.dataset == '_all_' else [ args.dataset ]

model_name = os.path.splitext(os.path.basename(args.model_pt))[0]

assert args.stage in ["encoder", "quantizer", "transformer", "_all_"], "Unknown wav2vec 2.0 stage specified: {}".format(args.stage)
stages = [ "encoder", "quantizer", "transformer" ] if args.stage == "_all_" else [ args.stage ]

if "transformer" in stages:
    layers = list(range(1, len(model.encoder.layers) + 1)) if args.layer == "_all_" else [ int(args.layer) ]

for dataset in datasets:

    for stage in stages:

        queries_wav_dir  = os.path.join(args.datasets_dir, dataset, args.queries_dir)
        refs_wav_dir    = os.path.join(args.datasets_dir, dataset, args.references_dir)

        if stage in ["encoder", "quantizer"]:

            feature = "{}_{}".format(model_name, stage) # LV60-0FT_encoder or # LV60-0FT_quantizer
            ds_feat_output_dir = os.path.join(args.feats_dir, dataset, feature)
            Path(ds_feat_output_dir).mkdir(parents=True, exist_ok=True)

            queries_pkl_path = os.path.join(ds_feat_output_dir, "queries.pickle")
            refs_pkl_path   = os.path.join(ds_feat_output_dir, "references.pickle")

            dir_to_w2v2_feats_pkl(stage, None, queries_wav_dir, queries_pkl_path)
            dir_to_w2v2_feats_pkl(stage, None, refs_wav_dir, refs_pkl_path)

        if stage == "transformer":

            for layer in layers:
                assert layer > 0 or layer <= len(model.encoder.layers), "Specified transformer layer out of range"

                feature = "{}_{}-L{}".format(model_name, stage, str(layer).zfill(2)) # e.g. LV60-0FT_transformer-L01
                ds_feat_output_dir = os.path.join(args.feats_dir, dataset, feature)
                Path(ds_feat_output_dir).mkdir(parents=True, exist_ok=True)

                queries_pkl_path = os.path.join(ds_feat_output_dir, "queries.pickle")
                refs_pkl_path   = os.path.join(ds_feat_output_dir, "references.pickle")

                dir_to_w2v2_feats_pkl(stage, layer, queries_wav_dir, queries_pkl_path)
                dir_to_w2v2_feats_pkl(stage, layer, refs_wav_dir, refs_pkl_path)
