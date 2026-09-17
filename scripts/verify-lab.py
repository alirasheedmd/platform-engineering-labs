#!/usr/bin/env python3
"""Read-only checks run as root on the Swarm manager by verify.yml."""

import argparse
import json
import subprocess
import sys
import time


def command(*args):
    return subprocess.check_output(args, text=True, stderr=subprocess.STDOUT, timeout=15).strip()


def docker_json(*args):
    return json.loads(command("docker", *args))


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def inspect_service(name, replicas, expected_image, network_id):
    service = docker_json("service", "inspect", name)[0]
    spec = service["Spec"]
    template = spec["TaskTemplate"]
    image = template["ContainerSpec"]["Image"]
    require(spec["Mode"].get("Replicated", {}).get("Replicas") == replicas,
            f"{name}: desired replicas do not equal {replicas}")
    if expected_image:
        require(image == expected_image, f"{name}: unexpected image {image}")
    require(network_id in [n["Target"] for n in template.get("Networks", [])],
            f"{name}: not attached to platform-overlay")
    state = service.get("UpdateStatus", {}).get("State")
    require(state in (None, "completed"), f"{name}: rollout state is {state}")
    ids = command("docker", "service", "ps", "--filter", "desired-state=running", "-q", name).split()
    require(len(ids) == replicas, f"{name}: expected {replicas} current tasks, found {len(ids)}")
    tasks = docker_json("inspect", "--type", "task", *ids)
    require(all(t["Status"]["State"] == "running" for t in tasks), f"{name}: tasks are not all running")
    require(all(t["Spec"]["ContainerSpec"]["Image"] == image for t in tasks),
            f"{name}: running tasks do not all use the desired image")
    # During config/secret rotation, tasks with the old mounts must not pass.
    for field in ("Configs", "Secrets"):
        desired = template["ContainerSpec"].get(field, [])
        require(all(t["Spec"]["ContainerSpec"].get(field, []) == desired for t in tasks),
                f"{name}: tasks still use old {field.lower()}")
    return spec


def verify(args):
    node_ids = command("docker", "node", "ls", "-q").split()
    require(bool(node_ids), "Swarm contains no nodes")
    nodes = docker_json("node", "inspect", *node_ids)
    wanted = set(args.nodes.split(","))
    require({n["Description"]["Hostname"] for n in nodes} == wanted, "Swarm membership differs from inventory")
    require(all(n["Status"]["State"] == "ready" and n["Spec"]["Availability"] == "active" for n in nodes),
            "Every expected node must be ready and active")
    network = docker_json("network", "inspect", "platform-overlay")[0]
    require(network["Driver"] == "overlay" and network["Attachable"], "platform-overlay has the wrong configuration")
    web = inspect_service("lab-web", args.web_replicas, args.web_image, network["Id"])
    require(not web.get("EndpointSpec", {}).get("Ports"), "lab-web still exposes a published port")
    ingress = inspect_service("lab-ingress", args.ingress_replicas, args.ingress_image, network["Id"])
    ports = {(p["PublishedPort"], p["TargetPort"], p["Protocol"], p.get("PublishMode", "ingress"))
             for p in ingress.get("EndpointSpec", {}).get("Ports", [])}
    require(ports == {(80, 80, "tcp", "ingress"), (443, 443, "tcp", "ingress")}, "Unexpected ingress ports")
    container = ingress["TaskTemplate"]["ContainerSpec"]
    configs = {c["File"]["Name"]: c for c in container.get("Configs", [])}
    require(set(configs) == {"/etc/nginx/nginx.conf", "/etc/nginx/tls.crt"}, "Ingress config mounts are incomplete")
    for target, expected in (("/etc/nginx/nginx.conf", args.config_name), ("/etc/nginx/tls.crt", args.cert_name)):
        if expected:
            require(configs[target]["ConfigName"] == expected, f"{target}: expected managed config is not deployed")
    secrets = container.get("Secrets", [])
    require(len(secrets) == 1 and secrets[0]["File"]["Name"] == "tls.key", "TLS key secret mount is missing")
    require(secrets[0]["File"]["Mode"] == 0o400, "TLS key secret must be readable only by root")
    if args.key_name:
        require(secrets[0]["SecretName"] == args.key_name, "Expected managed TLS secret is not deployed")

    for ip in args.addresses.split(","):
        common = ("curl", "--noproxy", "*", "--silent", "--show-error", "--max-time", "10")
        redirect = command(*common, "--resolve", f"{args.hostname}:80:{ip}", "--output", "/dev/null",
                           "--write-out", "%{http_code}\n%{redirect_url}", f"http://{args.hostname}/?lab-check=1")
        require(redirect == f"301\nhttps://{args.hostname}/?lab-check=1", f"{ip}: incorrect HTTP to HTTPS redirect")
        status = command(*common, "--fail", "--cacert", args.certificate,
                         "--resolve", f"{args.hostname}:443:{ip}", "--output", "/dev/null",
                         "--write-out", "%{http_code}", f"https://{args.hostname}/")
        require(status == "200", f"{ip}: HTTPS did not return 200")
    return web["TaskTemplate"]["ContainerSpec"]["Image"]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--nodes", required=True)
    parser.add_argument("--addresses", required=True)
    parser.add_argument("--hostname", required=True)
    parser.add_argument("--certificate", required=True)
    parser.add_argument("--web-replicas", type=int, default=4)
    parser.add_argument("--ingress-replicas", type=int, default=2)
    parser.add_argument("--web-image", default="")
    parser.add_argument("--ingress-image", required=True)
    parser.add_argument("--config-name", default="")
    parser.add_argument("--cert-name", default="")
    parser.add_argument("--key-name", default="")
    parser.add_argument("--timeout", type=int, default=180)
    args = parser.parse_args()
    deadline = time.monotonic() + args.timeout
    while True:
        try:
            image = verify(args)
            print(f"PASS: {args.nodes}; private lab-web {args.web_replicas}/{args.web_replicas}; "
                  f"lab-ingress {args.ingress_replicas}/{args.ingress_replicas}; "
                  f"HTTP redirect and trusted HTTPS on {args.addresses}; image={image}")
            return 0
        except (RuntimeError, subprocess.SubprocessError, ValueError, KeyError, IndexError) as error:
            if time.monotonic() >= deadline:
                print(f"FAIL: {error}", file=sys.stderr)
                return 1
            print(f"Waiting for lab convergence: {error}", flush=True)
            time.sleep(5)


if __name__ == "__main__":
    sys.exit(main())

