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
import json
import os
import re
import subprocess
import time
from textwrap import dedent

import docker
import matplotlib.pyplot as plt
import requests

# code inspired from "https://github.com/sylhare/docker-stats-graph"
def collect_docker_stats(container_name, duration=60, interval=1, start=None):
  docker_client = docker.from_env()
  container = docker_client.containers.get(container_name)
  stats = []
  if start is None:
    start = time.monotonic()
  while (time.monotonic() - start) < duration:
    instant = time.monotonic() - start
    instant_stats = container.stats(stream=False)
    stats.append((instant, instant_stats))
    time.sleep(max(interval - (time.monotonic() - instant - start), 0))
  return stats

def collect_apache_stats(duration=60, interval=1, start=None):
  stats = []
  if start is None:
    start = time.monotonic()
  while (time.monotonic() - start) < duration:
    instant = time.monotonic() - start
    stats_txt = requests.get("http://world.openfoodfacts.localhost/_apache_status", params={"auto": 1}).text
    stats_txt = [line.split(":", 1) for line in stats_txt.split("\n") if ":" in line]
    stats_n = {
      label.strip(): float(value)
      for label, value in stats_txt
      if re.match(r"^\d+(.(\d+)?)?$", value.strip())
    }
    stats.append((instant, stats_n))
    time.sleep(max(interval - (time.monotonic() - instant - start), 0))
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


def test_plot_stats(experiment_dir, args):
  docker_stats = [
    (i, {"memory_stats": {"usage": (1024 * 1024) + i * 1204 * 10}})
    for i in range(60)
  ]
  apache_stats = [
    (i, {"BusyWorkers": i // 10})
    for i in range(60)
  ]
  plot_stats(docker_stats, apache_stats, experiment_dir, args)


def plot_stats(docker_stats, apache_stats, experiment_dir, args):
  import matplotlib.pyplot as plt

  memory_stats = [
    (instant, stat["memory_stats"]["usage"] / (1024 * 1024))
    for instant, stat in docker_stats
  ]
  apache_stats = [
    (instant, stat["BusyWorkers"])
    for instant, stat in apache_stats
  ]
  fig, (legend, docker_graph, apache_graph) = plt.subplots(3, 1, figsize=(5, 10))
  plt.sca(docker_graph)
  plt.xlabel("time (s)")
  plt.ylabel("memory (MiB)")
  plt.title(f"Memory usage")
  plt.grid(True)
  plt.plot(*zip(*memory_stats))
  plt.tight_layout()
  plt.sca(apache_graph)
  plt.xlabel("time (s)")
  plt.ylabel("workers")
  plt.title(f"Busy workers")
  plt.grid(True)
  plt.plot(*zip(*apache_stats))
  plt.tight_layout()
  # legend of experiment
  plt.sca(legend)
  plt.title(f"Experiment {args.name}")
  legend.get_xaxis().set_visible(False)
  legend.get_yaxis().set_visible(False)
  legend.annotate(
    text=dedent(f"""\
    StartServers: {args.start_servers}
    MaxRequestWorkers: {args.max_request_workers}
    MinSpareServers: {args.min_spare}
    MaxSpareServers: {args.max_spare}
    """),
    xy=(0.1, 0.1),
    xytext=(0.1, 0.1),
  )
  fig.savefig(f"{experiment_dir}/memory_usage.png")


SERVICE = "backend"
CONTAINER = f"po_off-backend-1"
TEST_SCENARIO = "scripts/tests/test_scenario.py"


if __name__ == "__main__":
  args = parse_args()
  experiment_dir = f"mem_usage/{args.name}"
  os.makedirs(experiment_dir, exist_ok=True)
  # executor = concurrent.futures.ThreadPoolExecutor(max_workers=2)
  # future_apache_stats = executor.submit(collect_apache_stats, duration=10)
  # print(future_apache_stats.result())
  # exit(0)
  # test_plot_stats(experiment_dir, args)
  # exit(0)
  # relaunch docker container
  print("Relaunching docker container  ---------")
  backend_env = backend_env_variables(args)
  docker_env = dict(os.environ, **backend_env)
  if not args.skip_restart:
    subprocess.run(["docker-compose", "rm", "-sf", SERVICE])
    subprocess.run(["docker-compose", "up", "-d", SERVICE], env=docker_env)
  # wait a bit the container to be ready
  print("Waiting for docker container to be ready  ---------")
  wait_backend()
  print("Docker container is ready  ---------")
  start = time.monotonic()
  print("Launching stats ---------")
  # launch stats in parallel
  executor = concurrent.futures.ThreadPoolExecutor(max_workers=2)
  future_docker_stats = executor.submit(collect_docker_stats, container_name=CONTAINER, duration=80, start=start)
  future_apache_stats = executor.submit(collect_apache_stats, duration=80, start=start)
  print("Launching test ---------")
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
  print("Test finished ---------")
  docker_stats = future_docker_stats.result()
  apache_stats = future_apache_stats.result()
  json.dump(docker_stats, open(f"{experiment_dir}/docker_stats.json", "w"))
  json.dump(apache_stats, open(f"{experiment_dir}/apache_stats.json", "w"))
  print("Stats collected  ---------")
  plot_stats(docker_stats, apache_stats, experiment_dir, args)
  print("Plot generated  ---------")
  print(f"See {experiment_dir}/memory_usage.png")
