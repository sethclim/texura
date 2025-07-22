
import threading
from app import Consumer, app
from waitress import serve


def main():

    conusmer = Consumer()

    threading.Thread(target=conusmer.start, daemon=True).start()

    serve(app, host="0.0.0.0", port=8080)


if __name__ == "__main__":
    main()
