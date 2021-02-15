FROM continuumio/miniconda3

# Setup a language agnostic locale
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8

RUN apt-get update && \
    apt-get install -y g++ && \
    apt-get clean

RUN conda install -y -c coml shennong=0.1.1

WORKDIR /home
RUN git clone https://github.com/fauxneticien/qbe-std_feats_eval.git

WORKDIR /home/qbe-std_feats_eval
RUN pip install -r requirements.txt
