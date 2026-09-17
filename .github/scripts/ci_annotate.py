#!/usr/bin/env python3
"""Publica los resultados de flutter analyze/test/build como anotaciones
del check-run del job actual, para que sean legibles desde la API de
GitHub (los logs crudos del runner no siempre están accesibles).

IMPORTANTE: este script es BEST-EFFORT. Ningún error de API (token,
check-run no encontrado, rate limit) debe enmascarar el resultado real
del gate, que lo da el paso de flutter directamente. Por eso toda la
interacción con la API está rodeada de try/except y, en el peor caso,
el script termina en 0 con un aviso.

Uso:
  python3 ci_annotate.py --mode analyze [--machine analyze_machine.jsonl --human analyze_human.txt]
  python3 ci_annotate.py --mode tail --file <archivo> [--exit-code <n>]

Sin dependencias externas (solo stdlib).
"""
import argparse
import json
import os
import sys
import urllib.request


def api(method, path, payload=None):
    """Llamada a la API con tolerancia a fallos: devuelve None en error."""
    url = "https://api.github.com/" + path
    data = json.dumps(payload).encode() if payload is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Authorization", "Bearer " + os.environ["GITHUB_TOKEN"])
    req.add_header("Accept", "application/vnd.github+json")
    if data is not None:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req) as resp:
            return json.load(resp)
    except Exception as e:
        print("ci_annotate: API error en {} {}: {}".format(method, path, e))
        return None


def find_check_run_id(repo, sha, job_name):
    body = api("GET", "repos/{}/commits/{}/check-runs".format(repo, sha))
    if not body:
        return None
    for cr in body.get("check_runs", []):
        if cr.get("name") == job_name:
            return cr["id"]
    return None


def post_annotations(cr_id, annotations):
    for i in range(0, len(annotations), 50):
        api(
            "POST",
            "repos/{}/check-runs/{}/annotations".format(
                os.environ["GITHUB_REPOSITORY"], cr_id
            ),
            {"annotations": annotations[i : i + 50]},
        )


def mode_analyze(cr_id, args):
    annotations = []
    if os.path.exists(args.machine):
        with open(args.machine, encoding="utf-8", errors="replace") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                except Exception:
                    continue
                if obj.get("type") not in ("error", "warning", "info"):
                    continue
                level = {
                    "error": "failure",
                    "warning": "warning",
                    "info": "notice",
                }[obj["type"]]
                rng = (obj.get("range") or {}).get("start") or {}
                line_no = int(rng.get("line", 0)) + 1
                annotations.append(
                    {
                        "path": obj.get("file") or "",
                        "start_line": line_no,
                        "end_line": line_no,
                        "annotation_level": level,
                        "title": obj.get("code") or "analyzer",
                        "message": (obj.get("message") or "")[:60000],
                    }
                )

    human = ""
    if os.path.exists(args.human):
        with open(args.human, encoding="utf-8", errors="replace") as f:
            human = f.read()

    if not annotations:
        # Sin datos máquina: o el proyecto está limpio (flutter analyze
        # --machine no escribe issues) o algo falló y hay que ver el log.
        if human.strip() and "No issues found!" not in human:
            annotations.append(
                {
                    "path": ".github/workflows/flutter-ci.yml",
                    "start_line": 1,
                    "end_line": 1,
                    "annotation_level": "warning",
                    "title": "flutter analyze (salida inesperada)",
                    "message": human[-60000:],
                }
            )
            # Salida no reconocida: no se considera limpio.
            has_error = "error" in human.lower()
            has_warning = True
        else:
            has_error = False
            has_warning = False
    else:
        has_error = any(a["annotation_level"] == "failure" for a in annotations)
        has_warning = any(a["annotation_level"] == "warning" for a in annotations)

    if cr_id is not None and annotations:
        post_annotations(cr_id, annotations)
    print(
        "ci_annotate: {} anotaciones (error={}, warning={})".format(
            len(annotations), has_error, has_warning
        )
    )
    # SOLO informativo: el gate real lo da el paso `flutter analyze`.
    # Este script nunca debe fallear el job por su propia cuenta.
    sys.exit(0)


def mode_tail(cr_id, args):
    if not os.path.exists(args.file):
        print("ci_annotate: falta el archivo de salida, nada que anotar")
        sys.exit(0)
    with open(args.file, encoding="utf-8", errors="replace") as f:
        content = f.read()

    if args.exit_code == 0:
        tail = "\n".join(content.splitlines()[-15:])
        annotations = [
            {
                "path": ".github/workflows/flutter-ci.yml",
                "start_line": 1,
                "end_line": 1,
                "annotation_level": "notice",
                "title": "resultado del paso (best effort)",
                "message": tail[-60000:],
            }
        ]
    else:
        tail_lines = content.splitlines()[-200:]
        annotations = [
            {
                "path": ".github/workflows/flutter-ci.yml",
                "start_line": 1,
                "end_line": 1,
                "annotation_level": "failure",
                "title": "paso fallido (últimas 200 líneas)",
                "message": "\n".join(tail_lines)[:60000],
            }
        ]

    if cr_id is not None:
        post_annotations(cr_id, annotations)
    print("ci_annotate: anotación publicada (best effort)")
    # SOLO informativo: el gate real lo da el paso de flutter.
    sys.exit(0)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--mode", choices=["analyze", "tail"], required=True)
    ap.add_argument("--machine", default="analyze_machine.jsonl")
    ap.add_argument("--human", default="analyze_human.txt")
    ap.add_argument("--file")
    ap.add_argument("--exit-code", type=int, default=0)
    args = ap.parse_args()

    repo = os.environ.get("GITHUB_REPOSITORY", "")
    sha = os.popen("git rev-parse HEAD").read().strip()
    job_name = os.environ.get("JOB_NAME", "")
    cr_id = find_check_run_id(repo, sha, job_name)
    if cr_id is None:
        print("ci_annotate: check-run no encontrado; sigo sin anotar")

    try:
        if args.mode == "analyze":
            mode_analyze(cr_id, args)
        else:
            mode_tail(cr_id, args)
    except SystemExit:
        raise
    except Exception as e:
        # Última línea de defensa: jamás enmascarar el gate real.
        print("ci_annotate: error interno ({}); no bloqueo el gate".format(e))
        sys.exit(0)


if __name__ == "__main__":
    main()
