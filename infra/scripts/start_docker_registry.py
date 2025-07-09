import argparse
import subprocess

# reg_name = "kind-registry"
# reg_port = 5000

parser = argparse.ArgumentParser(description="Example script with argparse.")

parser.add_argument("-n", "--reg_name", default="kind-registry")
parser.add_argument("-p", "--reg_port", default="5000")

args = parser.parse_args()

def is_container_running(name):
    try:
        result = subprocess.run(
            ["docker", "inspect", "-f", "{{.State.Running}}", name],
            capture_output=True,
            text=True,
            check=True,
        )
        return result.stdout.strip() == "true"
    except subprocess.CalledProcessError:
        # Container does not exist or inspect failed
        return False

if not is_container_running(args.reg_name):
    subprocess.run(
        [
            "docker", "run",
            "-d",
            "--restart=always",
            "-p", f"{args.reg_port}:{args.reg_port}",
            "--network", "bridge",
            "--name", args.reg_name,
            "registry:2"
        ],
        check=True
    )
