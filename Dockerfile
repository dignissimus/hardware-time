FROM ubuntu:24.04

RUN apt-get update --fix-missing\
    && apt-get install -y build-essential wget git libguestfs-tools nano gpg apt-transport-https\
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV CONDA_DIR=/opt/conda
RUN wget https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh -O ~/miniconda.sh && \
    /bin/bash ~/miniconda.sh -b -p /opt/conda
ENV PATH=$CONDA_DIR/bin:$PATH
RUN conda init bash
SHELL ["/bin/bash", "-c"]
# Conda dependency resolver
RUN conda update -n base -c defaults conda && \
    conda install -n base conda-libmamba-solver && \
    conda config --set solver libmamba && \
    conda install -n base conda-lock==1.4.0

# Activate conda environment
RUN echo "conda activate base" >> ~/.bashrcs

# Get chipyard (from the public git repo for now)
RUN git clone https://github.com/ucb-bar/chipyard.git   && \
    cd chipyard && \
    git checkout 1.13.0
WORKDIR /chipyard

# make the submodules shallow to try and speed things up
RUN sed -i -e 's/\.git/\.git\n\tshallow = true/g' .gitmodules
# don't build makefiles for generators which we are not using (yet)
RUN sed -i \
    -e 's/^include \$(base_dir)\/generators\/cva6\/cva6.mk/# include \$(base_dir)\/generators\/cva6\/cva6.mk/' \
    -e 's/^include \$(base_dir)\/generators\/ibex\/ibex.mk/# include \$(base_dir)\/generators\/ibex\/ibex.mk/' \
    -e 's/^include \$(base_dir)\/generators\/ara\/ara.mk/# include \$(base_dir)\/generators\/ara\/ara.mk/' \
    -e 's/^include \$(base_dir)\/generators\/nvdla\/nvdla.mk/# include \$(base_dir)\/generators\/nvdla\/nvdla.mk/' \
    common.mk
# append config and datetime when simulation was run so that I know what was run and when it was run
RUN sed -i \
    -e 's/get_out_name = $(subst $() $(),_,$(notdir $(basename $(1))))/get_out_name = $(subst $() $(),_,$(notdir $(basename $(1))))_$(CONFIG)_$(shell date +%Y-%m-%d-%H:%M:%S)/' \
    variables.mk

# skip precompile for all generators in chipyard(step 5), FireSim (steps 6, 7) and FireMarshal (steps 8,9)
RUN ./build-setup.sh riscv-tools --use-lean-conda -s 5 -s 6 -s 7 -s 8 -s 9

# add line to modify boom instantiation parameters for printing out stuff with spike
RUN sed -i \
    -e 's/enableCommitLogPrintf: Boolean = false/enableCommitLogPrintf: Boolean = true/' \
    -e 's/enableBranchPrintf: Boolean = false/enableBranchPrintf: Boolean = true/' \
    /chipyard/generators/boom/src/main/scala/v3/common/parameters.scala

# run verilator
WORKDIR /chipyard/sims/verilator
# change this based on your local environment, $(nproc) doesn't work with containers
ENV VERILATOR_THREADS=14
# BINARIES has to be set AFTER running source
# Run all the rv64si tests for RocketConfig
RUN source ../../env.sh && \
    make VERILATOR_THREADS=${VERILATOR_THREADS} USE_FST=1 run-binaries-debug "BINARIES=$(find ../../toolchains/riscv-tools/riscv-tests/build/isa -name 'rv64si-p-*' ! -name '*.*')"
# Run all the rv64si tests for SmallBoomV3Config
RUN source ../../env.sh && \
    make VERILATOR_THREADS=${VERILATOR_THREADS} USE_FST=1 CONFIG=SmallBoomV3Config run-binaries-debug "BINARIES=$(find ../../toolchains/riscv-tools/riscv-tests/build/isa -name 'rv64si-p-*' ! -name '*.*')"
