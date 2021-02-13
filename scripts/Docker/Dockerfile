FROM pytorch/pytorch:1.7.1-cuda11.0-cudnn8-runtime

RUN apt-get update
RUN apt-get install -y git \
    wget \
    unzip

WORKDIR /home
RUN git clone https://github.com/fauxneticien/qbe-std_feats_eval.git

WORKDIR /home/qbe-std_feats_eval
RUN pip install -r requirements.txt

WORKDIR /tmp
RUN wget https://github.com/bootphon/shennong/archive/412ec4f6ada2ffe404decf1273030e5634879632.zip && \
    unzip 412ec4f6ada2ffe404decf1273030e5634879632.zip && \
    mv shennong-412ec4f6ada2ffe404decf1273030e5634879632 /shennong && \
    cp /home/qbe-std_feats_eval/scripts/Docker/shennong_environment.yml /shennong/environment.yml

# Taken from Shennong Dockerfile
# https://github.com/bootphon/shennong/blob/412ec4f6ada2ffe404decf1273030e5634879632/Dockerfile
WORKDIR /shennong
# setup shennong environment
COPY environment.yml /shennong/environment.yml
RUN conda env create -n shennong -f environment.yml && \
        rm -rf /opt/conda/pkgs/*

# install/test shennong
COPY . /shennong/
RUN /bin/bash -c "source activate shennong && \
        python setup.py install && \
        python setup.py test"

# activate the shennong environment
ENV PATH=/opt/conda/envs/shennong/bin:$PATH
