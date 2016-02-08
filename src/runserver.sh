#!/bin/sh

echo "Starting server on port $SIMPLE_SERVER_PORT"
python -m SimpleHTTPServer $SIMPLE_SERVER_PORT
