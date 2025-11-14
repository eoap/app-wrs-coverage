from __future__ import annotations
import planetary_computer
import pystac_client
from dask.distributed import Client, LocalCluster
import dask_geopandas as dgpd
import matplotlib.pyplot as plt
from dask_gateway import Gateway
import click
import loguru
import traceback
import os
import sys

logger = loguru.logger

# "landsat-c2-l2"


def main(collection_id: str) -> None:

    logger.info(f"Processing collection: {collection_id}")
    catalog = pystac_client.Client.open(
        "https://planetarycomputer.microsoft.com/api/stac/v1/"
    )
    collection = catalog.get_collection(collection_id)

    logger.info("Signing geoparquet-items asset")
    asset = planetary_computer.sign(collection.assets["geoparquet-items"])

    logger.info("Reading data into Dask GeoDataFrame")
    df = dgpd.read_parquet(
        asset.href,
        storage_options=asset.extra_fields["table:storage_options"],
        npartitions=40,
        columns=["landsat:wrs_path", "landsat:wrs_row", "geometry"],
    )

    logger.info("Computing acquisitions by WRS tile")
    acq_by_tile = (
        df.groupby(["landsat:wrs_path", "landsat:wrs_row"])
        .size()
        .compute()
        .reset_index(name="count")
    )

    logger.info("Extracting unique tile geometries")
    tile_geoms = (
        df[["landsat:wrs_path", "landsat:wrs_row", "geometry"]]
        .drop_duplicates(subset=["landsat:wrs_path", "landsat:wrs_row"])
        .compute()
    )

    logger.info("Merging acquisition counts with tile geometries")
    acq_by_tile_gdf = tile_geoms.merge(
        acq_by_tile,
        on=["landsat:wrs_path", "landsat:wrs_row"],
        how="left",
    )

    logger.info("Generating plot of acquisitions by WRS tile")
    fig, ax = plt.subplots(figsize=(10, 8))

    acq_by_tile_gdf.plot(
        column="count",
        ax=ax,
        legend=True,
        cmap="viridis",
        edgecolor="black",
        linewidth=0.2,
    )

    ax.set_title("Landsat acquisitions per WRS tile")
    ax.set_axis_off()

    fig.savefig("acq-by-wrs-tile.png", dpi=200, bbox_inches="tight")

    logger.info("Saving acquisition data to Parquet")
    acq_by_tile_gdf.to_parquet("acq-by-wrs-tile.parquet", index=False)

@click.command()
@click.option(
    "--collection-id",
    "collection_id",
    required=True,
    help="STAC Collection ID",
    default="landsat-c2-l2",
)
def start(collection_id):

    client = cluster = None

    if "DASK_CLUSTER" not in os.environ:
        logger.info("DASK_CLUSTER environment variable is not set.")
        logger.info("Starting a local Dask cluster for testing purposes.")
        # Start cluster
        cluster = LocalCluster()
        client = Client(cluster)
    else:
        gateway = Gateway()
        cluster_name = os.environ.get("DASK_CLUSTER")
        logger.info(f"Connecting to the Dask cluster: {cluster_name}")
        cluster = gateway.connect(cluster_name=cluster_name)
        client = cluster.get_client()

    try:
        logger.info(f"Dask Dashboard: {client.dashboard_link}")
        main(collection_id=collection_id)
        logger.info("Computation completed successfully!")
    except Exception as e:
        logger.error("Failed to run the script: {}", e)
        logger.error(traceback.format_exc())
    finally:
        if "DASK_CLUSTER" not in os.environ and cluster is not None:
            logger.info("Shutting down the local Dask cluster.")
            cluster.close()
        sys.exit(0)
