

import subprocess


from kind_load_image import load_image_kind

base_path = "../../apps/"

images = ["texture_engine", "texura_api"]

def build_docker_image(name, path, no_cache=False):
    cmd = ["docker", "build"]

    if no_cache:
        cmd.append("--no_cache")

    cmd.extend(["-t", name,  path])

    try:
        res = subprocess.run(cmd, text=True)
        print(res)

    except subprocess.CalledProcessError as e:
        print(f"Command failed with return code {e.returncode}")

def main():
    for image in images:
        image_build_path = f"{base_path}/{image}"
        build_docker_image(name=image, path=image_build_path)
        load_image_kind(image, cluster='texura-dev')

if __name__ == '__main__':
    main()

