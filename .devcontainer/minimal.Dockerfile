# This file is used to build the pulse-devcontainer image which we
# routinely push to DockerHub. It will not be rebuilt by rebuilding only
# the devcontainer. An alternative is replacing the "image" field in
# the devcontainer with a "build" field, but that would make everyone
# rebuild the container (and FStar, and Pulse) everytime, which is very
# expensive.

FROM ubuntu:latest

SHELL ["/bin/bash", "-c"]

# Base dependencies: opam
# CI dependencies: jq (to identify F* branch)
# python3 (for interactive tests)
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      wget \
      git \
      gnupg \
      sudo \
      python3 \
      python-is-python3 \
      pkg-config \
      libgmp-dev \
      opam \
      vim \
    && apt-get clean -y
# FIXME: libgmp-dev should be installed automatically by opam,
# but it is not working, so just adding it above.

# Create a new user and give them sudo rights
ARG USER=vscode
RUN useradd -d /home/$USER -s /bin/bash -m $USER
RUN echo "$USER ALL=NOPASSWD: ALL" >> /etc/sudoers
USER $USER
ENV HOME /home/$USER
WORKDIR $HOME
RUN mkdir -p $HOME/bin

# Make sure ~/bin is in the PATH
RUN echo 'export PATH=$HOME/bin:$PATH' | tee --append $HOME/.profile $HOME/.bashrc $HOME/.bash_profile

# Install OCaml
ARG OCAML_VERSION=4.14.1
RUN opam init --compiler=$OCAML_VERSION --disable-sandboxing
RUN opam option depext-run-installs=true
ENV OPAMYES=1
RUN opam install --yes batteries zarith stdint yojson dune menhir menhirLib pprint sedlex ppxlib process ppx_deriving ppx_deriving_yojson memtrace

# Get F* and build (branch pulse-tutorial)
RUN eval $(opam env) \
 && source $HOME/.profile \
 && git clone --depth=1 https://github.com/FStarLang/FStar \
 && cd FStar/ \
 && opam install --yes --deps-only . \
 && make -j$(nproc) ADMIT=1 \
 && ln -s $(realpath bin/fstar.exe) $HOME/bin/fstar.exe

ENV FSTAR_HOME $HOME/FStar

# Install Z3
RUN sudo ./FStar/.scripts/get_fstar_z3.sh /usr/local/bin

# Get karamel master and build
RUN eval $(opam env) \
 && source $HOME/.profile \
 && git clone --depth=1 https://github.com/FStarLang/karamel \
 && cd karamel/ \
 && .docker/build/install-other-deps.sh \
 && make -j$(nproc)

ENV KRML_HOME $HOME/karamel

# Get Pulse (main branch) and build
RUN eval $(opam env) \
 && source $HOME/.profile \
 && git clone --depth=1 https://github.com/FStarLang/pulse -b main \
 && cd pulse/ \
 && make -j$(nproc) \
 && make -j$(nproc) -C share/pulse/examples

ENV PULSE_HOME $HOME/pulse

# Instrument .bashrc to set the opam switch. Note that this
# just appends the *call* to eval $(opam env) in these files, so we
# compute the new environments fter the fact. Calling opam env here
# would perhaps thrash some variables set by the devcontainer infra.
RUN echo 'eval $(opam env --set-switch)' | tee --append $HOME/.bashrc
