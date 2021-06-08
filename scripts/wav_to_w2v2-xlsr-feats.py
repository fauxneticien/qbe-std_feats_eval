import os
import pickle
import torch
import soundfile as sf
import numpy as np
import pandas as pd

from argparse import ArgumentParser
from glob import glob
from transformers import logging
from transformers.models.wav2vec2 import Wav2Vec2Model
from pathlib import Path
from tqdm import tqdm

KNOWN_MODELS = {
    # Pre-trained
    'wav2vec2-base': 'facebook/wav2vec2-base',
    'wav2vec2-large': 'facebook/wav2vec2-large',
    'wav2vec2-large-lv60': 'facebook/wav2vec2-large-lv60',
    'wav2vec2-large-xlsr-53': 'facebook/wav2vec2-large-xlsr-53',
    # Fine-tuned
    'wav2vec2-base-960h': 'facebook/wav2vec2-base-960h',
    'wav2vec2-large-960h': 'facebook/wav2vec2-large-960h',
    'wav2vec2-large-960h-lv60': 'facebook/wav2vec2-large-960h-lv60',
    'wav2vec2-large-960h-lv60-self': 'facebook/wav2vec2-large-960h-lv60-self',
    'wav2vec2-large-xlsr-53-english': 'jonatasgrosman/wav2vec2-large-xlsr-53-english'
}

parser = ArgumentParser(
    prog='Wav2Vec2 Featurizer',
    description='Runs full featurization of wav files for downstream usage.',
)

parser.add_argument('--dataset', help = 'name of dataset, use _all_ to iterate over all')
parser.add_argument('--stage', default = 'transformer', help = 'name of wav2vec 2.0 output stage: encoder, quantizer, transformer, or _all_')
parser.add_argument('--layer', default = '1', help = 'if stage is transformer, which layer of transformer, or _all_')

parser.add_argument('--feats_dir',  default='data/interim/features', help = 'directory for features')
parser.add_argument('--datasets_dir', default='data/raw/datasets', help = 'directory for raw datasets and labels files')

parser.add_argument('--queries_dir',  default='queries', help = 'directory with .wav files for queries')
parser.add_argument('--references_dir',  default='references', help = 'directory with .wav files for references')

parser.add_argument('--model', default='wav2vec2-large-xlsr-53')
parser.add_argument('--hft_logging', default=40, help='HuggingFace Transformers verbosity level (40 = errors, 30 = warnings, 20 = info, 10 = debug)')

args = parser.parse_args()

logging.set_verbosity(args.hft_logging)

def load_wav2vec2_featurizer(model, layer=None):
    """
    Loads Wav2Vec2 featurization pipeline and returns it as a function.
    Featurizer returns a list with all hidden layer representations if "layer" argument is None.
    Otherwise, only returns the specified layer representations.
    """

    model_name_or_path = KNOWN_MODELS.get(model, model)
    model_kwargs = {}
    if layer is not None:
        model_kwargs["num_hidden_layers"] = layer if layer > 0 else 0
    model = Wav2Vec2Model.from_pretrained(model_name_or_path, **model_kwargs)
    model.eval()
    if torch.cuda.is_available():
        model.cuda()

    @torch.no_grad()
    def _featurize(path):
        input_values, rate = sf.read(path, dtype=np.float32)
        assert rate == 16_000
        input_values = torch.from_numpy(input_values).unsqueeze(0)
        if torch.cuda.is_available():
            input_values = input_values.cuda()

        if layer is None:
            hidden_states = model(input_values, output_hidden_states=True).hidden_states
            hidden_states = [s.squeeze(0).cpu().numpy() for s in hidden_states]
            return hidden_states

        if layer >= 0:
            hidden_state = model(input_values).last_hidden_state.squeeze(0).cpu().numpy()
        else:
            hidden_state = model.feature_extractor(input_values)
            hidden_state = hidden_state.transpose(1, 2)
            if layer == -1:
                hidden_state = model.feature_projection(hidden_state)
            hidden_state = hidden_state.squeeze(0).cpu().numpy()

        return hidden_state

    return _featurize

def featurize(wav_paths, layer, stage, dataset):
    '''
    Computes w2v2 from the queries and references files
    '''

    featurizer = load_wav2vec2_featurizer(args.model, layer=layer)
    
    fnames_list = []
    feats_list = []
    
    # Create features for each wav file
    for wav_path in tqdm(wav_paths, ncols=80):
        proc_set = wav_path.split('/')[-2]

        # Extract features
        hidden_states = featurizer(wav_path)
        fnames_list.append(wav_path.split('/')[-1][:-4])
        # print(hidden_states.shape)
        feats_list.append(hidden_states)

    feats_df = pd.DataFrame({
        'filename' : fnames_list,
        'features' : feats_list
    })

    if layer < 0:
        # e.g. wav2vec2-large-xlsr-53_encoder or # wav2vec2-large-xlsr-53_quantizer
        stage_name = "{}_{}".format(args.model, stage)
    else:
        # e.g. wav2vec2-large-xlsr-53_transformer-L01
        stage_name = "{}_{}-L{}".format(args.model, stage, str(layer).zfill(2))

    ds_feat_output_dir = os.path.join(args.feats_dir, dataset, stage_name)
    Path(ds_feat_output_dir).mkdir(parents=True, exist_ok=True)
    
    with open(ds_feat_output_dir + '/' + proc_set + '.pickle', 'wb') as handle:
        pickle.dump(feats_df, handle)

def main():
    datasets = [ os.path.basename(p) for p in glob.glob(os.path.join(args.datasets_dir, '*')) ] if args.dataset == '_all_' else [ args.dataset ]

    assert args.stage in ['encoder', 'quantizer', 'transformer', '_all_'], 'Unknown wav2vec 2.0 stage specified: {}'.format(args.stage)
    stages = [ 'encoder', 'quantizer', 'transformer' ] if args.stage == '_all_' else [ args.stage ]

    for dataset in datasets:

        for stage in stages:
            
            # Check wav files in input directory
            queries_wav_paths = glob(os.path.join(args.datasets_dir, dataset, args.queries_dir) + '/*.wav')
            assert len(queries_wav_paths) > 0, f'No wav files found in {args.input_dir}'

            refs_wav_paths = glob(os.path.join(args.datasets_dir, dataset, args.references_dir) + '/*.wav')
            assert len(refs_wav_paths) > 0, f'No wav files found in {args.input_dir}'

            if stage == 'encoder':
                layers = [-2]

            if stage == 'quantizer':
                layers = [-1]
            
            if stage == 'transformer':
                if args.layer == '_all_':
                    layers = list(range(1, 25))
                else:
                    assert int(args.layer) > 0 or int(args.layer) <= 24, f'Specified transformer layer {args.layer} out of range'
                    layers = [ int(args.layer) ]

            for layer in layers:
                featurize(queries_wav_paths, layer, stage, dataset)
                featurize(refs_wav_paths, layer, stage, dataset)             

if __name__ == '__main__':
    main()                  
