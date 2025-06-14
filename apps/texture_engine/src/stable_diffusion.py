#!/usr/bin/env python
import argparse
import datetime
import inspect
import os
import re
import warnings

import numpy as np
import torch
from PIL import Image
from diffusers import (
    AutoPipelineForText2Image,
    AutoPipelineForImage2Image,
    AutoPipelineForInpainting,
    DiffusionPipeline,
    OnnxStableDiffusionPipeline,
    OnnxStableDiffusionInpaintPipeline,
    OnnxStableDiffusionImg2ImgPipeline,
    schedulers,
)


def iso_date_time():
    return datetime.datetime.now().isoformat()


def load_image(path):
    image = Image.open(os.path.join("input", path)).convert("RGB")
    print(f"loaded image from {path}:", iso_date_time(), flush=True)
    return image


def remove_unused_args(p):
    params = inspect.signature(p._pipeline).parameters.keys()
    args = {
        "prompt": p.prompt,
        "negative_prompt": p.negative_prompt,
        "image": p.image,
        "mask_image": p.mask,
        "height": p.height,
        "width": p.width,
        "num_images_per_prompt": p.samples,
        "num_inference_steps": p.steps,
        "guidance_scale": p.scale,
        "image_guidance_scale": p.image_scale,
        "strength": p.strength,
        "generator": p._generator,
    }
    return {p: args[p] for p in params if p in args}


def stable_diffusion_pipeline(p):
    p._dtype = torch.float16 if p.half else torch.float32

    if p.onnx:
        p._diffuser = OnnxStableDiffusionPipeline
        p._revision = "onnx"
    else:
        p._diffuser = DiffusionPipeline
        p._revision = "fp16" if p.half else "main"

    autos = argparse.Namespace(
        **{
            "sd": ["StableDiffusionPipeline"],
            "sdxl": ["StableDiffusionXLPipeline"],
        }
    )

    config = DiffusionPipeline.load_config(p.model)
    is_auto_pipeline = config["_class_name"] in [autos.sd, autos.sdxl]

    if is_auto_pipeline:
        p._diffuser = AutoPipelineForText2Image

    if p.image is not None:
        if p._revision == "onnx":
            p._diffuser = OnnxStableDiffusionImg2ImgPipeline
        elif is_auto_pipeline:
            p._diffuser = AutoPipelineForImage2Image
        p.image = load_image(p.image)

    if p.mask is not None:
        if p._revision == "onnx":
            p._diffuser = OnnxStableDiffusionInpaintPipeline
        elif is_auto_pipeline:
            p._diffuser = AutoPipelineForInpainting
        p.mask = load_image(p.mask)

    if p.token is None:
        with open("token.txt") as f:
            p.token = f.read().replace("\n", "")

    if p.seed == 0:
        p.seed = torch.random.seed()

    if p._revision == "onnx":
        p.seed = p.seed >> 32 if p.seed > 2**32 - 1 else p.seed
        p._generator = np.random.RandomState(p.seed)
    else:
        p._generator = torch.Generator(device=p.device).manual_seed(p.seed)

    print("load pipeline start:", iso_date_time(), flush=True)

    with warnings.catch_warnings():
        for c in [UserWarning, FutureWarning]:
            warnings.filterwarnings("ignore", category=c)
        pipeline = p._diffuser.from_pretrained(
            p.model,
            torch_dtype=p._dtype,
            revision=p._revision,
            use_auth_token=p.token,
        ).to(p.device)

    if p._scheduler is not None:
        scheduler = getattr(schedulers, p._scheduler)
        pipeline._scheduler = scheduler.from_config(pipeline.scheduler.config)

    if p.skip:
        pipeline.safety_checker = None

    if p.attention_slicing:
        pipeline.enable_attention_slicing()

    if p.xformers_memory_efficient_attention:
        pipeline.enable_xformers_memory_efficient_attention()

    if p.vae_slicing:
        pipeline.enable_vae_slicing()

    if p.vae_tiling:
        pipeline.enable_vae_tiling()

    p._pipeline = pipeline

    print("loaded models after:", iso_date_time(), flush=True)

    return p


def stable_diffusion_inference(p):
    prefix = (
        re.sub(r"[\\/:*?\"<>|]", "", p.prompt)
        .replace(" ", "_")
        .encode("utf-8")[:170]
        .decode("utf-8", "ignore")
    )
    for j in range(p.iters):
        result = p._pipeline(**remove_unused_args(p))

        for i, img in enumerate(result.images):
            idx = j * p.samples + i + 1
            out = f"{prefix}__steps_{p.steps}__scale_{p.scale:.2f}__seed_{p.seed}__n_{idx}.png"

            print(f"OUT {out}")
            img.save(os.path.join("output", out))

    print("completed pipeline:", iso_date_time(), flush=True)



def parse_args():
    parser = argparse.ArgumentParser(description="Create images from a text prompt.")
    parser.add_argument(
        "--attention-slicing",
        action="store_true",
        help="Use less memory at the expense of inference speed",
    )
    parser.add_argument(
        "--device",
        type=str,
        nargs="?",
        default="cuda",
        help="The cpu or cuda device to use to render images",
    )
    parser.add_argument(
        "--half",
        action="store_true",
        help="Use float16 (half-sized) tensors instead of float32",
    )
    parser.add_argument(
        "--height", type=int, nargs="?", default=512, help="Image height in pixels"
    )
    parser.add_argument(
        "--image",
        type=str,
        nargs="?",
        help="The input image to use for image-to-image diffusion",
    )
    parser.add_argument(
        "--image-scale",
        type=float,
        nargs="?",
        help="How closely the image should follow the original image",
    )
    parser.add_argument(
        "--iters",
        type=int,
        nargs="?",
        default=1,
        help="Number of times to run pipeline",
    )
    parser.add_argument(
        "--mask",
        type=str,
        nargs="?",
        help="The input mask to use for diffusion inpainting",
    )
    parser.add_argument(
        "--model",
        type=str,
        nargs="?",
        default="CompVis/stable-diffusion-v1-4",
        help="The model used to render images",
    )
    parser.add_argument(
        "--negative-prompt",
        type=str,
        nargs="?",
        help="The prompt to not render into an image",
    )
    parser.add_argument(
        "--onnx",
        action="store_true",
        help="Use the onnx runtime for inference",
    )
    parser.add_argument(
        "--prompt", type=str, nargs="?", help="The prompt to render into an image"
    )
    parser.add_argument(
        "--samples",
        type=int,
        nargs="?",
        default=1,
        help="Number of images to create per run",
    )
    parser.add_argument(
        "--scale",
        type=float,
        nargs="?",
        default=7.5,
        help="How closely the image should follow the prompt",
    )
    parser.add_argument(
        "--scheduler",
        type=str,
        nargs="?",
        help="Override the scheduler used to denoise the image",
    )
    parser.add_argument(
        "--seed", type=int, nargs="?", default=0, help="RNG seed for repeatability"
    )
    parser.add_argument(
        "--skip",
        action="store_true",
        help="Skip the safety checker",
    )
    parser.add_argument(
        "--steps", type=int, nargs="?", default=50, help="Number of sampling steps"
    )
    parser.add_argument(
        "--strength",
        type=float,
        default=0.75,
        help="Diffusion strength to apply to the input image",
    )
    parser.add_argument(
        "--token", type=str, nargs="?", help="Huggingface user access token"
    )
    parser.add_argument(
        "--vae-slicing",
        action="store_true",
        help="Use less memory when creating large batches of images",
    )
    parser.add_argument(
        "--vae-tiling",
        action="store_true",
        help="Use less memory when creating ultra-high resolution images",
    )
    parser.add_argument(
        "--width", type=int, nargs="?", default=512, help="Image width in pixels"
    )
    parser.add_argument(
        "--xformers-memory-efficient-attention",
        action="store_true",
        help="Use less memory but require the xformers library",
    )
    parser.add_argument(
        "prompt0",
        metavar="PROMPT",
        type=str,
        nargs="?",
        help="The prompt to render into an image",
    )

    args = parser.parse_args()

    if args.prompt0 is not None:
        args.prompt = args.prompt0

    return args


