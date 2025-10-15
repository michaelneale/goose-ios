#!/usr/bin/env python3
"""
Network Traffic Monitor

Features:
- Per-interface RX/TX throughput (bytes/s and bits/s) at a chosen interval
- Optional CSV logging of per-interval stats
- Optional display of active TCP/UDP connections (requires permissions for some details)
- Cross-platform using psutil

Usage examples:
  python3 network_monitor.py --interval 1
  python3 network_monitor.py --interval 2 --iface en0 --csv net.csv
  python3 network_monitor.py --show-conns --states ESTABLISHED --top 20
  python3 network_monitor.py --duration 60 --csv net.csv

Dependencies:
  pip install psutil

Note: Showing per-process names/ports for all connections may require elevated
permissions on some systems (e.g., macOS/Linux). If you see AccessDenied
warnings, run with sudo or omit --show-conns.
"""

import argparse
import csv
import datetime as dt
import signal
import sys
import time
from typing import Dict, Iterable, List, Optional, Tuple

try:
    import psutil  # type: ignore
except ImportError:
    print("This script requires 'psutil'. Install it with: pip install psutil", file=sys.stderr)
    sys.exit(1)


def human_bytes(n: float, suffix: str = "B") -> str:
    """Return human-readable bytes (IEC)."""
    # Guard
    if n is None:
        return "0" + suffix
    units = ["", "Ki", "Mi", "Gi", "Ti", "Pi"]
    for u in units:
        if abs(n) < 1024.0:
            return f"{n:6.2f} {u}{suffix}"
        n /= 1024.0
    return f"{n:6.2f} Ei{suffix}"


def human_bits(n: float) -> str:
    return human_bytes(n / 8.0, suffix="b")


def now_ts() -> str:
    return dt.datetime.now().strftime("%Y-%m-%d %H:%M:%S")


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Monitor network throughput and connections")
    p.add_argument("--interval", "-i", type=float, default=1.0, help="Polling interval in seconds (default: 1.0)")
    p.add_argument("--iface", "-n", action="append", default=None, help="Interface name to include (repeatable). If omitted, all interfaces are shown.")
    p.add_argument("--csv", type=str, default=None, help="Path to CSV file for logging per-interval stats")
    p.add_argument("--duration", type=float, default=None, help="Run for N seconds then exit")
    p.add_argument("--once", action="store_true", help="Print one sample and exit")
    p.add_argument("--show-conns", action="store_true", help="Also show active network connections each interval")
    p.add_argument("--states", type=str, default="ESTABLISHED", help="Comma-separated connection states to include (e.g., ESTABLISHED,LISTEN,SYN_SENT). Use 'ALL' to show all.")
    p.add_argument("--top", type=int, default=15, help="Max connections to display when --show-conns (default: 15)")
    p.add_argument("--ipv6", action="store_true", help="Include IPv6 connections (default: IPv4 only)")
    p.add_argument("--no-header", action="store_true", help="Do not print the header line each interval")
    p.add_argument("--no-clear", action="store_true", help="Do not clear the screen between updates")
    return p.parse_args()


def get_filtered_interfaces(include_ifaces: Optional[List[str]]) -> List[str]:
    pernic = psutil.net_io_counters(pernic=True)
    names = list(pernic.keys())
    if include_ifaces:
        include_set = set(include_ifaces)
        names = [n for n in names if n in include_set]
    # Sort for stable output; put likely active first
    names.sort(key=lambda x: (0 if x.lower().startswith(("en", "eth", "wlan")) else 1, x))
    return names


def print_header(ifaces: Iterable[str], show_conns: bool):
    cols_iface = "Interface"
    cols = ["RX/s", "TX/s", "RX/s (bits)", "TX/s (bits)", "RX pkts/s", "TX pkts/s", "Errs/s", "Drops/s"]
    line = f"{cols_iface:>12}  " + "  ".join([f"{c:>14}" for c in cols])
    print("\n" + line)
    print("-" * len(line))
    if show_conns:
        print("Connections: laddr -> raddr [state] (pid: name)")


def clear_screen():
    sys.stdout.write("\033[2J\033[H")
    sys.stdout.flush()


def monitor(interval: float,
            include_ifaces: Optional[List[str]] = None,
            csv_path: Optional[str] = None,
            duration: Optional[float] = None,
            once: bool = False,
            show_conns: bool = False,
            states_filter: Optional[List[str]] = None,
            top: int = 15,
            ipv6: bool = False,
            no_header: bool = False,
            no_clear: bool = False) -> None:

    pernic_prev = psutil.net_io_counters(pernic=True)
    ifaces = get_filtered_interfaces(include_ifaces)

    # CSV setup
    csv_writer = None
    csv_file = None
    if csv_path:
        csv_file = open(csv_path, "a", newline="")
        csv_writer = csv.writer(csv_file)
        # Write header if file is empty
        try:
            if csv_file.tell() == 0:
                csv_writer.writerow([
                    "timestamp", "interface", "rx_bytes", "tx_bytes", "rx_bps", "tx_bps",
                    "rx_pkts", "tx_pkts", "errin", "errout", "dropin", "dropout"
                ])
        except Exception:
            pass

    start = time.time()

    def time_left() -> Optional[float]:
        if duration is None:
            return None
        return max(0.0, duration - (time.time() - start))

    # Signal handling for clean exit
    stop = {"flag": False}

    def handle_sigint(signum, frame):
        stop["flag"] = True

    signal.signal(signal.SIGINT, handle_sigint)

    first = True
    while True:
        if not no_clear and not once:
            clear_screen()

        # Sleep until next sample
        if not first:
            # Adjust sleep if duration limit
            if duration is not None:
                remain = time_left()
                if remain is not None and remain <= 0:
                    break
                sleep_time = min(interval, remain) if remain is not None else interval
            else:
                sleep_time = interval
            try:
                time.sleep(sleep_time)
            except KeyboardInterrupt:
                break
        first = False

        pernic_now = psutil.net_io_counters(pernic=True)
        ifaces = get_filtered_interfaces(include_ifaces)

        # Header
        if not no_header:
            print(f"[{now_ts()}] Interval: {interval:.2f}s")
            print_header(ifaces, show_conns)

        for nic in ifaces:
            prev = pernic_prev.get(nic)
            curr = pernic_now.get(nic)
            if not curr or not prev:
                continue
            dt_sec = interval if interval > 0 else 1.0

            rx_bytes = max(0, curr.bytes_recv - prev.bytes_recv)
            tx_bytes = max(0, curr.bytes_sent - prev.bytes_sent)
            rx_pkts = max(0, curr.packets_recv - prev.packets_recv)
            tx_pkts = max(0, curr.packets_sent - prev.packets_sent)
            err = max(0, curr.errin - prev.errin) + max(0, curr.errout - prev.errout)
            drops = max(0, curr.dropin - prev.dropin) + max(0, curr.dropout - prev.dropout)

            rx_per_s = rx_bytes / dt_sec
            tx_per_s = tx_bytes / dt_sec
            rx_pkts_s = rx_pkts / dt_sec
            tx_pkts_s = tx_pkts / dt_sec
            err_s = err / dt_sec
            drops_s = drops / dt_sec

            print(
                f"{nic:>12}  "
                f"{human_bytes(rx_per_s):>14}  {human_bytes(tx_per_s):>14}  "
                f"{human_bits(rx_per_s):>14}  {human_bits(tx_per_s):>14}  "
                f"{rx_pkts_s:14.2f}  {tx_pkts_s:14.2f}  {err_s:14.2f}  {drops_s:14.2f}"
            )

            if csv_writer:
                csv_writer.writerow([
                    now_ts(), nic,
                    rx_bytes, tx_bytes,
                    int(rx_per_s * 8), int(tx_per_s * 8),
                    rx_pkts, tx_pkts,
                    max(0, curr.errin - prev.errin),
                    max(0, curr.errout - prev.errout),
                    max(0, curr.dropin - prev.dropin),
                    max(0, curr.dropout - prev.dropout),
                ])
                csv_file.flush()

        # Connections (best-effort)
        if show_conns:
            try:
                kind = "inet6" if ipv6 else "inet"
                conns = psutil.net_connections(kind=kind)
                # Filter states
                if states_filter and "ALL" not in states_filter:
                    wanted = set(s.upper() for s in states_filter)
                    conns = [c for c in conns if (c.status or "").upper() in wanted]
                # Prepare printable entries
                display: List[Tuple[str, str, str, str]] = []
                for c in conns:
                    laddr = f"{getattr(c.laddr, 'ip', '')}:{getattr(c.laddr, 'port', '')}" if c.laddr else "-"
                    raddr = f"{getattr(c.raddr, 'ip', '')}:{getattr(c.raddr, 'port', '')}" if c.raddr else "-"
                    state = c.status or "-"
                    pid = c.pid if c.pid is not None else "-"
                    pname = ""
                    if c.pid:
                        try:
                            pname = psutil.Process(c.pid).name()
                        except Exception:
                            pname = "?"
                    display.append((laddr, raddr, state, f"{pid}: {pname}"))
                # Sort by state then laddr
                display.sort(key=lambda x: (x[2], x[0], x[1]))
                print("")
                print(f"Active connections (showing up to {top}):")
                print("laddr -> raddr [state] (pid: name)")
                for i, (l, r, s, pn) in enumerate(display[:top], 1):
                    print(f"{i:2d}. {l} -> {r} [{s}] ({pn})")
            except psutil.AccessDenied:
                print("Connections: AccessDenied. Try running with elevated permissions or omit --show-conns.")
            except Exception as e:
                print(f"Connections: error: {e}")

        pernic_prev = pernic_now

        if once:
            break
        if stop["flag"]:
            break

    if csv_path and csv_file:
        csv_file.close()


def main():
    args = parse_args()
    states = None
    if args.states:
        states = [s.strip() for s in args.states.split(",") if s.strip()]
    monitor(
        interval=max(0.1, args.interval),
        include_ifaces=args.iface,
        csv_path=args.csv,
        duration=args.duration,
        once=args.once,
        show_conns=args.show_conns,
        states_filter=states,
        top=args.top,
        ipv6=args.ipv6,
        no_header=args.no_header,
        no_clear=args.no_clear,
    )


if __name__ == "__main__":
    main()
