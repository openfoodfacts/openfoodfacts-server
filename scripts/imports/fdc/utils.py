from datetime import datetime


def convert_to_seconds(date_t: str) -> int:
    """Converts a mm/dd/yyyy date string to a Unix timestamp (seconds)"""
    format_string = "%m/%d/%Y"
    date_object = datetime.strptime(date_t, format_string)

    return int(date_object.timestamp())
