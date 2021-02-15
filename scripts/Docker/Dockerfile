FROM continuumio/miniconda3

# Setup a language agnostic locale
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8

RUN apt-get update && \
    # Need g++ to compile fairseq
    apt-get install -y g++ \
    git && \
    apt-get clean

    # Change base python to 3.7.6 for shennong
RUN conda install -y python=3.7.6 && \
    conda install -y -c coml shennong=0.1.1

WORKDIR /home
RUN git clone https://github.com/fauxneticien/qbe-std_feats_eval.git

WORKDIR /home/qbe-std_feats_eval
    # Install fairseq, etc.
    # Change torch to 1.7.0 to be compatible with torchaudio
RUN pip install -r requirements.txt
