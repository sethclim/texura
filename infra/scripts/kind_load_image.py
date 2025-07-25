



import subprocess
import argparse

def load_image_kind(image, cluster="minikube"):

    try:
        res = subprocess.run(["minikube", "image", "load", image, "--profile",  cluster], text=True)
        print(res)

    except subprocess.CalledProcessError as e:
        print(f"Command failed with return code {e.returncode}")



if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Example script with argparse.")

    parser.add_argument("-i", "--image", required=True)
    parser.add_argument("-c", "--cluster", default="kind")

    args = parser.parse_args()
    load_image_kind(args.image, args.cluster)
    