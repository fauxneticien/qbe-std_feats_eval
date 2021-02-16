FROM pytorch/pytorch:1.7.1-cuda11.0-cudnn8-runtime

RUN apt-get update
RUN apt-get install -y git \
    g++

WORKDIR /home
RUN git clone https://github.com/fauxneticien/qbe-std_feats_eval.git

WORKDIR /home/qbe-std_feats_eval
RUN pip install -r requirements.txt
