FROM ubuntu:22.04 AS builder

# Install common dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    libx11-dev \
    libxft-dev \
    libfontconfig1-dev \
    libxinerama-dev \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Build dmenu
WORKDIR /app/dmenu
COPY ./dmenu .
RUN mkdir build && cd build && \
    cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local && \
    make -j$(nproc) && \
    make install

# Build dwm
WORKDIR /app/dwm
COPY ./dwm .
RUN make -j$(nproc) && \
    make install

# Build st
WORKDIR /app/st
COPY ./st .
RUN make -j$(nproc) && \
    make install

FROM ubuntu:22.04 AS runtime

RUN apt-get update && apt-get install -y \
    libx11-6 \
    libxft2 \
    libfontconfig1 \
    libxinerama1 \
    && rm -rf /var/lib/apt/lists/*

# Copy binaries
COPY --from=builder /usr/local/bin/ /usr/local/bin/
COPY --from=builder /usr/local/share/man/ /usr/local/share/man/

CMD ["dmenu"]