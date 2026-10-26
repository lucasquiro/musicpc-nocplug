"""EN: Provides safe MPD-library file operations for the MusicPC Luau entries.
ES: Proporciona operaciones seguras de archivos de la biblioteca MPD a las entradas Luau de MusicPC."""

import hashlib
import json
import os
import re
import shlex
import socket
import stat
import subprocess
import sys
import tempfile
from pathlib import Path


TAG_NAMES = {
    "title": "title",
    "artist": "artist",
    "album": "album",
    "album_artist": "album_artist",
    "date": "date",
    "genre": "genre",
    "track": "track",
    "disc": "disc",
    "composer": "composer",
    "performer": "performer",
    "publisher": "publisher",
    "bpm": "bpm",
    "comment": "comment",
}


# --- EN: Resolves MPD's configured music directory from its server or common config files.
# --- ES: Resuelve el directorio musical de MPD desde el servidor o archivos de configuración habituales.
def mpd_config():
    host_setting = os.environ.get("MPD_HOST", "localhost")
    password = None
    if "@" in host_setting and not host_setting.startswith("/"):
        password, host_setting = host_setting.rsplit("@", 1)
    port = int(os.environ.get("MPD_PORT", "6600"))
    response = []
    connection = None
    try:
        connection = socket.socket(socket.AF_UNIX if host_setting.startswith("/") else socket.AF_INET)
        connection.settimeout(3)
        if host_setting.startswith("/"):
            connection.connect(host_setting)
        else:
            connection.connect((host_setting or "localhost", port))
        stream = connection.makefile("rwb", buffering=0)
        greeting = stream.readline().decode("utf-8", "replace")
        if not greeting.startswith("OK MPD "):
            raise RuntimeError("MPD no respondió correctamente")
        if password:
            escaped = password.replace("\\", "\\\\").replace('"', '\\"')
            stream.write(f'password "{escaped}"\n'.encode())
            if stream.readline().startswith(b"ACK"):
                raise RuntimeError("MPD rechazó la contraseña configurada")
        stream.write(b"config\n")
        while True:
            line = stream.readline().decode("utf-8", "replace")
            if line == "OK\n" or line == "OK":
                break
            if not line or line.startswith("ACK"):
                break
            response.append(line.rstrip("\r\n"))
        stream.close()
    except (OSError, RuntimeError, socket.timeout):
        pass
    finally:
        if connection is not None:
            connection.close()
    music_directory = None
    for line in response:
        if line.startswith("music_directory:"):
            value = line.split(":", 1)[1].strip()
            parsed = shlex.split(value)
            if parsed:
                music_directory = parsed[0]
                break
    if music_directory:
        candidate = Path(music_directory).expanduser()
        if candidate.is_dir():
            return candidate.resolve(strict=True)

    config_paths = [
        Path.home() / ".config/mpd/mpd.conf",
        Path.home() / ".mpdconf",
        Path("/etc/mpd.conf"),
        Path("/etc/mpd/mpd.conf"),
    ]
    for config_path in config_paths:
        try:
            contents = config_path.read_text(encoding="utf-8")
        except OSError:
            continue
        match = re.search(r"^\s*music_directory\s+(.+?)\s*(?:#.*)?$", contents, re.MULTILINE)
        if not match:
            continue
        parsed = shlex.split(match.group(1))
        if not parsed:
            continue
        candidate = Path(parsed[0]).expanduser()
        if not candidate.is_absolute():
            candidate = config_path.parent / candidate
        if candidate.is_dir():
            return candidate.resolve(strict=True)
    raise RuntimeError("No se pudo resolver music_directory de MPD; revisa MPD_HOST o mpd.conf")


# --- EN: Confines a relative track URI to the resolved MPD library and returns its path and root.
# --- ES: Restringe una URI relativa a la biblioteca MPD y devuelve su ruta y raíz.
def resolve_track(uri):
    root = mpd_config()
    relative = Path(uri)
    if relative.is_absolute():
        raise RuntimeError("La ruta debe ser relativa a la biblioteca MPD")
    path = (root / relative).resolve(strict=True)
    if not path.is_file() or not path.is_relative_to(root):
        raise RuntimeError("El archivo no pertenece a la biblioteca MPD")
    return path, root


# --- EN: Reads supported audio tags with ffprobe and returns normalized string values.
# --- ES: Lee etiquetas admitidas con ffprobe y devuelve valores de texto normalizados.
def read_tags(uri):
    path, _root = resolve_track(uri)
    result = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format_tags", "-of", "json", str(path)],
        check=True,
        capture_output=True,
        text=True,
    )
    data = json.loads(result.stdout)
    raw = (data.get("format") or {}).get("tags") or {}
    normalized = {key.casefold(): value for key, value in raw.items()}
    return {key: normalized.get(name.casefold(), "") for key, name in TAG_NAMES.items()}


# --- EN: Rewrites MP3 tags and optionally renames the file with validated atomic replacement.
# --- ES: Reescribe etiquetas MP3 y opcionalmente renombra el archivo con reemplazo atómico validado.
def save_tags(uri, values, overwrite=False):
    path, root = resolve_track(uri)
    if path.suffix.casefold() != ".mp3":
        raise RuntimeError("La edición de metadatos está limitada a archivos MP3")
    if not isinstance(values, dict):
        raise RuntimeError("Los metadatos deben ser un objeto")
    filename = values.pop("_filename", path.name)
    if (
        not isinstance(filename, str)
        or not filename
        or Path(filename).name != filename
        or filename in {".", ".."}
        or re.fullmatch(r"[^\x00-\x1f/\\]+", filename) is None
    ):
        raise RuntimeError("El nombre debe ser un nombre de archivo, sin carpetas")
    destination = path.with_name(filename)
    if destination.suffix.casefold() != ".mp3":
        raise RuntimeError("El archivo debe conservar la extensión .mp3")
    if destination != path and destination.exists() and not overwrite:
        raise RuntimeError("DEST_EXISTS: ya existe un archivo con ese nombre")
    original_mode = stat.S_IMODE(path.stat().st_mode)
    descriptor, temporary_name = tempfile.mkstemp(prefix=".musicpc-", suffix=".mp3", dir=path.parent)
    os.close(descriptor)
    os.unlink(temporary_name)
    command = ["ffmpeg", "-nostdin", "-v", "error", "-y", "-i", str(path), "-map", "0", "-c", "copy", "-id3v2_version", "3"]
    for key, ffmpeg_name in TAG_NAMES.items():
        value = values.get(key, "")
        if not isinstance(value, str):
            raise RuntimeError(f"El metadato {key} debe ser texto")
        command.extend(["-metadata", f"{ffmpeg_name}={value}"])
    command.append(temporary_name)
    try:
        subprocess.run(command, check=True, capture_output=True, text=True)
        os.chmod(temporary_name, original_mode)
        if destination == path or overwrite:
            os.replace(temporary_name, destination)
        else:
            try:
                os.link(temporary_name, destination)
            except FileExistsError:
                raise RuntimeError("DEST_EXISTS: ya existe un archivo con ese nombre")
            os.unlink(temporary_name)
        if destination != path:
            path.unlink()
    finally:
        if os.path.exists(temporary_name):
            os.unlink(temporary_name)
    updated_uri = destination.relative_to(root).as_posix()
    subprocess.run(["mpc", "update"], check=False, capture_output=True)
    return updated_uri


# --- EN: Checks whether a file starts with a supported image format signature.
# --- ES: Comprueba si un archivo empieza con la firma de un formato de imagen compatible.
def has_image_signature(path):
    try:
        with open(path, "rb") as image_file:
            header = image_file.read(16)
    except OSError:
        return False
    return (
        header.startswith(b"\x89PNG\r\n\x1a\n")
        or header.startswith((b"\xff\xd8\xff", b"GIF87a", b"GIF89a", b"BM", b"II*\x00", b"MM\x00*"))
        or (header.startswith(b"RIFF") and header[8:12] == b"WEBP")
        or (header[4:8] == b"ftyp" and header[8:12] in {b"avif", b"avis"})
    )


# --- EN: Fetches embedded artwork using mpc and stores valid images in a per-plugin cache.
# --- ES: Obtiene carátula incrustada con mpc y guarda imágenes válidas en la caché del plugin.
def fetch_cover(uri, cache_directory):
    cache = Path(cache_directory)
    cache.mkdir(parents=True, exist_ok=True)
    destination = cache / (hashlib.sha256(uri.encode("utf-8")).hexdigest() + ".cover")
    if not has_image_signature(destination):
        destination.unlink(missing_ok=True)
        descriptor, temporary_name = tempfile.mkstemp(prefix=".cover-", dir=cache)
        try:
            with os.fdopen(descriptor, "wb") as output:
                result = subprocess.run(["mpc", "readpicture", uri], stdout=output, stderr=subprocess.PIPE)
                if result.returncode != 0 or not has_image_signature(temporary_name):
                    output.seek(0)
                    output.truncate()
                    result = subprocess.run(["mpc", "albumart", uri], stdout=output, stderr=subprocess.PIPE)
            if result.returncode != 0 or not has_image_signature(temporary_name):
                os.unlink(temporary_name)
                print("")
                return
            os.replace(temporary_name, destination)
        finally:
            if os.path.exists(temporary_name):
                os.unlink(temporary_name)
    print(destination)


# --- EN: Moves a validated library track to the desktop trash and requests an MPD update.
# --- ES: Mueve una pista validada a la papelera del escritorio y solicita actualizar MPD.
def trash_track(uri):
    path, _root = resolve_track(uri)
    subprocess.run(["gio", "trash", str(path)], check=True, capture_output=True, text=True)
    subprocess.run(["mpc", "update"], check=False, capture_output=True)


# --- EN: Streams enough mpc listall output to build one page and nearby pagination metadata.
# --- ES: Lee suficiente salida de mpc listall para construir una página y metadatos de paginación próximos.
def list_library_page(page, page_size):
    page = max(1, int(page))
    page_size = min(100, max(1, int(page_size)))
    start = (page - 1) * page_size
    scan_limit = start + page_size * 3 + 1
    tracks = []
    scanned = 0
    process = subprocess.Popen(
        ["mpc", "listall"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    stopped_early = False
    for line in process.stdout:
        uri = line.rstrip("\r\n")
        if not uri:
            continue
        scanned += 1
        if start < scanned <= start + page_size:
            tracks.append(uri)
        if scanned >= scan_limit:
            stopped_early = True
            process.terminate()
            break
    process.stdout.close()
    error = process.stderr.read()
    process.stderr.close()
    return_code = process.wait()
    if return_code != 0 and not stopped_early:
        raise RuntimeError(error.strip() or "No se pudo leer la biblioteca de MPD")

    first_page = page
    last_page = page + 2
    pages = [number for number in range(first_page, last_page + 1) if scanned > (number - 1) * page_size]
    return {
        "page": page,
        "tracks": tracks,
        "pages": pages,
        "hasPrevious": page > 1,
        "hasNext": scanned > page * page_size,
        "hasMorePages": scanned > (page + 2) * page_size,
    }


# --- EN: Waits for MPD to rescan its library before returning the requested page.
# --- ES: Espera a que MPD reescanee la biblioteca antes de devolver la página solicitada.
def refresh_library_page(page, page_size):
    result = subprocess.run(
        ["mpc", "--wait", "update"],
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or "No se pudo actualizar la biblioteca de MPD")
    return list_library_page(page, page_size)


# --- EN: Dispatches the requested helper operation using argv parameters; prints data or raises on failure.
# --- ES: Ejecuta la operación solicitada con parámetros argv; imprime datos o lanza un error.
def main():
    action = sys.argv[1]
    if action == "cover":
        fetch_cover(sys.argv[2], sys.argv[3])
    elif action == "tags":
        print(json.dumps(read_tags(sys.argv[2]), ensure_ascii=False))
    elif action == "save":
        values = json.loads(sys.argv[3])
        overwrite = len(sys.argv) > 4 and sys.argv[4] == "--overwrite"
        print(save_tags(sys.argv[2], values, overwrite))
    elif action == "trash":
        trash_track(sys.argv[2])
    elif action == "library-page":
        print(json.dumps(list_library_page(sys.argv[2], sys.argv[3]), ensure_ascii=False))
    elif action == "library-refresh":
        print(json.dumps(refresh_library_page(sys.argv[2], sys.argv[3]), ensure_ascii=False))
    else:
        raise RuntimeError("Acción de archivo desconocida")


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, ValueError, subprocess.CalledProcessError, json.JSONDecodeError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)