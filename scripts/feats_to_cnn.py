import argparse
import glob
import os
import pickle
import torch
import numpy as np
import pandas as pd
from pathlib import Path
from tqdm import tqdm
from torch.utils.data import Dataset, DataLoader
from scipy.spatial.distance import cdist
from CNN_Models import VGG11

parser = argparse.ArgumentParser(
    description='example: python feats_to_dtw.py 20210225-Large-0FT_transformer-L11 wrl-mb',
    formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )

parser.add_argument('cnn_cp', help='checkpoint file for CNN weights')
parser.add_argument('features', help='features to use in CNN computations, use _all_ to iterate over all')
parser.add_argument('dataset', help = 'name of dataset, use _all_ to iterate over all')

parser.add_argument('--use_gpu',  default=False, help = "flag for using GPU, True or False")
parser.add_argument('--batch_size',  default=20, help = "batch size for processing on GPU")
parser.add_argument('--num_dlw',  default=4, help = "number of data loader workers")

parser.add_argument('--feats_dir',  default='data/interim/features', help = "directory for features")
parser.add_argument('--datasets_dir', default='data/raw/datasets', help = "directory for raw datasets and labels files")
parser.add_argument('--output_dir',  default='data/processed/cnn', help = "directory for CNN output, will create if it does not exist")

parser.add_argument('--queries_file',  default='queries.pickle', help = "file with features of queries")
parser.add_argument('--references_file',  default='references.pickle', help = "file with features of references")
parser.add_argument('--labels_file',  default='labels.csv', help = "file indicating which query occurs in which reference")

args = parser.parse_args()

# Load CNN classifier
cnn_model = VGG11()
cnn_cp    = torch.load(args.cnn_cp, torch.device('cpu'))
cnn_model.load_state_dict(cnn_cp['model_state_dict'])
cnn_model.eval()

if (args.use_gpu):
    cnn_model = cnn_model.cuda()

datasets = [ os.path.basename(p) for p in glob.glob(os.path.join(args.datasets_dir, "*")) ] if args.dataset == '_all_' else [ args.dataset ]

class STD_Dataset(Dataset):
    """Extend PyTorch Dataset class to define custom Spoken Term Detection Dataset class."""
    
    def __init__(self, labels_df, queries_df, references_df, max_height = 100, max_width = 800):
        """
        Args:
            labels_df (Pandas DF): Pandas DataFrame with 'query', 'reference', and grouth truth 'label' columns
            queries_df (Pandas DF): Pandas DataFrame with 'query' and 'features' columns
            references_df (Pandas DF): Pandas DataFrame with 'reference' and 'features' columns
        """
        self.labels_df     = labels_df
        self.queries_df    = queries_df
        self.references_df = references_df
        self.max_height    = max_height
        self.max_width     = max_width
        
    def __len__(self):
        return len(self.labels_df)

    def __getitem__(self, idx):
        if torch.is_tensor(idx):
            idx = idx.tolist()

        query_name      = self.labels_df.iloc[idx, 0] 
        reference_name  = self.labels_df.iloc[idx, 1] 
        qr_label        = self.labels_df.iloc[idx, 2]

        query_feats_matrix     = queries_df.loc[queries_df["filename"]       == query_name]["features"].values[0]
        reference_feats_matrix = references_df.loc[references_df["filename"] == reference_name]["features"].values[0]

        assert query_feats_matrix.shape[1] == reference_feats_matrix.shape[1], "Query and reference feature matrices differ in number of columns"

                        # For two distance matrices Q of shape (M, F) and R of shape (N, F) where M, N time frames and F feature columns
                        # standardise each feature matrix within each feature component then compute Euclidean distance between each pair of
                        # time frames. Produces a distance matrix of shape (M, N).
        distance_matrix = cdist(query_feats_matrix, reference_feats_matrix, 'seuclidean', V = None)
                        # Normalise to [-1, 1] range by subtracting min, then dividing by range (ptp = peak-to-peak)
        distance_matrix = -1 + 2 * (distance_matrix - distance_matrix.min(0)) / distance_matrix.ptp(0)

        def get_keep_indices(dim_size, dim_max):
            if dim_size <= dim_max:
                # no need to downsample if M or N smaller than max_height/max_width
                return np.arange(0, dim_size)
            else:
                # if bigger, return evenly spaced indices for correct height/width
                return np.round(np.linspace(0, dim_size - 1, dim_max)).astype(int)

        ind_rows = get_keep_indices(distance_matrix.shape[0], self.max_height)
        ind_cols = get_keep_indices(distance_matrix.shape[1], self.max_width)

        distance_matrix = np.take(distance_matrix, ind_rows, axis = 0)
        distance_matrix = np.take(distance_matrix, ind_cols, axis = 1)

        # Create empty 100 x 800 matrix, then fill relevant cells with dist values
        temp_dists = np.full((self.max_height, self.max_width), distance_matrix.min(), dtype='float32')
        temp_dists[:distance_matrix.shape[0], :distance_matrix.shape[1]] = distance_matrix

        # Reshape to (1xHxW) since to feed into ConvNet with 1 input channel
        dists = torch.Tensor(temp_dists).view(1, self.max_height, self.max_width)
        label = torch.Tensor([qr_label])

        sample = {'index': idx, 'query': query_name, 'reference': reference_name, 'dists': dists, 'labels': label}

        return sample

for dataset in datasets:

    # If "_all_" see what features have been extracted for given dataset (in case it differs from dataset to dataset)
    extracted_feats = [ os.path.basename(p) for p in glob.glob(os.path.join(args.feats_dir, dataset, "*")) ] if args.features == '_all_' else [ args.features ]

    for features in extracted_feats:

        labels_csv     = os.path.join(args.datasets_dir, dataset, 'labels.csv')
        queries_pkl    = os.path.join(args.feats_dir, dataset, features, args.queries_file)
        references_pkl = os.path.join(args.feats_dir, dataset, features, args.references_file)

        assert os.path.isfile(labels_csv), "Labels file does not exist at: {}".format(labels_csv)
        assert os.path.isfile(queries_pkl), "Queries features file does not exist at: {}".format(queries_pkl)
        assert os.path.isfile(references_pkl), "References features file does not exist at: {}".format(references_pkl)
        Path(args.output_dir).mkdir(parents=True, exist_ok=True)

        labels_df     = pd.read_csv(labels_csv)
        queries_df    = pickle.load(open(queries_pkl, "rb"))
        references_df = pickle.load(open(references_pkl, "rb"))

        queries_set    = set(labels_df["query"].unique())
        references_set = set(labels_df["reference"].unique())

        # Check that all the query-reference file pairs actually occur in the features files
        assert queries_set.difference(set(queries_df["filename"].unique())) == set(), "Queries in {} missing from filenames in {}".format(labels_csv, queries_pkl)
        assert references_set.difference(set(references_df["filename"].unique())) == set(), "References in {} missing from filenames {}".format(labels_csv, references_pkl)

        pt_dataset    = STD_Dataset(labels_df, queries_df, references_df)
        pt_dataloader = DataLoader(
            dataset = pt_dataset,
            batch_size = args.batch_size, 
            shuffle = False,
            # Not having num_workers = 0 on a CPU-only machine causes script to hang
            num_workers = args.num_dlw if args.use_gpu else 0
        )

        # Add empty predictions column
        labels_df["prediction"] = np.nan

        with torch.no_grad():

            for batch_index, batch_data in enumerate(tqdm(pt_dataloader)):

                dists  = batch_data['dists']

                if (args.use_gpu):
                    dists = dists.cuda()

                outputs = cnn_model(dists)

                # Update predictions of relevant rows with outputs
                labels_df.at[batch_data['index'], 'prediction'] = outputs.cpu().detach()

        Path(args.output_dir).mkdir(parents=True, exist_ok=True)
        output_file = os.path.join(args.output_dir, "{}_{}.csv".format(features, dataset))

        labels_df.to_csv(output_file, index = False)
