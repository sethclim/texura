

import subprocess


from kind_load_image import load_image_kind

base_path = "../../apps/"

images = ["texture_engine", "texura_api"]

def build_docker_image(name, path):
    try:
        res = subprocess.run(["docker", "build", "-t", name,  path], text=True)
        print(res)

    except subprocess.CalledProcessError as e:
        print(f"Command failed with return code {e.returncode}")

def main():
    for image in images:
        image_build_path = f"{base_path}/{image}"
        build_docker_image(name=image, path=image_build_path)
        load_image_kind(image, cluster='test')

if __name__ == '__main__':
    main()

