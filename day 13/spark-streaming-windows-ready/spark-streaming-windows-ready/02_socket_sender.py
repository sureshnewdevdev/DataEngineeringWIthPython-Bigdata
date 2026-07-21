"""Windows socket sender used instead of the Linux nc command."""

import socket


HOST = "127.0.0.1"
PORT = 9999

with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as server:
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind((HOST, PORT))
    server.listen(1)

    print(f"Waiting for Spark to connect at {HOST}:{PORT}")
    connection, address = server.accept()

    with connection:
        print("Spark connected:", address)
        print("Type a sentence and press Enter. Press Ctrl+C to stop.")

        try:
            while True:
                message = input("stream> ").strip()
                if message:
                    connection.sendall((message + "\n").encode("utf-8"))
        except (KeyboardInterrupt, BrokenPipeError):
            print("\nSocket sender stopped.")

