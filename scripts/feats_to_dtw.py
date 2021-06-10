import argparse
import glob
import os
import pickle
import numpy as np
import pandas as pd
from dtw import dtw, StepPattern
from pathlib import Path
from scipy.spatial.distance import cdist
from tqdm.contrib.concurrent import process_map

parser = argparse.ArgumentParser(
    description='example: python feats_to_dtw.py mfcc wrm-pd',
    formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )

parser.add_argument('features', help='features to use in DTW computations, use _all_ to iterate over all')
parser.add_argument('dataset', help = 'name of dataset, use _all_ to iterate over all')

parser.add_argument('--feats_dir',  default='data/interim/features', help = "directory for features")
parser.add_argument('--datasets_dir', default='data/raw/datasets', help = "directory for raw datasets and labels files")
parser.add_argument('--output_dir',  default='data/processed/dtw', help = "directory for dtw output, will create if it does not exist")

parser.add_argument('--queries_file',  default='queries.pickle', help = "file with features of queries")
parser.add_argument('--references_file',  default='references.pickle', help = "file with features of references")
parser.add_argument('--labels_file',  default='labels.csv', help = "file indicating which query occurs in which reference")

args = parser.parse_args()

datasets = [ os.path.basename(p) for p in glob.glob(os.path.join(args.datasets_dir, "*")) ] if args.dataset == '_all_' else [ args.dataset ]

for dataset in datasets:

    # If "_all_" see what features have been extracted for given dataset (in case it differs from dataset to dataset)
    wildcard = '*' if args.features == '_all_' else args.features + "*"

    extracted_feats = [ os.path.basename(p) for p in sorted(glob.glob(os.path.join(args.feats_dir, dataset, wildcard))) ]

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

        # Add a 'prediction' column to labels dataframe, where the value is a
        # score between 0 and 1 calculated by using DTW to calculate whether there
        # is a region inside the reference that is spectrally similar to the query
        # 
        # | query | reference   | label | prediction |
        # | hello | hello there |   1   |    0.99    |
        # | hello | cool beans  |   0   |    0.51    |

        def dtw_by_row(row_number):

            # Fetch metadata and features for relevant row in labels_df dataframe
            row_data               = labels_df.iloc[row_number]
            query_feats_matrix     = queries_df.loc[queries_df["filename"]       == row_data["query"]]["features"].values[0]
            reference_feats_matrix = references_df.loc[references_df["filename"] == row_data["reference"]]["features"].values[0]

            assert query_feats_matrix.shape[1] == reference_feats_matrix.shape[1], "Query and reference feature matrices differ in number of columns"

                            # For two distance matrices Q of shape (M, F) and R of shape (N, F) where M, N time frames and F feature columns
                            # standardise each feature matrix within each feature component then compute Euclidean distance between each pair of
                            # time frames. Produces a distance matrix of shape (M, N).
            distance_matrix = cdist(query_feats_matrix, reference_feats_matrix, 'seuclidean', V = None)
                            # Normalise to [0, 1] range by subtracting min, then dividing by range (ptp = peak-to-peak)
            distance_matrix = (distance_matrix - distance_matrix.min(0)) / distance_matrix.ptp(0)

            # Segmental DTW: divide reference into segments by moving
            # a window roughly the size of the query along the length
            # of the reference and calculate a DTW alignment at each step

            segdtw_dists = []
            query_length, reference_length = distance_matrix.shape

            # reject if alignment less than half of query size
            # or if larger than 1.5 times query size
            min_match_ratio, max_match_ratio = [0.5, 1.5]

            window_size      = int(query_length * max_match_ratio)
            last_segment_end = int(reference_length - (min_match_ratio * query_length))

            for r_i in range(last_segment_end):
                
                segment_start = r_i
                segment_end   = min(r_i + window_size, reference_length)

                segment_data  = distance_matrix[:,segment_start:segment_end]
                
                dtw_obj = dtw(segment_data,
                    step_pattern = "symmetricP1", # See Sakoe & Chiba (1978) for definition of step pattern
                    open_end = True,              # Let alignment end anywhere along the segment (need not be at lower corner)
                    distance_only = True          # Speed up dtw(), no backtracing for alignment path
                )

                match_ratio = dtw_obj.jmin / query_length

                if match_ratio < min_match_ratio or match_ratio > max_match_ratio:
                    segdtw_dists.append(1)
                else:
                    segdtw_dists.append(dtw_obj.normalizedDistance)

            # Convert distance (lower is better) to similary score (is higher better)
            # makes it easier to compare with CNN output probabilities
            #
            # Return 0 if segdtw_dists is [] (i.e. no good alignments found)
            sim_score = 0 if len(segdtw_dists) == 0 else 1 - min(segdtw_dists)

            return sim_score

        tqdm_desc = "Running DTW on {} dataset with {} features".format(dataset, features)

        labels_df["prediction"] = process_map(dtw_by_row, range(labels_df.shape[0]),
            chunksize = 1,
            desc = tqdm_desc
        )

        output_file = os.path.join(args.output_dir, "{}_{}.csv".format(features, dataset))

        labels_df.to_csv(output_file, index = False)
