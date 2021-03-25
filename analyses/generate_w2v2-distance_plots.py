import os
import fairseq
import torch
import torchaudio
import matplotlib.pyplot as plt
from scipy.spatial.distance import cdist

# Assuming you're running this script from the repo root
# e.g. python analyses/scripts/generate_w2v2-distance_plots.py
query_wav_path = "analyses/data/hello.wav"
ref_wav_path   = "analyses/data/goodbye-hello-goodbye.wav"

q_dat, q_sr = torchaudio.load(query_wav_path)
r_dat, r_sr = torchaudio.load(ref_wav_path)

# Resample to 16 kHz
q_dat = torchaudio.transforms.Resample(q_sr, 16000)(q_dat)
r_dat = torchaudio.transforms.Resample(r_sr, 16000)(r_dat)

# Also assuming the model checkpoints are in the expected locations:
mono_model_pt = "data/raw/model_checkpoints/20210225-Large-0FT.pt"
xlsr_model_pt = "data/raw/model_checkpoints/20210127-XLSR53.pt"

mono_model, cfg, task = fairseq.checkpoint_utils.load_model_ensemble_and_task([mono_model_pt])
mono_model = mono_model[0]
mono_model = mono_model.eval()

xlsr_model, cfg, task = fairseq.checkpoint_utils.load_model_ensemble_and_task([xlsr_model_pt])
xlsr_model = xlsr_model[0]
xlsr_model = xlsr_model.eval()

def extract_w2v2_feats(wav_data, layer = None, model = mono_model):

    x = model.feature_extractor(wav_data)
    x = x.transpose(1, 2)
    x = model.layer_norm(x)
    x = model.post_extract_proj(x)

    # Transformer encoder
    x_conv = model.encoder.pos_conv(x.transpose(1, 2))
    x_conv = x_conv.transpose(1, 2)
    x += x_conv

    x = model.encoder.layer_norm(x)
    x = x.transpose(0, 1)

    for i, t_layer in enumerate(model.encoder.layers):
        x, z = t_layer(x, self_attn_padding_mask=None, need_weights=False)
        if i == layer - 1:
            break

    x = x.transpose(0, 1)

    return x.squeeze(0).detach().cpu().numpy()

def save_dist_fig(q_feats, r_feats, model_name, layer_name):

    qr_dists_w2v2 = cdist(q_feats, r_feats, 'euclidean', V = None)                                      # Calculate distance matrix
    qr_dists_w2v2 = ((qr_dists_w2v2 - qr_dists_w2v2.min())/(qr_dists_w2v2.max() - qr_dists_w2v2.min())) # Normalized to [0, 1]

    output_path = os.path.join('analyses', 'xlsr-pilot_files', model_name + '-T' + str(layer_name) + '.png')

    plt.figure(figsize=(8,2))
    plt.imshow(qr_dists_w2v2, interpolation='none')
    plt.savefig(output_path)

for layer_i in [1, 5, 10, 15, 20, 24]:
    
    for model in ['mono', 'xlsr']:
        
        q_feats = extract_w2v2_feats(q_dat, layer_i, mono_model if model == 'mono' else xlsr_model)
        r_feats = extract_w2v2_feats(r_dat, layer_i, mono_model if model == 'mono' else xlsr_model)
        save_dist_fig(q_feats, r_feats, model, layer_i)
