FROM pytorch/pytorch:1.7.1-cuda11.0-cudnn8-runtime

RUN apt-get update && \
    apt-get install -y libsndfile1 \
    git \
    g++ && \
    rm -rf /var/lib/apt/lists

WORKDIR /home
RUN git clone https://github.com/fauxneticien/qbe-std_feats_eval.git

WORKDIR /home/qbe-std_feats_eval
RUN pip install -r requirements.txt

# Install R and perl for STDEval tool
ENV TZ=America/Los_Angeles
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN apt-get update && \
    apt-get install -y apt-transport-https software-properties-common parallel perlbrew && \
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E298A3A825C0D65DFD57CBB651716619E084DAB9 && \
    add-apt-repository 'deb https://cloud.r-project.org/bin/linux/ubuntu bionic-cran35/' && \
    apt-get update && apt-get install -y r-base && \
    Rscript -e "install.packages(c('dplyr', 'glue', 'purrr', 'furrr', 'readr', 'stringr', 'tuneR'))" && \
    mkdir -p /root/perl5/perlbrew/dists/ && \
    perlbrew install perl-5.18.4 -n --switch && \
    cd /home/qbe-std_feats_eval
