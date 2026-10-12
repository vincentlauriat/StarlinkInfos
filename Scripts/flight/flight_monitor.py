#!/usr/bin/env python3
"""In-flight Starlink link monitor, one CSV row every 30 s.

Per sample:
- end-to-end latency/loss: 10 pings to 1.1.1.1
- space-segment latency/loss: 5 TTL-limited probes expiring at hop 2, Starlink's
  CGNAT gateway (100.64.0.1), i.e. roughly aircraft -> satellite -> ground station.
  That gateway drops direct ICMP echo but answers "TTL exceeded", hence traceroute.
  Runs in parallel with the pings.
- egress PoP: public IP (api.ipify.org) -> reverse DNS
  (customer.<pop>.isp.starlink.com) -> PoP code
City/country come from ipinfo.io, queried only every 10 min or when the PoP code
changes (ipinfo is rate-limited; ipify + reverse DNS are not).

Read-only: ICMP pings, UDP traceroute probes, HTTPS GETs, one DNS PTR lookup. Usage:
    flight_monitor.py <out.csv>
"""
import csv
import json
import re
import socket
import subprocess
import sys
import time
import urllib.request
from datetime import datetime, timezone

INTERNET_TARGET = "1.1.1.1"
SPACE_HOP = 2
INTERNET_COUNT = 10
SPACE_COUNT = 5
INTERVAL_S = 30
CITY_EVERY_S = 600

FIELDS = ["utc", "rtt_min", "rtt_avg", "rtt_max", "rtt_stddev", "loss_pct",
          "public_ip", "hostname", "pop_city", "pop_country",
          "pop_code", "space_hop", "space_rtt_avg", "space_loss_pct"]

SUMMARY_RE = re.compile(r"(\d+) packets transmitted, (\d+) (?:packets )?received")
RTT_RE = re.compile(r"= ([\d.]+)/([\d.]+)/([\d.]+)/([\d.]+) ms")
POP_RE = re.compile(r"^customer\.([a-z0-9]+)\.isp\.starlink\.com$")
HOP_RE = re.compile(r"^\s*\d+\s+(\S+)\s+(.*)$", re.M)
PROBE_RE = re.compile(r"([\d.]+) ms|\*")


def start_ping(target, count):
    return subprocess.Popen(["ping", "-c", str(count), "-i", "1", "-t", str(count + 5), target],
                            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)


def parse_ping(proc, count):
    """Return (min, avg, max, stddev, loss_pct); RTTs are None when nothing came back."""
    try:
        out, _ = proc.communicate(timeout=count + 10)
    except subprocess.TimeoutExpired:
        proc.kill()
        return None, None, None, None, 100.0
    s = SUMMARY_RE.search(out)
    loss = 100.0 if not s else round(100 * (1 - int(s.group(2)) / int(s.group(1))), 1)
    r = RTT_RE.search(out)
    if not r:
        return None, None, None, None, loss
    return (*(float(x) for x in r.groups()), loss)


def start_hop_probe():
    return subprocess.Popen(["traceroute", "-n", "-f", str(SPACE_HOP), "-m", str(SPACE_HOP),
                             "-q", str(SPACE_COUNT), "-w", "2", INTERNET_TARGET],
                            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)


def parse_hop_probe(proc):
    """Return (hop_ip, avg_rtt, loss_pct) for the single hop traceroute reported."""
    try:
        out, _ = proc.communicate(timeout=SPACE_COUNT * 2 + 10)
    except subprocess.TimeoutExpired:
        proc.kill()
        return "", None, 100.0
    m = HOP_RE.search(out)
    if not m or m.group(1) == "*":
        return "", None, 100.0
    rtts = [float(p.group(1)) for p in PROBE_RE.finditer(m.group(2)) if p.group(1)]
    lost = SPACE_COUNT - len(rtts)
    avg = round(sum(rtts) / len(rtts), 3) if rtts else None
    return m.group(1), avg, round(100 * lost / SPACE_COUNT, 1)


def http_get(url):
    with urllib.request.urlopen(url, timeout=8) as resp:
        return resp.read().decode()


def egress():
    """Return (public_ip, hostname, pop_code) without touching ipinfo."""
    try:
        ip = http_get("https://api.ipify.org").strip()
    except Exception as e:  # network drop: record it, keep going
        return "", f"error: {type(e).__name__}", ""
    try:
        host = socket.gethostbyaddr(ip)[0]
    except OSError:
        return ip, "", ""
    m = POP_RE.match(host)
    return ip, host, m.group(1) if m else ""


def city():
    try:
        d = json.loads(http_get("https://ipinfo.io/json"))
        return d.get("city", ""), d.get("country", "")
    except Exception:
        return "", ""


def open_csv(path):
    try:
        with open(path, newline="") as f:
            header = next(csv.reader(f), None)
    except FileNotFoundError:
        header = None
    if header is not None and header != FIELDS:
        sys.exit(f"{path} has an older column layout; write to a new file.")
    f = open(path, "a", newline="")
    w = csv.writer(f)
    if header is None:
        w.writerow(FIELDS)
        f.flush()
    return f, w


def main():
    f, w = open_csv(sys.argv[1])
    last_city_t, last_code, place = 0.0, None, ("", "")
    while True:
        t0 = time.monotonic()
        utc = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        internet = start_ping(INTERNET_TARGET, INTERNET_COUNT)
        space = start_hop_probe()
        ip, host, code = egress()
        if code and (code != last_code or t0 - last_city_t >= CITY_EVERY_S):
            place, last_city_t, last_code = city(), t0, code
        i_min, i_avg, i_max, i_sd, i_loss = parse_ping(internet, INTERNET_COUNT)
        s_hop, s_avg, s_loss = parse_hop_probe(space)
        w.writerow([utc, i_min, i_avg, i_max, i_sd, i_loss, ip, host, *place, code, s_hop, s_avg, s_loss])
        f.flush()
        time.sleep(max(0, INTERVAL_S - (time.monotonic() - t0)))


if __name__ == "__main__":
    main()
