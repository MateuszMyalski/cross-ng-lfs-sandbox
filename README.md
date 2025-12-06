# Embedded Linux with crosstool-ng, kernel and BusyBox built in Docker
A short tutorial and Docker-based reproducible environment to build a cross-compiler (crosstool-ng), an ARM Cortex‑A9 Linux kernel and a minimal rootfs (BusyBox), then run the kernel under QEMU.

```sh
# Build the Docker image
docker build -t emb .

# Run an interactive container, mounting ./shared from host (optional)
docker run -v ./shared:/shared -it emb:latest
```
