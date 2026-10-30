# One-time acceptance of the Prior Labs TabPFN-3.5 licence.
# Usage: uv run python tabpfn_login.py, run from the project root.
# Opens the browser for login/registration and licence acceptance; the API
# key can also be pasted into the terminal. tabpfn caches the key in
# ~/.cache/tabpfn/auth_token, so the TabPFN scripts run without a prompt
# afterwards. Alternative: set the environment variable TABPFN_TOKEN.
# Writes: ~/.cache/tabpfn/auth_token

import sys
import time

from tabpfn import browser_auth


# ── Windows: stdin polling ────────────────────────────────────────────────────
# tabpfn waits for the browser callback while polling stdin with
# select.select(), which on Windows only accepts sockets (WinError 10038).
# Replace the poll with an msvcrt-based one; elsewhere tabpfn is used as is.
def _poll_for_token_windows(auth_event, received_token):
    import msvcrt

    sys.stdout.write("API key (or complete the login in the browser): ")
    sys.stdout.flush()
    chars = []
    while not auth_event.is_set():
        if not msvcrt.kbhit():
            time.sleep(0.1)
            continue
        ch = msvcrt.getwche()
        if ch in ("\r", "\n"):
            sys.stdout.write("\n")
            token = "".join(chars).strip()
            if token:
                return token
            chars.clear()
        elif ch == "\x08":
            if chars:
                chars.pop()
                sys.stdout.write(" \b")
        elif ch == "\x03":
            raise KeyboardInterrupt
        else:
            chars.append(ch)
    return received_token[0]

if sys.platform == "win32":
    browser_auth._poll_for_token = _poll_for_token_windows


# ── licence ───────────────────────────────────────────────────────────────────
# hf_repo_id of the TabPFN-3.5 weights used by all three TabPFN variants
browser_auth.ensure_license_accepted(hf_repo_id="tabpfn_3_5")
print("TabPFN-3.5 licence accepted; the TabPFN scripts can now be run.")
