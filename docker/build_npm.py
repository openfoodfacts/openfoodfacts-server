import subprocess
from pathlib import Path

parent_dir = str(Path(__file__).resolve().parent.parent)

args = [
    "docker",
    "run",
    "--rm",
    "-it",
    "-v=node_modules:/mnt/node_modules",
    f"-v={parent_dir}:/mnt",
    "-w=/mnt",
    "node:12.16.2-alpine3.10",
]

subprocess.call(args + (["npm", "install"]))
subprocess.call(args + (["npm", "run", "build"]))
