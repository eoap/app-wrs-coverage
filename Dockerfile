# ---------- Stage 1: hatch binary ----------
FROM rockylinux:9.3-minimal AS hatch-build

RUN microdnf install -y curl tar && microdnf clean all

RUN curl -L https://github.com/pypa/hatch/releases/latest/download/hatch-x86_64-unknown-linux-gnu.tar.gz \
      -o /tmp/hatch-x86_64-unknown-linux-gnu.tar.gz \
 && tar -xzf /tmp/hatch-x86_64-unknown-linux-gnu.tar.gz -C /tmp/

# ---------- Stage 2: final image ----------
FROM rockylinux:9.3-minimal

# System deps: Python + build tools + GEOS/PROJ (no GDAL)
RUN microdnf update -y 

# Put hatch somewhere neutral (not under /home/<user>)
COPY --from=hatch-build /tmp/hatch /usr/local/bin/hatch
RUN chmod +x /usr/local/bin/hatch

# Where hatch stores its own Python runtimes & metadata
ENV HATCH_DATA_DIR=/opt/hatch

# App layout
WORKDIR /app
COPY . /app

# Hatch-managed env target
ENV VIRTUAL_ENV=/app/envs/wrs-coverage
ENV PATH="$VIRTUAL_ENV/bin:/usr/local/bin:/usr/bin:$PATH"

# Optional: avoid pycache noise in read-only contexts
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONPYCACHEPREFIX=/tmp/pycache

# Create the hatch env INSIDE the image using system python
# Assumes you have [tool.hatch.envs.prod] configured to use /app/envs/wrs-coverage
RUN hatch env prune && \
    hatch env create prod && \
    rm -rf /app/.git /app/.pytest_cache && \
    # Make sure runtimes/envs are world-readable (CWL runs as arbitrary UID)
    chmod -R a+rX /opt/hatch /app/envs

# Entry point: wrs-coverage CLI in that env
#ENTRYPOINT ["wrs-coverage"]
