
import asyncio
import uvicorn

from app import app, consume

async def main():
    # threading.Thread(target=conusmer.start, daemon=True).start()
    # serve(app, host="0.0.0.0", port=8080)

    task1 = asyncio.create_task(consume())
    config = uvicorn.Config(app, host="0.0.0.0", port=8080)
    server = uvicorn.Server(config)
    task2 = asyncio.create_task(server.serve())

    await asyncio.gather(task1, task2)


if __name__ == "__main__":
  asyncio.run(main())
