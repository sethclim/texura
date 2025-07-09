

import glob
import logging
import os

import boto3
from botocore.client import Config
from requests import request
from stable_diffusion import stable_diffusion_inference, stable_diffusion_pipeline
import flask
from flask import request, jsonify, Response

from pydantic import BaseModel, ValidationError, PrivateAttr
from typing import Optional
import torch

logging.basicConfig(level=logging.INFO, force=True)
app = flask.Flask(__name__)

class InferenceArgsModel(BaseModel):
    attention_slicing : bool = False
    device : str = "cuda"
    half : bool = False
    height : int = 512
    image : Optional[str] = None
    image_scale : float
    iters : int = 1
    mask : Optional[str] = None
    model : str = "CompVis/stable-diffusion-v1-4"
    negative_prompt: Optional[str] = None
    onnx : bool = False
    prompt: str
    samples: int = 1
    scale: float = 7.5
    seed : int = 0
    skip : int = False
    steps : int = 50
    strength: float = 0.75
    token : Optional[str] = None
    vae_slicing : bool = False
    vae_tiling : bool = False
    width : int = 512
    xformers_memory_efficient_attention : bool = False
    # prompt0 : str
    _dtype: torch.dtype = PrivateAttr(default=torch.float32)
    _diffuser : any = PrivateAttr(default=None)
    _revision : str = PrivateAttr(default=None)
    _generator : any = PrivateAttr(default="")
    _scheduler : any = PrivateAttr(default=None)



s3 = boto3.client(
    's3',
    endpoint_url=os.environ['MINIO_ENDPOINT'],
    aws_access_key_id=os.environ['AWS_ACCESS_KEY_ID'],
    aws_secret_access_key=os.environ['AWS_SECRET_ACCESS_KEY'],
    config=Config(signature_version='s3v4'),
    region_name=os.environ['MINIO_REGION'],
)


@app.route("/ping", methods=["GET"])
def ping():
    """Determine if the container is working and healthy."""
    health = (
        500
        # ScoringService.get_model() is not None
        # You can insert a health check here
    )

    status = 200 if health else 404
    return flask.Response(response="\n", status=status, mimetype="application/json")


@app.route("/invocations", methods=["POST"])
def invoke():
    logging.info("invoke...")

    try:
        json_data = request.get_json()
        logging.info(f"json_data {json_data}")
        args = InferenceArgsModel(**json_data)
    except ValidationError as e:
        return {"error": e.errors()}, 400
    
    logging.info(args)

    pipeline = stable_diffusion_pipeline(args)
    stable_diffusion_inference(pipeline)


    files = glob.glob("/home/huggingface/output/*.png")
    logging.info(f"files {files}")

    upload_name = 'uploads/texure.png'
    s3.upload_file(files[0], 'my-bucket', upload_name)

    status = 200
    return flask.Response(response=upload_name, status=status, mimetype="application/json")