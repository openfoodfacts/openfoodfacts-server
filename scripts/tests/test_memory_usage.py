#!/usr/bin/env -S uv run --script
# help uv run this script easily
# /// script
# dependencies = [
#    "docker",
#    "requests",
#    "matplotlib",
# ]
# ///
import argparse
import concurrent.futures
import os
import subprocess
import time
from textwrap import dedent

import docker
import matplotlib.pyplot as plt
import requests

# code inspired from "https://github.com/sylhare/docker-stats-graph"
def run_docker_stats(container_name, duration=60, interval=1):
  docker_client = docker.from_env()
  container = docker_client.containers.get(container_name)
  stats = []
  start = time.monotonic()
  while (time.monotonic() - start) < duration:
    instant = time.monotonic() - start
    instant_stats = container.stats(stream=False)
    stats.append((instant, instant_stats))
    time.sleep(max(interval - (time.monotonic() - instant), 0))
  return stats

def wait_backend():
  while True:
    try:
      requests.get("http://world.openfoodfacts.localhost/")
      break
    except requests.exceptions.ConnectionError:
      print(".", end="", flush=True)
      time.sleep(1)


def parse_args():
  parser = argparse.ArgumentParser(
    description="Run load testing on a docker container"
  )
  parser.add_argument(
    "name",
    help="Experiment name"
  )
  parser.add_argument(
    "start_servers",
    type=int,
    help="StartServers config",
  )
  parser.add_argument(
    "max_request_workers",
    type=int,
    help="MaxRequestWorkers config",
  )
  parser.add_argument(
    "min_spare",
    type=int,
    help="MinSpareServers config",
  )
  parser.add_argument(
    "max_spare",
    type=int,
    help="MaxSpareServers config",
  )
  parser.add_argument(
    "--skip-restart",
    action="store_true",
    help="Skip restarting the backend",
  )
  return parser.parse_args()


def backend_env_variables(args):
  return {
    "APACHE_MPM_START_SERVERS": str(args.start_servers),
    "APACHE_MPM_MAX_REQUEST_WORKERS": str(args.max_request_workers),
    "APACHE_MPM_MIN_SPARE_SERVERS": str(args.min_spare),
    "APACHE_MPM_MAX_SPARE_SERVERS": str(args.max_spare),
    "APACHE_MPM_SERVER_LIMIT": str(args.max_request_workers),
  }


def plot_stats(stats, experiment_dir, args):
  import matplotlib.pyplot as plt

  memory_stats = [
    (instant, stat["memory_stats"]["usage"])
    for instant, stat in stats
  ]
  fig, (graph, legend) = plt.subplots(2, 1)
  plt.sca(graph)
  plt.xlabel("time (s)")
  plt.ylabel("memory (bytes)")
  plt.title("Memory usage for experiment {args.name}")
  plt.grid(True)
  plt.plot(*zip(*memory_stats))
  # legend of experiment
  plt.sca(legend)
  plt.figtext(
    0.2, 0.8, dedent(f"""\
  StartServers: {args.start_servers}
  MaxRequestWorkers: {args.max_request_workers}
  MinSpareServers: {args.min_spare}
  MaxSpareServers: {args.max_spare}
  """))
  fig.savefig(f"{experiment_dir}/memory_usage.png")


SERVICE = "backend"
CONTAINER = f"po_off-backend-1"
TEST_SCENARIO = "scripts/tests/test_scenario.py"


if __name__ == "__main__":
  args = parse_args()
  experiment_dir = f"mem_usage/{args.name}"
  os.makedirs(experiment_dir, exist_ok=True)
  # relaunch docker container
  print("relaunching docker container")
  backend_env = backend_env_variables(args)
  docker_env = dict(os.environ, **backend_env)
  if not args.skip_restart:
    subprocess.run(["docker-compose", "rm", "-sf", SERVICE])
    subprocess.run(["docker-compose", "up", "-d", SERVICE], env=docker_env)
  # wait a bit the container to be ready
  print("waiting for docker container to be ready")
  wait_backend()
  print("docker container is ready")
  # launch stats in parallel
  future_stats = concurrent.futures.ThreadPoolExecutor(
    max_workers=1
  ).submit(run_docker_stats, container_name=CONTAINER, duration=80)
  # launch load testing
  subprocess.run(
    [
      "uvx",
      "locust",
      "-f",
      TEST_SCENARIO,
      "--users=50",
      "--spawn-rate=50",
      "--run-time=60s",
      "--headless",
      f"--csv={experiment_dir}/locus-stats",
    ],
  )
  print("test finished")
  stats = future_stats.result()
  print("stats collected")
  plot_stats(stats, experiment_dir, args)
  print("plot generated")
  print(f"See {experiment_dir}/memory_usage.png")
