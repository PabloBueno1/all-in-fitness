# Use latest Flutter stable image
FROM ghcr.io/cirruslabs/flutter:latest

# Set working directory
WORKDIR /app
COPY . .

# Fix "dubious ownership" issue
RUN git config --global --add safe.directory /sdks/flutter

# Ensure Flutter runs as a non-root user and set correct permissions
RUN useradd -ms /bin/bash flutteruser \
    && chown -R flutteruser:flutteruser /app /sdks/flutter \
    && chmod -R 777 /app /sdks/flutter

# Switch to non-root user
USER flutteruser

# Run Flutter doctor
RUN flutter doctor

# Install dependencies
RUN flutter pub get

CMD ["flutter", "run", "-d", "web-server", "--web-hostname=0.0.0.0", "--web-port=8080"]
