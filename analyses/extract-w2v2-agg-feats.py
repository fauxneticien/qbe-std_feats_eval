import os
import torch
import soundfile as sf
import pandas as pd
import numpy as np
from tqdm import tqdm

from argparse import ArgumentParser

from transformers import logging
from transformers.models.wav2vec2 import Wav2Vec2Model

logging.set_verbosity(40)

parser = ArgumentParser(
    prog='Wav2Vec2 Featurizer',
    description='Extract features aggregated across intervals specified in input csv file',
)

parser.add_argument('--model', default='wav2vec2-large-xlsr-53')
parser.add_argument('--intervals_csv', help = 'CSV file of intervals')
parser.add_argument('--features_csv', help = 'Name of output CSV file')

args = parser.parse_args()

KNOWN_MODELS = {
    # Pre-trained
    'wav2vec2-base': 'facebook/wav2vec2-base',
    'wav2vec2-large': {'name' : 'facebook/wav2vec2-large', 'revision' : '85c73b1a7c1ee154fd7b06634ca7f42321db94db' },
    # March 11, 2021 version: https://huggingface.co/facebook/wav2vec2-large/commit/85c73b1a7c1ee154fd7b06634ca7f42321db94db
    'wav2vec2-large-lv60': 'facebook/wav2vec2-large-lv60',
    'wav2vec2-large-xlsr-53': {'name' : 'facebook/wav2vec2-large-xlsr-53', 'revision' : '8e86806e53a4df405405f5c854682c785ae271da' },
    # May 6, 2021 version: https://huggingface.co/facebook/wav2vec2-large-xlsr-53/commit/8e86806e53a4df405405f5c854682c785ae271da
    
    # Fine-tuned
    'wav2vec2-base-960h': 'facebook/wav2vec2-base-960h',
    'wav2vec2-large-960h': 'facebook/wav2vec2-large-960h',
    'wav2vec2-large-960h-lv60': 'facebook/wav2vec2-large-960h-lv60',
    'wav2vec2-large-960h-lv60-self': 'facebook/wav2vec2-large-960h-lv60-self',
    'wav2vec2-large-xlsr-53-english': 'jonatasgrosman/wav2vec2-large-xlsr-53-english',
    'wav2vec2-large-xlsr-53-tamil': 'manandey/wav2vec2-large-xlsr-tamil'
}

def load_wav2vec2_featurizer(model, layer=None):
    """
    Loads Wav2Vec2 featurization pipeline and returns it as a function.
    Featurizer returns a list with all hidden layer representations if "layer" argument is None.
    Otherwise, only returns the specified layer representations.
    """

    model_spec = KNOWN_MODELS.get(model, model)
    model_kwargs = {}
    if layer is not None:
        model_kwargs["num_hidden_layers"] = layer if layer > 0 else 0

    if type(model_spec) is dict:
        model_name_or_path       = model_spec['name']
        model_kwargs['revision'] = model_spec['revision']
    else:
        model_name_or_path = model_spec
    
    model = Wav2Vec2Model.from_pretrained(model_name_or_path, **model_kwargs)

    num_gpus = torch.cuda.device_count()

    if num_gpus > 1:
        model = torch.nn.DataParallel(model)

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
            hidden_state = model.feature_extractor(input_values) if num_gpus <= 1 else model.module.feature_extractor(input_values)
            hidden_state = hidden_state.transpose(1, 2)
            if layer == -1:
                hidden_state = model.feature_projection(hidden_state) if num_gpus <= 1 else model.module.feature_projection(hidden_state)
            hidden_state = hidden_state.squeeze(0).cpu().numpy()

        return hidden_state

    return _featurize

featurizer = load_wav2vec2_featurizer(args.model, layer=11)

segs_df    = pd.read_csv(args.intervals_csv)

feat_names = ["file", "text"] + [ "d" + str(n + 1).zfill(4) for n in range(1024) ]
feats_df   = pd.DataFrame(columns = feat_names)

for i in tqdm(range(segs_df.shape[0])):
    soi = segs_df.iloc[i]

    T11_feats  = featurizer(soi.file)
    
    soi_start = round((soi.xmin) * 50)
    soi_end   = round((soi.xmax) * 50)

    new_row   = [ soi.file, soi.text ] + list(np.mean(T11_feats[soi_start:soi_end,:], axis=0))
    new_row   = dict(zip(feat_names, new_row))
    
    feats_df = feats_df.append(new_row, ignore_index=True, sort=False)

feats_df.to_csv(args.features_csv, index = False)
