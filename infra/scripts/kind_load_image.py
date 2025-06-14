



import subprocess
import argparse

parser = argparse.ArgumentParser(description="Example script with argparse.")

parser.add_argument("-i", "--image", required=True)
parser.add_argument("-c", "--cluster", default="kind")

args = parser.parse_args()

try:
    res = subprocess.run(["kind", "load", "docker-image", args.image, "--name",  args.cluster], text=True)
    print(res)

except subprocess.CalledProcessError as e:
    print(f"Command failed with return code {e.returncode}")