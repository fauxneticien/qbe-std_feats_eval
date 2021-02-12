import argparse
import glob
import os
import numpy as np
import pandas as pd
from sklearn.metrics import precision_recall_curve

parser = argparse.ArgumentParser(
    description='example: python dtw_to_fbeta.py data/processed/dtw/mfcc_wrm-pd.csv',
    formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )

parser.add_argument('dtw_results_csv', help='name of results CSV file to process in dtw_results_dir, or _all_ to process all files')

parser.add_argument('--dtw_results_dir', default = "data/processed/dtw", help='name of results file to process in dtw_results_dir')
parser.add_argument('--fbeta_results_dir', default = "data/processed/fbeta", help='Folder to write raw fbeta calculations to')

parser.add_argument('--beta', type=int, default = 2, help = "beta value, e.g. 1 = F1 score")

args = parser.parse_args()

dtw_results_csvs  = glob.glob(os.path.join(args.dtw_results_dir, "*.csv")) if args.dtw_results_csv == '_all_' else [ os.path.join(args.dtw_results_dir, args.dtw_results_csv) ]

for dtw_results_csv in dtw_results_csvs:

    assert os.path.isfile(dtw_results_csv), "DTW results file does not exist at: {}".format(dtw_results_csv)

    beta            = args.beta
    dtw_results_df  = pd.read_csv(dtw_results_csv)

    precision, recall, thresholds = precision_recall_curve(dtw_results_df["label"], dtw_results_df["prediction"])

    precision = np.array(precision)
    recall    = np.array(recall)

    # Ignore divide by zero or nan (when denominator is 0 in fbeta calculations)
    np.seterr(divide='ignore', invalid='ignore')

    # See https://en.wikipedia.org/wiki/F-score#Definition
    fbeta_scores = (1 + beta**2) * (precision * recall) / (((beta**2) * precision) + recall)

    max_fbeta_i   = np.nanargmax(fbeta_scores)
    max_fbeta     = fbeta_scores[max_fbeta_i]
    max_prec      = precision[max_fbeta_i]
    max_rec       = recall[max_fbeta_i]
    max_threshold = thresholds[max_fbeta_i]

    fbeta_raw_df = pd.DataFrame({
        "Precision" : precision,
        "Recall" : recall,
        "Fbeta" : fbeta_scores
    }).rename({"Fbeta" : "F" + str(beta)})

    fbeta_results_csv = os.path.join(args.fbeta_results_dir, "f{}_{}".format(beta, os.path.basename(dtw_results_csv)))
    fbeta_raw_df.to_csv(fbeta_results_csv, index = False)

    print("""
    F-beta results for {}, with beta = {}
        Max F-beta: {}
        Precision:  {}
        Recall:     {}
        Threshold:  {}

    Raw results saved to: {}
    """.format(dtw_results_csv, beta, max_fbeta, max_prec, max_rec, max_threshold, fbeta_results_csv))
