import os
import glob
import json
import torch
import logging

import boto3
from botocore.client import Config

from stable_diffusion import stable_diffusion_inference, stable_diffusion_pipeline

from pydantic import BaseModel, ValidationError, PrivateAttr
from typing import Optional

import asyncio
from fastapi import FastAPI
import aio_pika
from aio_pika import connect_robust

import redis

app = FastAPI()
loop = asyncio.get_event_loop()


logging.basicConfig(level=logging.INFO, force=True)
# app = flask.Flask(__name__)

print(f"torch cuda version {torch.version.cuda}") 
print(f"cuda is_available:  {torch.cuda.is_available()}")   

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

rdb = redis.Redis(host=os.environ['REDIS_HOST'], port=6379, decode_responses=True)

COMPLETED_STATUS = "completed"
IN_PROGRESS_STATUS = "in_progress"

@app.get("/ping")
def ping():
    """Determine if the container is working and healthy."""
    return {"status": "ok"}

async def handle_task(message: aio_pika.IncomingMessage):
    body_decoded = message.body.decode()
    logging.info(f" [x] Received: {body_decoded}")

    try:
        json_data = json.loads(body_decoded)
        logging.info(f"json_data {json_data}")
        args = InferenceArgsModel(**json_data)
    except ValidationError as e:
        logging.error(f"ValidationError {e}")
        return {"error": e.errors()}, 400
    
    logging.info(args)

    rdb.set(json_data['task_id'], IN_PROGRESS_STATUS)

    pipeline =   await asyncio.to_thread(stable_diffusion_pipeline, args)
    await asyncio.to_thread(stable_diffusion_inference, pipeline)

    files = glob.glob("/home/huggingface/output/*.png")
    logging.info(f"files {files}")

    upload_name = 'uploads/texure.png'
    s3.upload_file(files[0], 'my-bucket', upload_name)

    rdb.set(json_data['task_id'], COMPLETED_STATUS)

async def consume():
    while True:
        try:
            # Connect to RabbitMQ server (localhost by default)
            logging.info(f'RABBIT_MQ_ADDRESS ={os.environ.get("RABBIT_MQ_ADDRESS")}')
            connection = await connect_robust(os.environ.get("RABBIT_MQ_ADDRESS"))
            channel = await connection.channel()
            await channel.set_qos(prefetch_count=1)
            queue = await channel.get_queue('ml_task_queue', ensure=False)

            async with queue.iterator() as queue_iter:
                async for message in queue_iter:
                    async with message.process():
                        await handle_task(message)

        except Exception as e:
            logging.error(f"Connection or consume error: {e}")
            logging.info("Reconnecting in 5 seconds...")
            await asyncio.sleep(5)  # backoff before retry
            