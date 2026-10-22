"""The ``filetype`` command line.

Every capability of the desktop chooser is available here: identify a file,
list the applications that can consume it, open it, scan a directory for files
that need help, install or remove the desktop handler, and inspect the catalog.
The JSON output is the stable interface for other programs.
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import sys
from pathlib import Path

from . import paths
from .about_links import history_entries, load_history, save_history, state_path
from .application_catalog import (ApplicationCatalog, CatalogError, Recommendation,
                                  install_commands, preferred_install, recommend)
from .desktop_application import ApplicationIndex
from .desktop_integration import (handler_status, install_handler, uninstall_handler)
from .file_identifier import Identification, format_size, identify
from .file_launcher import (command_text, launch_application, open_default,
                            reveal_in_file_manager)
from .mime_index import TypeIndex, category_label
from .version import version_line

SCHEMA_VERSION = 1
EXIT_OK = 0
EXIT_FAILURE = 1
EXIT_USAGE = 2
EXIT_NOT_INSTALLED = 3
EXIT_NEEDS_ATTENTION = 4


def _json_requested(arguments) -> bool:
    return bool(getattr(arguments, "json", False) or getattr(arguments, "json_global", False))


def _print_json(document: dict[str, object]) -> None:
    document = {"schema": SCHEMA_VERSION, **document}
    print(json.dumps(document, indent=2, sort_keys=False))


def _truncate(value: str, width: int) -> str:
    value = " ".join(str(value).split())
    if 0 <= width and width < len(value):
        return value[:width - 1] + "…"
    return value


def _table(headers: list[str], rows: list[list[str]], widths: list[int] | None = None) -> str:
    widths = widths or [max(len(str(row[index])) for row in [headers, *rows])
                        for index in range(len(headers))]
    lines = []
    header_line = "  ".join(_truncate(headers[index], widths[index]).ljust(widths[index])
                            for index in range(len(headers)))
    lines.append(header_line)
    lines.append("  ".join("-" * widths[index] for index in range(len(headers))))
    for row in rows:
        lines.append("  ".join(_truncate(str(row[index]), widths[index]).ljust(widths[index])
                               for index in range(len(headers))))
    return "\n".join(lines)


def _app_line(application) -> list[str]:
    status = "installed" if application.installed else "available"
    if application.installed and not application.usable:
        status = "installed?"
    maturity = application.maturity
    popularity = "?" if application.popularity is None else str(application.popularity)
    return [status, application.name, maturity, popularity, application.purpose]


def _print_recommendation(recommendation: Recommendation, show_available: bool = True) -> None:
    identification = recommendation.identification
    print(f"{identification.path}")
    print(f"  Type:       {identification.description} ({identification.mime})")
    print(f"  Category:   {identification.category_label}")
    print(f"  Confidence: {identification.confidence_label} ({identification.confidence:.2f}) via {identification.source}")
    print(f"  Size:       {format_size(identification.size)}")
    if identification.magic.mime:
        print(f"  libmagic:   {identification.magic.mime}" +
              (f" / {identification.magic.encoding}" if identification.magic.encoding else ""))
    if identification.extension.mime:
        print(f"  Name:       .{identification.extension.suffix} -> {identification.extension.mime}")
    elif identification.extension.suffix:
        print(f"  Name:       .{identification.extension.suffix} is not a known extension")
    else:
        print("  Name:       no extension")
    if identification.conflict is not None:
        print(f"  Conflict:   {identification.conflict.get('explanation', '')}")
    print(f"  Default:    {recommendation.default.name if recommendation.default is not None else 'none'}")
    if recommendation.unhandled:
        print("  Attention:  no installed application can open this file.")
    print()
    if recommendation.installed:
        rows = [_app_line(application) for application in recommendation.installed]
        print("Installed applications")
        print(_table(["Status", "Application", "Maturity", "Popularity", "Purpose"], rows,
                     [11, 28, 10, 10, 58]))
    else:
        print("Installed applications: none")
    if show_available:
        print()
        if recommendation.available:
            rows = [_app_line(application) for application in recommendation.available]
            print("Applications worth installing")
            print(_table(["Status", "Application", "Maturity", "Popularity", "Purpose"], rows,
                         [11, 28, 10, 10, 58]))
        else:
            print("Applications worth installing: no catalog suggestion")
    if recommendation.notes:
        print()
        for note in recommendation.notes:
            if note:
                print(f"Note: {note}")


def _identification_document(identification: Identification,
                             recommendation: Recommendation | None = None) -> dict[str, object]:
    document = identification.to_dict()
    if recommendation is not None:
        document["applications"] = recommendation.to_dict()
    return document


def _load_context(path: str | None = None):
    index = TypeIndex.load()
    installed = ApplicationIndex(index=index)
    catalog = ApplicationCatalog.load()
    return index, installed, catalog


def command_identify(arguments) -> int:
    index, installed, catalog = _load_context()
    documents = []
    status = EXIT_OK
    for path in arguments.paths:
        identification = identify(path, index)
        if not identification.exists:
            status = EXIT_FAILURE
        recommendation = None
        if not arguments.no_apps:
            recommendation = recommend(identification, installed, catalog, index)
        if _json_requested(arguments):
            documents.append(_identification_document(identification, recommendation))
        else:
            if recommendation is not None:
                _print_recommendation(recommendation, show_available=arguments.apps)
            else:
                print(f"{identification.path}")
                print(f"  Type:     {identification.description} ({identification.mime})")
                print(f"  Category: {identification.category_label}")
                print(f"  Source:   {identification.source} ({identification.confidence:.2f})")
                for reason in identification.reasons:
                    print(f"  Why:      {reason}")
                print()
        if len(arguments.paths) > 1 and not _json_requested(arguments):
            print()
    if _json_requested(arguments):
        _print_json({"files": documents})
    return status


def command_apps(arguments) -> int:
    index, installed, catalog = _load_context()
    if arguments.mime:
        mime = arguments.mime
        extension = ""
        category = index.category(mime)
        description = index.description(mime)
        path = ""
        identification = None
    else:
        if not arguments.path:
            print("filetype apps: a FILE or --mime TYPE is required", file=sys.stderr)
            return EXIT_USAGE
        identification = identify(arguments.path, index)
        mime = identification.mime
        extension = identification.extension.suffix
        category = identification.category
        description = identification.description
        path = str(identification.path)
        if not identification.exists:
            print(f"filetype apps: no such file: {arguments.path}", file=sys.stderr)
            return EXIT_FAILURE
    if identification is not None:
        recommendation = recommend(identification, installed, catalog, index)
    else:
        from .file_identifier import Identification, MagicResult, ExtensionHint
        synthetic = Identification(
            path=Path(path or mime), mime=mime, description=description,
            category=category, category_label=category_label(category),
            source="mime", confidence=1.0, magic=MagicResult(mime=mime),
            extension=ExtensionHint(suffix=extension), exists=True,
        )
        recommendation = recommend(synthetic, installed, catalog, index)
    if _json_requested(arguments):
        _print_json({"path": path or None, "mime": mime, "description": description,
                     "applications": recommendation.to_dict()})
        return EXIT_OK
    print(f"{path or mime}: {description} ({mime})")
    print()
    if recommendation.installed:
        print("Installed applications")
        print(_table(["Status", "Application", "Maturity", "Popularity", "Purpose"],
                     [_app_line(application) for application in recommendation.installed],
                     [11, 28, 10, 10, 58]))
    else:
        print("Installed applications: none")
        print()
        print("Attention: no installed application can open this file.")
    if not arguments.installed_only and recommendation.available:
        print()
        print("Applications worth installing")
        rows = []
        for application in recommendation.available:
            methods = ", ".join(sorted(application.install)) or "no recorded package"
            rows.append(["available", application.name, application.maturity,
                         "?" if application.popularity is None else str(application.popularity),
                         f"{application.purpose} [{methods}]"])
        print(_table(["Status", "Application", "Maturity", "Popularity", "Purpose"],
                     rows, [11, 28, 10, 10, 78]))
    if recommendation.notes:
        print()
        for note in recommendation.notes:
            if note:
                print(f"Note: {note}")
    return EXIT_OK


def _find_application(recommendation: Recommendation, wanted: str):
    wanted_lower = wanted.casefold()
    for application in recommendation.all:
        if wanted in {application.identifier, application.desktop_id, application.name}:
            return application
        if wanted_lower == application.name.casefold() or wanted_lower == application.identifier.casefold():
            return application
    return None


def command_open(arguments) -> int:
    index, installed, catalog = _load_context()
    identification = identify(arguments.path, index)
    if not identification.exists:
        print(f"filetype open: no such file: {arguments.path}", file=sys.stderr)
        return EXIT_FAILURE
    if arguments.default:
        result = open_default(str(identification.path), dry_run=arguments.print_only)
        if _json_requested(arguments):
            _print_json({"result": result.to_dict()})
        else:
            print(result.message)
            if arguments.print_only:
                print(command_text(result.command))
        return EXIT_OK if result.ok else EXIT_FAILURE
    recommendation = recommend(identification, installed, catalog, index)
    if arguments.app:
        application = _find_application(recommendation, arguments.app)
    else:
        application = recommendation.default
        if application is None or not application.usable:
            application = next((item for item in recommendation.installed if item.usable), None)
    if application is None and arguments.app:
        candidates = [item for item in recommendation.available
                      if arguments.app.casefold() in {item.name.casefold(), item.identifier.casefold()}]
        if candidates:
            application = candidates[0]
    if application is None:
        if recommendation.unhandled:
            print("filetype open: no installed application can open this file.")
            print("Run 'filetype apps' to see what could be installed, or 'filetype choose' for the window.")
            return EXIT_NEEDS_ATTENTION
        print("filetype open: no application matched; use --app or --default.", file=sys.stderr)
        return EXIT_USAGE
    if not application.installed:
        print(f"filetype open: {application.name} is not installed.", file=sys.stderr)
        for entry in install_commands(application.catalog) if application.catalog else []:
            print(f"  {entry['command']}", file=sys.stderr)
        return EXIT_NOT_INSTALLED
    if not application.usable:
        print(f"filetype open: {application.name} is installed but not usable here.", file=sys.stderr)
        if application.catalog is not None:
            for entry in install_commands(application.catalog):
                print(f"  {entry['command']}", file=sys.stderr)
        return EXIT_FAILURE
    if application.desktop is None:
        print(f"filetype open: {application.name} has no desktop entry to launch.", file=sys.stderr)
        return EXIT_FAILURE
    result = launch_application(application.desktop, str(identification.path),
                                dry_run=arguments.print_only)
    if _json_requested(arguments):
        _print_json({"result": result.to_dict(), "application": application.to_dict()})
    else:
        print(result.message)
        if arguments.print_only:
            print(command_text(result.command))
    return EXIT_OK if result.ok else EXIT_FAILURE


def command_choose(arguments) -> int:
    if not arguments.path:
        print("filetype choose: a FILE is required", file=sys.stderr)
        return EXIT_USAGE
    try:
        from .gtk_chooser import run
    except Exception as error:
        print(f"filetype choose: the graphical chooser is unavailable: {error}", file=sys.stderr)
        return EXIT_FAILURE
    return run(arguments.path, self_test=arguments.self_test)


def command_handle(arguments) -> int:
    try:
        from .gtk_chooser import run
        return run(arguments.path, self_test=getattr(arguments, "self_test", False))
    except Exception as error:
        print(f"filetype handle: the graphical chooser is unavailable: {error}", file=sys.stderr)
        index = TypeIndex.load()
        identification = identify(arguments.path, index)
        print(f"{identification.path}: {identification.description} ({identification.mime})")
        return EXIT_FAILURE


def command_scan(arguments) -> int:
    index, installed, catalog = _load_context()
    roots = [Path(root).expanduser() for root in (arguments.directories or [str(Path.home() / "Downloads")])]
    files: list[dict[str, object]] = []
    counts = {"files": 0, "unhandled": 0, "handled": 0, "errors": 0, "skipped": 0}
    for root in roots:
        if not root.exists():
            counts["errors"] += 1
            if not _json_requested(arguments):
                print(f"filetype scan: no such directory: {root}", file=sys.stderr)
            continue
        if root.is_file():
            candidates = [root]
        else:
            candidates = []
            base_depth = len(root.parts)
            for directory, directories, names in os.walk(root, followlinks=False):
                depth = len(Path(directory).parts) - base_depth
                if 0 <= arguments.depth < depth:
                    directories[:] = []
                    continue
                if not arguments.include_hidden:
                    directories[:] = [name for name in directories if not name.startswith(".")]
                for name in sorted(names):
                    if not arguments.include_hidden and name.startswith("."):
                        continue
                    candidates.append(Path(directory) / name)
        for path in candidates:
            try:
                if not path.is_file() or path.is_symlink():
                    counts["skipped"] += 1
                    continue
            except OSError:
                counts["skipped"] += 1
                continue
            identification = identify(path, index)
            recommendation = recommend(identification, installed, catalog, index)
            counts["files"] += 1
            if recommendation.unhandled:
                counts["unhandled"] += 1
            else:
                counts["handled"] += 1
            if arguments.unhandled_only and not recommendation.unhandled:
                continue
            if _json_requested(arguments):
                files.append({
                    "path": str(identification.path),
                    "mime": identification.mime,
                    "description": identification.description,
                    "category": identification.category,
                    "size": identification.size,
                    "unhandled": recommendation.unhandled,
                    "default": recommendation.default.name if recommendation.default else "",
                    "installed_count": len([app for app in recommendation.installed if app.usable]),
                    "available_count": len(recommendation.available),
                })
            else:
                marker = "NEEDS HELP" if recommendation.unhandled else "ok"
                default = recommendation.default.name if recommendation.default else "none"
                print(f"{marker:10} {identification.mime:42} {identification.path}  (default: {default})")
        if arguments.limit and counts["files"] >= arguments.limit:
            break
    if _json_requested(arguments):
        _print_json({"roots": [str(root) for root in roots], "files": files, "summary": counts})
    else:
        print()
        print(f"Scanned {counts['files']} file(s): {counts['unhandled']} need help, "
              f"{counts['handled']} handled, {counts['skipped']} skipped, {counts['errors']} error(s).")
    if arguments.fail_on_unhandled and counts["unhandled"]:
        return EXIT_NEEDS_ATTENTION
    return EXIT_OK if not counts["errors"] else EXIT_FAILURE


def command_handler(arguments) -> int:
    if arguments.action == "status":
        status = handler_status()
        if _json_requested(arguments):
            _print_json({"handler": status.to_dict()})
        else:
            print(f"Handler installed: {'yes' if status.installed else 'no'}")
            print(f"  Desktop entry:   {status.desktop_entry} ({'present' if status.desktop_entry_present else 'missing'})")
            print(f"  Manifest:        {status.manifest_path}")
            print(f"  Icon:            {'present' if status.icon_present else 'missing'}")
            print(f"  File types:      {status.handler_mime_types}")
            print(f"  Defaults owned:  {status.defaults_owned}")
            print(f"  Still unhandled: {status.unhandled_types}")
            print(f"  Installed apps:  {status.installed_applications}")
            print(f"  Catalog apps:    {status.catalog_applications}")
            print(f"  Nautilus:        available={status.nautilus_available} installed={status.nautilus_installed}")
            for note in status.notes:
                print(f"  Note: {note}")
        return EXIT_OK if status.installed else EXIT_NOT_INSTALLED
    if arguments.action == "install":
        result = install_handler(set_defaults=not arguments.no_defaults,
                                 with_nautilus=not arguments.no_nautilus,
                                 dry_run=arguments.dry_run)
        if _json_requested(arguments):
            _print_json({"result": result.to_dict()})
        else:
            verb = "Would install" if result.dry_run else "Installed"
            print(f"{verb} the File Type Chooser.")
            print(f"  Desktop entry: {result.desktop_entry}")
            print(f"  Icon:          {result.icon}")
            print(f"  File types:    {result.handler_mime_types}")
            print(f"  Defaults set:  {result.defaults_set}")
            print(f"  Already had a handler: {result.already_handled}")
            if result.nautilus_extension:
                print(f"  Nautilus:      {result.nautilus_extension}")
            for note in result.notes:
                print(f"  Note: {note}")
            print()
            print("Double-clicking a file with no handler now opens this chooser.")
            print("Right-click a file and choose 'Choose Application…' when the Nautilus extension is active.")
        return EXIT_OK if result.ok else EXIT_FAILURE
    if arguments.action == "uninstall":
        result = uninstall_handler(dry_run=arguments.dry_run)
        if _json_requested(arguments):
            _print_json({"result": result.to_dict()})
        else:
            print(f"{'Would remove' if arguments.dry_run else 'Removed'} the File Type Chooser.")
            print(f"  Restored defaults: {result.restored_defaults}")
            print(f"  Kept user choices: {result.kept_user_defaults}")
            for path in result.removed_files:
                print(f"  {path}")
            for note in result.notes:
                print(f"  Note: {note}")
        return EXIT_OK if result.ok else EXIT_NOT_INSTALLED
    print(f"filetype handler: unknown action {arguments.action}", file=sys.stderr)
    return EXIT_USAGE


def command_catalog(arguments) -> int:
    try:
        catalog = ApplicationCatalog.load()
    except CatalogError as error:
        print(f"filetype catalog: {error}", file=sys.stderr)
        return EXIT_FAILURE
    if arguments.action == "stats":
        stats = catalog.stats()
        if _json_requested(arguments):
            _print_json({"catalog": stats})
        else:
            print(f"Catalog: {stats['path']}")
            print(f"  Applications: {stats['applications']}")
            print(f"  MIME patterns: {stats['mime_patterns']}")
            print(f"  Extensions:   {stats['extensions']}")
            print("  Categories:")
            for category, count in stats["categories"].items():  # type: ignore[union-attr]
                print(f"    {category_label(category):16} {count}")
        return EXIT_OK
    if arguments.action == "search":
        if not arguments.target:
            print("filetype catalog search: a QUERY is required", file=sys.stderr)
            return EXIT_USAGE
        results = catalog.search(arguments.target)
        if _json_requested(arguments):
            _print_json({"query": arguments.target,
                         "applications": [application.to_dict() for application in results]})
        else:
            print(_table(["Id", "Name", "Maturity", "Popularity", "Purpose"],
                         [[application.id, application.name, application.maturity,
                           str(application.popularity), application.purpose]
                          for application in results],
                         [35, 26, 10, 10, 70]))
        return EXIT_OK
    if arguments.action == "show":
        if not arguments.target:
            print("filetype catalog show: an ID is required", file=sys.stderr)
            return EXIT_USAGE
        application = catalog.get(arguments.target)
        if application is None:
            print(f"filetype catalog: no application {arguments.target}", file=sys.stderr)
            return EXIT_FAILURE
        if _json_requested(arguments):
            _print_json({"application": application.to_dict()})
        else:
            print(f"{application.name} ({application.id})")
            print(f"  Purpose:    {application.purpose}")
            print(f"  Kind:       {application.kind}")
            print(f"  Maturity:   {application.maturity}")
            print(f"  Popularity: {application.popularity}")
            print(f"  Usefulness: {application.usefulness}")
            print(f"  Handles:    {json.dumps(application.handles)}")
            for command in install_commands(application):
                print(f"  Install:    {command['command']}")
        return EXIT_OK
    if arguments.action == "validate":
        errors = []
        for application in catalog.applications:
            for pattern in application.mime_patterns:
                if "/" not in pattern:
                    errors.append(f"{application.id}: invalid MIME pattern {pattern}")
            for extension in application.extensions:
                if extension.startswith("."):
                    errors.append(f"{application.id}: extension should not start with a dot: {extension}")
        if errors:
            for error in errors:
                print(error, file=sys.stderr)
            return EXIT_FAILURE
        if _json_requested(arguments):
            _print_json({"valid": True, "applications": len(catalog.applications)})
        else:
            print(f"Catalog valid: {len(catalog.applications)} applications, "
                  f"{catalog.stats()['mime_patterns']} MIME patterns, "
                  f"{catalog.stats()['extensions']} extensions.")
        return EXIT_OK
    print(f"filetype catalog: unknown action {arguments.action}", file=sys.stderr)
    return EXIT_USAGE


def command_about_history(arguments) -> int:
    if arguments.clear:
        save_history({"version": 1, "sites": {}})
        if not _json_requested(arguments):
            print(f"Cleared the About history: {state_path()}")
        else:
            _print_json({"cleared": True, "path": str(state_path()), "history": []})
        return EXIT_OK
    entries = history_entries()
    if arguments.limit:
        entries = entries[:arguments.limit]
    if _json_requested(arguments):
        _print_json({"path": str(state_path()), "history": entries,
                     "count": len(entries)})
        return EXIT_OK
    if not entries:
        print(f"No About visits recorded yet ({state_path()}).")
        return EXIT_OK
    print(_table(["Checked", "Status", "URL"],
                 [[entry["last_checked"], "ok" if entry["ok"] else "failed", entry["url"]]
                  for entry in entries], [12, 8, 90]))
    print(f"\nHistory: {state_path()}")
    return EXIT_OK


def command_types(arguments) -> int:
    index = TypeIndex.load()
    if arguments.mime:
        mime = index.canonical(arguments.mime)
        info = {
            "mime": mime,
            "description": index.description(mime),
            "category": index.category(mime),
            "aliases": index.aliases_for(mime),
            "parents": index.ancestors(mime),
            "extensions": index.extensions_for(mime),
        }
        if _json_requested(arguments):
            _print_json({"type": info})
        else:
            for key, value in info.items():
                print(f"{key:12} {value}")
        return EXIT_OK
    if arguments.extension:
        match = index.lookup_extension_name(arguments.extension)
        if match is None:
            print(f"filetype types: no type for extension {arguments.extension}", file=sys.stderr)
            return EXIT_FAILURE
        alternatives = [item for item in index.lookup_extension(f"name.{match.extension}")[1:]]
        if _json_requested(arguments):
            _print_json({"extension": {"extension": match.extension, "mime": match.mime,
                                       "description": match.description,
                                       "alternatives": [
                                           {"mime": item.mime, "description": item.description}
                                           for item in alternatives
                                       ]}})
        else:
            print(f".{match.extension}  {match.mime}  {match.description}")
        return EXIT_OK
    entries = []
    for extension in sorted(index.extension_map):
        types = index.extension_map[extension]
        if not types:
            continue
        entries.append({"extension": extension, "mime": types[0],
                        "description": index.description(types[0])})
    limit = arguments.limit or len(entries)
    entries = entries[:limit]
    if _json_requested(arguments):
        _print_json({"types": entries, "total": index.type_count(),
                     "extensions": index.extension_count()})
    else:
        print(_table(["Extension", "MIME type", "Description"],
                     [[f".{entry['extension']}", entry["mime"], entry["description"]]
                      for entry in entries], [14, 48, 60]))
        print(f"\n{index.type_count()} MIME types, {index.extension_count()} extensions, "
              f"{len(index.globs)} glob rules.")
    return EXIT_OK


def command_doctor(arguments) -> int:
    index = TypeIndex.load()
    installed = ApplicationIndex(index=index)
    try:
        catalog = ApplicationCatalog.load()
        catalog_error = ""
    except CatalogError as error:
        catalog = None
        catalog_error = str(error)
    status = handler_status(index, installed)
    checks: list[dict[str, str]] = []

    def check(name: str, ok: bool, detail: str, level: str = "fail") -> None:
        checks.append({"check": name, "status": "PASS" if ok else ("WARN" if level == "warn" else "FAIL"),
                       "detail": detail})

    check("file utility", shutil.which("file") is not None,
          shutil.which("file") or "not found; identification falls back to the name")
    check("MIME database", index.type_count() > 0,
          f"{index.type_count()} types, {index.extension_count()} extensions")
    check("desktop entries", len(installed.entries) > 0,
          f"{len(installed.entries)} applications")
    check("catalog", catalog is not None,
          catalog_error or (f"{len(catalog.applications)} applications" if catalog else ""))
    try:
        import gi
        gi.require_version("Gtk", "4.0")
        from gi.repository import Gtk  # noqa: F401
        gtk_ok, gtk_detail = True, "GTK4 available"
    except Exception as error:
        gtk_ok, gtk_detail = False, f"GTK4 unavailable: {error}"
    check("GTK4", gtk_ok, gtk_detail, level="warn")
    adwaita = _module_available("Adw", "1")
    check("libadwaita", adwaita,
          "libadwaita available" if adwaita else "libadwaita unavailable; plain GTK4 is used",
          level="warn")
    check("Nautilus extension", status.nautilus_available,
          "python3-nautilus available" if status.nautilus_available
          else "python3-nautilus is missing; use Open With or the command line",
          level="warn")
    check("handler", status.installed,
          f"{status.defaults_owned} defaults owned, {status.unhandled_types} types still unhandled",
          level="warn")
    if status.unhandled_types and status.installed:
        checks.append({"check": "coverage", "status": "WARN",
                       "detail": f"{status.unhandled_types} known types still have no installed handler; "
                                 "the chooser covers them"})
    failures = [item for item in checks if item["status"] == "FAIL"]
    if _json_requested(arguments):
        _print_json({"checks": checks, "ok": not failures})
    else:
        for item in checks:
            print(f"{item['status']:4}  {item['check']:20} {item['detail']}")
    return EXIT_OK if not failures else EXIT_FAILURE


def _module_available(namespace: str, version: str) -> bool:
    try:
        import gi
        gi.require_version(namespace, version)
        __import__("gi.repository", fromlist=[namespace])
    except Exception:
        return False
    return True


def command_version(arguments) -> int:
    print(version_line("filetype"))
    return EXIT_OK


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="filetype",
        description="Identify a file, find every application that can open it, and offer choices on the GNOME desktop.",
    )
    parser.add_argument("--version", action="version", version=version_line("filetype"))
    parser.add_argument("--json", action="store_true", dest="json_global",
                        help="print the machine-readable JSON document")
    subparsers = parser.add_subparsers(dest="command", required=True)

    identify_parser = subparsers.add_parser("identify", help="identify files and list applications")
    identify_parser.add_argument("paths", nargs="+", metavar="FILE")
    identify_parser.add_argument("--json", action="store_true")
    identify_parser.add_argument("--no-apps", action="store_true", help="identify only; do not rank applications")
    identify_parser.add_argument("--apps", action="store_true", help="also list the applications worth installing")
    identify_parser.set_defaults(function=command_identify)

    apps_parser = subparsers.add_parser("apps", help="list the applications that can open a file or type")
    apps_parser.add_argument("path", nargs="?", metavar="FILE")
    apps_parser.add_argument("--mime", help="ask about a MIME type instead of a file")
    apps_parser.add_argument("--installed-only", action="store_true")
    apps_parser.add_argument("--json", action="store_true")
    apps_parser.set_defaults(function=command_apps)

    open_parser = subparsers.add_parser("open", help="open a file with a chosen application")
    open_parser.add_argument("path", metavar="FILE")
    open_parser.add_argument("--app", help="application name, desktop id, or catalog id")
    open_parser.add_argument("--default", action="store_true", help="use the desktop default")
    open_parser.add_argument("--print", action="store_true", dest="print_only",
                             help="print the command and do not start anything")
    open_parser.add_argument("--json", action="store_true")
    open_parser.set_defaults(function=command_open)

    choose_parser = subparsers.add_parser("choose", help="open the graphical chooser")
    choose_parser.add_argument("path", nargs="?", metavar="FILE")
    choose_parser.add_argument("--self-test", action="store_true", help=argparse.SUPPRESS)
    choose_parser.set_defaults(function=command_choose)

    handle_parser = subparsers.add_parser("handle", help="the desktop entry point")
    handle_parser.add_argument("path", metavar="FILE")
    handle_parser.add_argument("--self-test", action="store_true", help=argparse.SUPPRESS)
    handle_parser.set_defaults(function=command_handle)

    scan_parser = subparsers.add_parser("scan", help="find files that no installed application can open")
    scan_parser.add_argument("directories", nargs="*", metavar="DIRECTORY")
    scan_parser.add_argument("--unhandled-only", action="store_true")
    scan_parser.add_argument("--include-hidden", action="store_true")
    scan_parser.add_argument("--depth", type=int, default=-1, help="maximum depth below each directory")
    scan_parser.add_argument("--limit", type=int, default=0, help="stop after this many files")
    scan_parser.add_argument("--fail-on-unhandled", action="store_true",
                             help="exit 4 when at least one file needs help")
    scan_parser.add_argument("--json", action="store_true")
    scan_parser.set_defaults(function=command_scan)

    handler_parser = subparsers.add_parser("handler", help="install, remove, or inspect the desktop handler")
    handler_parser.add_argument("action", choices=("status", "install", "uninstall"))
    handler_parser.add_argument("--dry-run", action="store_true")
    handler_parser.add_argument("--no-defaults", action="store_true",
                                help="register the entry but do not set defaults for unhandled types")
    handler_parser.add_argument("--no-nautilus", action="store_true")
    handler_parser.add_argument("--json", action="store_true")
    handler_parser.set_defaults(function=command_handler)

    catalog_parser = subparsers.add_parser("catalog", help="inspect the curated application catalog")
    catalog_parser.add_argument("action", choices=("stats", "search", "show", "validate"))
    catalog_parser.add_argument("target", nargs="?", metavar="QUERY|ID")
    catalog_parser.add_argument("--json", action="store_true")
    catalog_parser.set_defaults(function=command_catalog)

    history_parser = subparsers.add_parser(
        "about-history", help="list the About sites visited, their date, and their result")
    history_parser.add_argument("--limit", type=int, default=0)
    history_parser.add_argument("--clear", action="store_true",
                                help="forget the recorded visits")
    history_parser.add_argument("--json", action="store_true")
    history_parser.set_defaults(function=command_about_history)

    types_parser = subparsers.add_parser("types", help="inspect the MIME database and extension index")
    types_parser.add_argument("--mime", help="describe one MIME type")
    types_parser.add_argument("--ext", "--extension", dest="extension", help="describe one extension")
    types_parser.add_argument("--limit", type=int, default=0)
    types_parser.add_argument("--json", action="store_true")
    types_parser.set_defaults(function=command_types)

    doctor_parser = subparsers.add_parser("doctor", help="check this machine's file-type support")
    doctor_parser.add_argument("--json", action="store_true")
    doctor_parser.set_defaults(function=command_doctor)

    version_parser = subparsers.add_parser("version", help="print the build version")
    version_parser.set_defaults(function=command_version)
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    arguments = parser.parse_args(argv)
    try:
        return int(arguments.function(arguments))
    except BrokenPipeError:
        return EXIT_OK
    except CatalogError as error:
        print(f"filetype: {error}", file=sys.stderr)
        return EXIT_FAILURE
    except KeyboardInterrupt:
        return 130


if __name__ == "__main__":
    raise SystemExit(main())
