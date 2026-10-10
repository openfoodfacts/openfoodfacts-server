"""
Read configuration values from .env files. This does not seem
very useful at the moment, but it costs nothing and we may
do something smarter in the future.
"""
from dotenv import dotenv_values


def cfg() -> dict:
    d = dotenv_values(".env")
    return d

