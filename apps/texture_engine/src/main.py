
from app import app


def main():
    from waitress import serve

    serve(app, host="0.0.0.0", port=8080)


if __name__ == "__main__":
    main()
