#!/bin/bash
# Download spaCy model if not present
python -m spacy download en_core_web_sm
# Start server
uvicorn main:app --host 0.0.0.0 --port ${PORT:-8000}
