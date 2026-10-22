"""GNOME file type integration.

The package identifies a file from its content and its name, ranks the
applications that can consume it, and registers a GNOME handler that offers
those applications when the desktop has none.
"""

from .version import version_string

__all__ = ["version_string"]
